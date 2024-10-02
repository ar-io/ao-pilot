import {
  AOProcess,
  IO,
  IO_DEVNET_PROCESS_ID,
  IO_TESTNET_PROCESS_ID,
} from "@ar.io/sdk";
import { connect } from "@permaweb/aoconnect";
import path from "path";
import fs from "fs";

const __dirname = path.dirname(new URL(import.meta.url).pathname);
const restart = process.argv.includes("--restart");
const testnet = process.argv.includes("--testnet");
async function main() {
  const io = IO.init({
    process: new AOProcess({
      processId: testnet ? IO_TESTNET_PROCESS_ID : IO_DEVNET_PROCESS_ID,
      ao: connect({
        CU_URL: "https://cu.ar-io.dev",
      }),
    }),
  });

  const outputFilePath = path.join(
    __dirname,
    `arns-processid-mapping-${testnet ? "testnet" : "devnet"}.csv`,
  );

  const arnsRecords = await io.getArNSRecords({
    limit: 100000,
    sortBy: "startTimestamp",
    sortOrder: "asc",
  });

  // recreate the file if restart is true
  if (!fs.existsSync(outputFilePath) || restart) {
    fs.writeFileSync(outputFilePath, "domain,oldProcessId\n", { flag: "w" });
  }

  console.log(
    `Found ${arnsRecords.items.length} ARNS records for process, mapping to CSV for processing`,
  );
  arnsRecords.items.forEach((record) => {
    fs.writeFileSync(outputFilePath, `${record.name},${record.processId}\n`, {
      flag: "a",
    });
  });
  console.log(`Wrote ${arnsRecords.items.length} ARNS records to CSV`);
}

main();
