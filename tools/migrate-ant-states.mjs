import { ArweaveSigner, createAoSigner, ANT } from "@ar.io/sdk";
import Arweave from "arweave";
import { connect } from "@permaweb/aoconnect";
import path from "path";
import fs from "fs";

const __dirname = path.dirname(new URL(import.meta.url).pathname);
const restart = process.argv.includes("--restart");
const dryRun = process.argv.includes("--dry-run");
const inputFilePath = process.argv.includes("--file")
  ? process.argv[process.argv.indexOf("--file") + 1]
  : null;
const wallet = JSON.parse(
  fs.readFileSync(path.join(__dirname, "key.json"), "utf8"),
);
const signer = new ArweaveSigner(wallet);
const testnet = process.argv.includes("--testnet");
const arweave = Arweave.init({
  host: "arweave.net",
  port: 443,
  protocol: "https",
});
const { message, result } = connect();

async function main() {
  const csv = fs.readFileSync(path.join(__dirname, inputFilePath), "utf8");

  const outputFilePath = path.join(
    __dirname,
    `migrated-process-ids-${testnet ? "testnet" : "devnet"}.csv`,
  );

  // print out address of wallet being used
  const address = await arweave.wallets.jwkToAddress(wallet);
  console.log(`Using wallet ${address} to migrate ants`);

  const antsToMigrateWithProcessIds = csv
    .split("\n")
    .slice(1) // skip header
    .map((line) => line.split(","))
    .filter(
      ([domain, oldProcessId, newProcessId, sourceCodeUpdated, sdkVerified]) =>
        domain &&
        oldProcessId &&
        newProcessId &&
        oldProcessId !== newProcessId &&
        sourceCodeUpdated === "true" &&
        sdkVerified === "true",
    );

  // create output csv if not exists including eval result
  if (!fs.existsSync(outputFilePath) || restart) {
    fs.writeFileSync(
      outputFilePath,
      "domain,oldProcessId,newProcessId,sourceCodeUpdated,sdkVerified,stateMigrated,initializeStateMessageId\n",
      { flag: "w" },
    );
  }

  const processMap = new Map();

  // if any failed previously, we want to retry so add them our list
  if (!restart) {
    const existingRecords = fs
      .readFileSync(outputFilePath, "utf8")
      .split("\n")
      .slice(1) // Skip header
      .filter((line) => line.trim() !== "")
      .map((line) => line.split(","));

    for (const [
      domain,
      oldProcessId,
      newProcessId,
      sourceCodeUpdated,
      sdkVerified,
      stateMigrated,
      initializeStateMessageId
    ] of existingRecords) {
      processMap.set(newProcessId, initializeStateMessageId);
    }

    console.log(`Skipping ${Object.keys(processMap).length} ants that have already been migrated.`);
  }

  // filter out messages in the process map and remove duplicates based on newProcessId
  const processIdsToMigrate = antsToMigrateWithProcessIds.reduce((acc, [domain, oldProcessId, newProcessId, sourceCodeUpdated, sdkVerified, stateMigrated]) => {
    if (!processMap.has(newProcessId) && !acc.some(item => item[2] === newProcessId)) {
      acc.push([domain, oldProcessId, newProcessId, sourceCodeUpdated, sdkVerified, stateMigrated]);
    }
    return acc;
  }, []);

  console.log(`Migrating ${processIdsToMigrate.length} unique ants`);

  // process map - don't re-evaluate ants that have already been evaluated

  await Promise.all(processIdsToMigrate.map(async ([domain, oldProcessId, newProcessId, sourceCodeUpdated, sdkVerified,stateMigrated]) => {
    console.log(`Migrating state for ant ${oldProcessId} to ${newProcessId}`);

    // don't eval if we already have on the process map
    if (processMap.has(newProcessId)) {
      console.log(`Skipping ${newProcessId} as it has already been migrated`);
      fs.promises.writeFile(
        outputFilePath,
        `${domain},${oldProcessId},${newProcessId},${sourceCodeUpdated},${sdkVerified},${stateMigrated},${processMap.get(newProcessId)}\n`,
        {
          flag: "a",
        },
      );
      return;
    }

    // get the current AO state of the old process
    const oldProcessANT = ANT.init({
      processId: oldProcessId
    });

    const oldProcessState = await oldProcessANT.getState();

    // required by Initialize-State in this format. Everything else will be defaulted
    const migratedState = {
        owner: oldProcessState.Owner,
        controllers: oldProcessState.Controllers,
        name: oldProcessState.Name,
        ticker: oldProcessState.Ticker,
        records: oldProcessState.Records,
        balances: oldProcessState.Balances,
    }

    if (dryRun) {
      console.log(`Dry run, skipping actual evaluation of ant ${newProcessId}. Migrated state: ${JSON.stringify(migratedState)}`);
      processMap.set(newProcessId, 'fake-message-id-of-init-state');
      fs.promises.writeFile(
        outputFilePath,
        `${domain},${oldProcessId},${newProcessId},${sourceCodeUpdated},${sdkVerified},${sourceCodeUpdated},${processMap.get(newProcessId)}\n`,
        {
          flag: "a",
        },
      );
      return;
    }

    const migrateStateMessageId = await message({
      signer: createAoSigner(signer),
      tags: [
        {
          name: "Action",
          value: "Initialize-State",
        },
        {
          name: "Old-Process-Id",
          value: oldProcessId,
        },
      ],
      data: JSON.stringify(migratedState),
    });

    // crank the MU to ensure eval is processed
    await result({
      message: evalMessageId,
      process: newProcessId,
    });

    fs.promises.writeFile(
      outputFilePath,
      `${domain},${oldProcessId},${newProcessId},${sourceCodeUpdated},${sdkVerified},${sdkVerified},${migrateStateMessageId}\n`,
      {
        flag: "a",
      },
    );

      processMap.set(newProcessId, migrateStateMessageId);
    }),
  );
}

main();
