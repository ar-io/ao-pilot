import { AOProcess, IO, IO_TESTNET_PROCESS_ID } from '@ar.io/sdk';
import { connect } from '@permaweb/aoconnect';
import path from 'path';
import fs from 'fs';

const __dirname = path.dirname(new URL(import.meta.url).pathname);
const outputFilePath = path.join(__dirname, 'arns-processid-mapping.csv');

async function main() {
  const io = IO.init({
    process: new AOProcess({
      processId: IO_TESTNET_PROCESS_ID,
      ao: connect({
        CU_URL: 'https://cu.ar-io.dev',
      }),
    }),
  });

  const arnsRecords = await io.getArNSRecords({
    limit: 100000,
    sortBy: 'startTimestamp',
    sortOrder: 'asc',
  });
  // create csv if not exists
  fs.writeFileSync(outputFilePath, 'domain,processId\n', { flag: 'w' });

  arnsRecords.items.forEach((record) => {
    // append column to CSV
    // column 1: domain name
    // column 2: process ID

    fs.writeFileSync(outputFilePath, `${record.name},${record.processId}\n`, {
      flag: 'a',
    });
  });
}

main();