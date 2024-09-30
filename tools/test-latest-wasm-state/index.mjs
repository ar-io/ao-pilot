import workerpool from 'workerpool';
import path from 'path';
import { pLimit } from 'plimit-lit';
import { AOProcess, IO, IO_TESTNET_PROCESS_ID } from '@ar.io/sdk';
import { connect } from '@permaweb/aoconnect';
import fs from 'fs';

const __dirname = path.dirname(new URL(import.meta.url).pathname);

const domainsToTest = fs.readFileSync(
  path.join(__dirname, 'domains-to-test.json'),
);

// initialize a worker pool
const pool = workerpool.pool(path.join(__dirname, 'worker.mjs'));

// call a function in the worker
async function main() {
  const arnsRecords = await IO.init({
    process: new AOProcess({
      processId: IO_TESTNET_PROCESS_ID,
      ao: connect({
        CU_URL: 'https://cu.ar-io.dev',
      }),
    }),
  }).getArNSRecords({
    limit: 100000,
  });
  const antIds = arnsRecords.items
    .map((record) => {
      if (JSON.parse(domainsToTest).includes(record.name))
        return record.processId;
    })
    .filter((id) => id !== undefined);
  const antsToScan = antIds.length;
  let scanned = 1;
  let evalCapable = [];
  let notEvalCapable = [];

  const limit = pLimit(30); // Set the concurrency limit to 10 workers
  const scanPromises = antIds.map(async (antId) => {
    console.log(`Scanning domain ${scanned} / ${antsToScan}: ${antId}`);
    await limit(() =>
      pool
        .proxy()
        .then((proxy) => proxy.testProcessEvalCapability(antId))
        .then((res) => {
          if (!res) {
            notEvalCapable.push(antId);
          } else {
            evalCapable.push(antId);
          }
        })
        .catch(function (err) {
          console.error(err);
        }),
    ); // Use pLimit to control the concurrency

    scanned++;
    console.log(
      `Eval capable: ${evalCapable.length}, Not eval capable: ${notEvalCapable.length}, scanned ${scanned} / ${antsToScan}`,
    );
  });
  await Promise.all(scanPromises);

  // tie ant IDs to domains for provisioning
  console.log('Eval capable:', evalCapable);
  console.log('Not eval capable:', notEvalCapable);

  const domainsToProvision = [];

  notEvalCapable.map((antId) => {
    const domain = arnsRecords.items.forEach(
      (record) => record.processId === antId,
    );
    domainsToProvision.push(domain);
  });

  fs.writeFileSync(
    path.join(__dirname, 'domains-to-provision.json'),
    JSON.stringify(domainsToProvision),
  );
}

main().finally(() => {
  pool.terminate();
});
