import { ANT, AOProcess } from "@ar.io/sdk";
import { connect } from "@permaweb/aoconnect";
import fs from "fs";
import path from "path";
import { strict as assert } from "node:assert";
import Arweave from "arweave";

const __dirname = path.dirname(new URL(import.meta.url).pathname);
const inputFilePath = process.argv.includes("--file")
  ? process.argv[process.argv.indexOf("--file") + 1]
  : null;
const testnet = process.argv.includes("--testnet") ? true : false;
const aoClient = connect();
const wallet = JSON.parse(
  fs.readFileSync(path.join(__dirname, "key.json"), "utf8"),
);
const arweave = Arweave.init({
  host: "arweave.net",
  port: 443,
  protocol: "https",
});

async function main() {
  const csv = fs.readFileSync(path.join(__dirname, inputFilePath), "utf8");

  const outputFilePath = path.join(
    __dirname,
    `e2e-eval-verified-ants-${testnet ? "testnet" : "devnet"}.csv`,
  );

  // print out address of wallet being used
  const address = await arweave.wallets.jwkToAddress(wallet);
  console.log(`Using wallet ${address} to evaluate ants`);

  const inputProcessIds = csv
    .split("\n")
    .slice(1) // skip header
    .map((line) => line.split(","))
    .filter(
      ([domain, oldProcessId, newProcessId, evaluated]) =>
        domain &&
        oldProcessId &&
        newProcessId &&
        oldProcessId !== newProcessId
    );

  fs.writeFileSync(
    outputFilePath,
    "domain,oldProcessId,newProcessId,evaluated,sdkIntegrationVerified\n",
    { flag: "w" },
  );

  await Promise.all(inputProcessIds.map(async ([domain, oldProcessId, newProcessId]) => {
    console.log(
      `Verifying sdk integration for ${domain} with new process id ${newProcessId}`,
    );
    const ant = ANT.init({
      process: new AOProcess({
        processId: newProcessId,
        ao: aoClient,
      }),
    });
    const info = await ant.getInfo();
    assert(info.Name);
    assert(info.Ticker);
    assert(info["Total-Supply"]);
    assert(info.Denomination !== undefined);
    assert(info.Logo);
    assert(info.Owner === address);
    assert(info.Handlers);
    assert.deepStrictEqual(info.Handlers, [
      "evolve",
      "_eval",
      "_default",
      "transfer",
      "balance",
      "balances",
      "totalSupply",
      "info",
      "addController",
      "removeController",
      "controllers",
      "setRecord",
      "removeRecord",
      "record",
      "records",
      "setName",
      "setTicker",
      "initializeState",
      "state",
    ]);

    // write the existing columns and code verified column
    await fs.promises.appendFile(
      outputFilePath,
      `${domain},${oldProcessId},${newProcessId},true,true\n`,
      );
    }),
  );
}

main();
