import {
  ANT_REGISTRY_ID,
  AOS_MODULE_ID,
  ArweaveSigner,
  createAoSigner,
  DEFAULT_SCHEDULER_ID,
} from '@ar.io/sdk';
import Arweave from 'arweave';
import { connect } from '@permaweb/aoconnect';
import path from 'path';
import fs from 'fs';

const __dirname = path.dirname(new URL(import.meta.url).pathname);
const restart = process.argv.includes('--restart');
const dryRun = process.argv.includes('--dry-run');
const testnet = process.argv.includes('--testnet');
const inputFilePath = process.argv.includes('--file') ? process.argv[process.argv.indexOf('--file') + 1] : null;
const wallet = JSON.parse(
  fs.readFileSync(path.join(__dirname, 'key.json'), 'utf8'),
);
const signer = new ArweaveSigner(wallet);
const arweave = Arweave.init({
  host: 'arweave.net',
  port: 443,
  protocol: 'https',
});
const aoClient = connect({
  CU_URL: 'https://cu.ar-io.dev',
});
const { spawn } = aoClient;

async function main() {
  const csv = fs.readFileSync(
    path.join(__dirname, inputFilePath),
    'utf8',
  );

  const outputFilePath = path.join(__dirname, `new-arns-processid-mapping-${testnet ? 'testnet' : 'devnet'}.csv`);

  // print out address of wallet being used
  const address = await arweave.wallets.jwkToAddress(wallet);
  console.log(`Using wallet ${address}`);

  const oldRecords = csv
    .split('\n')
    .slice(1) // skip header
    .map((line) => line.split(','))
    .filter(([domain, oldProcessId]) => domain && oldProcessId);

  console.log(`Validating new ant creation for ${oldRecords.length} records`);

  // create output csv if not exists
  if (!fs.existsSync(outputFilePath) || restart) {
    fs.writeFileSync(outputFilePath, 'domain,oldProcessId,newProcessId\n', { flag: 'w' });
  }

  // in memory map of previously created process ids
  const oldToNewProcessMap = new Map();
  let lastProvisionedName = null;
  // if resuming (e.g. not a restart, check the last row of the file on the new records and contine from there)
  if (!restart) {
    const existingRecords = fs.readFileSync(outputFilePath, 'utf8')
      .split('\n')
      .slice(1) // Skip header
      .filter(line => line.trim() !== '')
      .map(line => line.split(','));

    for (const [domain, oldProcessId, newProcessId] of existingRecords) {
      if (oldProcessId && newProcessId) {
        oldToNewProcessMap.set(oldProcessId, newProcessId);
      }
      lastProvisionedName = domain;
    }

    console.log(`Loaded ${oldToNewProcessMap.size} existing mappings.`);
  }

  // resuming from if last provisioned name is not null
  if (lastProvisionedName) {
    console.log(`Resuming from ${lastProvisionedName}`);
  }

  // slice the existing records to the last provisioned name
  const lastProvisionedIndex = oldRecords.findIndex(([domain]) => domain === lastProvisionedName);
  const recordsToProcess = oldRecords.slice(lastProvisionedIndex + 1);

  console.log(`Processing ${recordsToProcess.length} records`);

  for (const [domain, oldProcessId] of recordsToProcess) {
    console.log(`Provisioning new process id for ${oldProcessId}...`);
    if(oldToNewProcessMap.has(oldProcessId)) {
      const newProcessId = oldToNewProcessMap.get(oldProcessId);
      console.log(`Skipping ${oldProcessId} for name ${domain} because we already have a new process id for it: ${newProcessId}`);
      fs.writeFileSync(outputFilePath, `${domain},${oldProcessId},${newProcessId}\n`, {
        flag: 'a',
      });
      continue;
    }
    if (dryRun) {
      console.log(`Dry run, skipping actual spawn of new process id for name ${domain} with old process id ${oldProcessId}`);
      const randomId = Math.random().toString(36).substring(2, 15);
      const newProcessId = `dry-run-${randomId}`;
      fs.writeFileSync(outputFilePath, `${domain},${oldProcessId},${newProcessId}\n`, {
        flag: 'a',
      });
      oldToNewProcessMap.set(oldProcessId, newProcessId);
      console.log(`Provisioned new process id for name ${domain} with old process id ${oldProcessId}: ${newProcessId}`);
      continue;
    }
    // create new ant if we have not already
    const newAntId = await spawn({
      signer: createAoSigner(signer),
      module: AOS_MODULE_ID,
      scheduler: DEFAULT_SCHEDULER_ID,
      tags: [
        {
          name: 'ANT-Registry-Id',
          value: ANT_REGISTRY_ID,
        },
      ],
    });
    fs.writeFileSync(outputFilePath, `${domain},${oldProcessId},${newAntId}\n`, {
      flag: 'a',
    }); 
    oldToNewProcessMap.set(oldProcessId, newAntId);
    console.log(`Provisioned new process id for name ${domain} with old process id ${oldProcessId}: ${newAntId}`);
  }
}

main();
