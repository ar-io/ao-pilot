import {
  ArweaveSigner,
  createAoSigner,
} from '@ar.io/sdk';
import Arweave from 'arweave';
import { connect } from '@permaweb/aoconnect';
import path from 'path';
import fs from 'fs';

const __dirname = path.dirname(new URL(import.meta.url).pathname);
const restart = process.argv.includes('--restart');
const dryRun = process.argv.includes('--dry-run');
const wallet = JSON.parse(
  fs.readFileSync(path.join(__dirname, 'key.json'), 'utf8'),
);
const signer = new ArweaveSigner(wallet);
const testnet = process.argv.includes('--testnet');
const arweave = Arweave.init({
  host: 'arweave.net',
  port: 443,
  protocol: 'https',
});
const aoClient = connect({
  CU_URL: 'https://cu.ar-io.dev',
});
const { message, result } = aoClient;
const bundledCode = fs.readFileSync(path.join(__dirname, 'aos-bundled.lua'), 'utf8');

async function main() {
  const csv = fs.readFileSync(
    path.join(__dirname, `new-arns-processid-mapping-${testnet ? 'testnet' : 'devnet'}.csv`),
    'utf8',
  );

  const outputFilePath = path.join(__dirname, `new-evaluated-processids-${testnet ? 'testnet' : 'devnet'}.csv`);

  // print out address of wallet being used
  const address = await arweave.wallets.jwkToAddress(wallet);
  console.log(`Using wallet ${address} to evaluate ants`);

  const newlyCreatedProcessIds = csv
    .split('\n')
    .slice(1) // skip header
    .map((line) => line.split(','))
    .filter(([domain, oldProcessId, newProcessId]) => domain && oldProcessId && newProcessId && oldProcessId !== newProcessId);

  // create output csv if not exists including eval result
  if (!fs.existsSync(outputFilePath) || restart) {
    fs.writeFileSync(outputFilePath, 'domain,oldProcessId,newProcessId,evalResult\n', { flag: 'w' });
  }

  const antsToEvaluate = [];
  const processMap = new Map();
  let lastEvalProcessId;

  // if any failed previously, we want to retry so add them our list
  if (!restart) {
    const existingRecords = fs.readFileSync(outputFilePath, 'utf8')
      .split('\n')
      .slice(1) // Skip header
      .filter(line => line.trim() !== '')
      .map(line => line.split(','));

    for (const [domain, oldProcessId, newProcessId, evalResult] of existingRecords) {
      lastEvalProcessId = newProcessId;
      if(processMap.has(newProcessId) && processMap.get(newProcessId)) {
        continue;
      }
      processMap.set(newProcessId, evalResult === 'true');
    }

    console.log(`Loaded ${antsToEvaluate.length} ants to evaluate.`);
  }

  if (lastEvalProcessId) {
    console.log(`Last eval process id: ${lastEvalProcessId}`);
  }

  const indexOfAntToEval = newlyCreatedProcessIds.findIndex(([domain, oldProcessId, newProcessId]) => newProcessId === lastEvalProcessId);
  const processIdsToEval = [...antsToEvaluate, ...newlyCreatedProcessIds.slice(indexOfAntToEval + 1)];

  console.log(`Evaluating ${processIdsToEval.length} unique ants`);

  // process map - don't re-evaluate ants that have already been evaluated

  for (const [domain, oldProcessId, newProcessId] of processIdsToEval) {
    console.log(`Evaluating ant ${newProcessId}`);

    // don't eval if we already have on the process map
    if(processMap.has(newProcessId)) {
      console.log(`Skipping ${newProcessId} as it has already been evaluated`);
      continue;
    }

    if (dryRun) {
      console.log(`Dry run, skipping actual evaluation of ant ${newProcessId}`);
      processMap.set(newProcessId, true);
      fs.writeFileSync(outputFilePath, `${domain},${oldProcessId},${newProcessId},true\n`, {
        flag: 'a',
      });
      continue;
    }

    const evalMessageId = await message({
        signer: createAoSigner(signer),
        process: newProcessId,
        tags: [
            {
                name: 'Action',
                value: 'Eval'
            },
            {
                name: 'For-Domain',
                value: domain
            },
            {
                name: 'Old-Process-Id',
                value: oldProcessId
            }
        ],
        data: bundledCode
    })

    // crank the MU to ensure eval is processed
    await result({
        message: evalMessageId,
        process: newProcessId,
    });

    fs.writeFileSync(outputFilePath, `${domain},${oldProcessId},${newProcessId},true\n`, {
      flag: 'a',
    });

    processMap.set(newProcessId, true);
  }
}

main();
