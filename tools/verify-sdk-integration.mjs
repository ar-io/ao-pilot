import { ANT, AOProcess } from "@ar.io/sdk";
import { connect } from "@permaweb/aoconnect";
import fs from "fs";
import path from "path";
import { strict as assert } from "node:assert";
import Arweave from "arweave";
import pLimit from "p-limit";
const __dirname = path.dirname(new URL(import.meta.url).pathname);
const inputFilePath = process.argv.includes("--file")
  ? process.argv[process.argv.indexOf("--file") + 1]
  : null;
const testnet = process.argv.includes("--testnet") ? true : false;
const verifyStateMigration = process.argv.includes("--verify-state-migration")
  ? true
  : false;
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
    `verified-ant-state-and-sdk-integration-${testnet ? "testnet" : "devnet"}.csv`,
  );

  // print out address of wallet being used
  const address = await arweave.wallets.jwkToAddress(wallet);
  console.log(`Using wallet ${address} to evaluate ants`);

  const inputProcessIds = csv
    .split("\n")
    .slice(1) // skip header
    .map((line) => line.split(","))
    .filter(
      ([domain, oldProcessId, newProcessId, sourceCodeUpdated]) =>
        domain && oldProcessId && newProcessId && oldProcessId !== newProcessId,
    );

  fs.writeFileSync(
    outputFilePath,
    "domain,oldProcessId,newProcessId,sourceCodeUpdated,sdkVerified,initializeStateMessageId,stateMatchVerified\n",
    { flag: "w" },
  );

  const limit = pLimit(50);

  await Promise.all(
    inputProcessIds.map(
      async ([
        domain,
        oldProcessId,
        newProcessId,
        sourceCodeUpdated,
        sdkVerified,
        initializeStateMessageId,
      ]) => {
        return limit(async () => {
          console.log(
            `Verifying state and SDK integrations for ${newProcessId}`,
          );
          const ant = ANT.init({
            process: new AOProcess({
              processId: newProcessId,
              ao: aoClient,
            }),
          });
          const info = await ant.getInfo().catch((error) => {
            console.error(`Error getting info for ${newProcessId}: ${error}`);
            return null;
          });
          assert(
            info,
            `Info not found for ${domain} with process id ${newProcessId}`,
          );
          assert(info.Name !== undefined, `Name not found for ${newProcessId}`);
          assert(
            info.Ticker !== undefined,
            `Ticker not found for ${newProcessId}`,
          );
          assert(
            info["Total-Supply"] !== 1,
            `Total supply not found for ${newProcessId}`,
          );
          assert(
            info.Denomination !== 0,
            `Denomination not found for ${newProcessId}`,
          );
          assert(info.Logo !== undefined, `Logo not found for ${newProcessId}`);
          assert(
            info.Owner !== undefined,
            `Owner not found for ${newProcessId}`,
          );
          assert(
            info.Handlers !== undefined,
            `Handlers not found for ${newProcessId}`,
          );
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

          if (verifyStateMigration) {
            // verify old state and new state are the same for every name
            const oldProcessANT = ANT.init({
              processId: oldProcessId,
            });

            // timeout after 15 seconds
            const oldProcessState = await Promise.race([
              oldProcessANT.getState(),
              new Promise((_, reject) =>
                setTimeout(
                  () => reject(new Error("Timeout getting state")),
                  15_000,
                ),
              ),
            ])
              .catch((error) => {
                console.error(
                  `Error getting state for ${oldProcessId}: ${error}`,
                );
                return null;
              })
              .then((state) => {
                return state;
              });

            const newProcessANT = ANT.init({
              processId: newProcessId,
            });

            const newProcessState = await newProcessANT
              .getState()
              .catch((error) => {
                console.error(
                  `Error getting state for ${newProcessId}: ${error}`,
                );
                return null;
              });

            assert(newProcessState, `State not found for ${newProcessId}`);

            // confirm we have the updated source code
            assert.deepStrictEqual(
              newProcessState["Source-Code-TX-ID"],
              "pOh2yupSaQCrLI_-ah8tVTiusUdVNTxxeWTQQHNdf30",
              `Source code not updated for ${newProcessId}`,
            );

            if (!oldProcessState) {
              assert.deepStrictEqual(
                oldProcessState.Records,
                newProcessState.Records,
                `Records not migrated for ${newProcessId}`,
              );
              assert.deepStrictEqual(
                oldProcessState.Balances,
                newProcessState.Balances,
                `Balances not migrated for ${newProcessId}`,
              );
              assert.deepStrictEqual(
                oldProcessState.Name,
                newProcessState.Name,
                `Name not migrated for ${newProcessId}`,
              );
              assert.deepStrictEqual(
                oldProcessState.Ticker,
                newProcessState.Ticker,
              );
              assert.deepStrictEqual(
                oldProcessState.Denomination,
                newProcessState.Denomination,
                `Denomination not migrated for ${newProcessId}`,
              );
              assert.deepStrictEqual(
                oldProcessState.Logo,
                newProcessState.Logo,
                `Logo not migrated for ${newProcessId}`,
              );
              assert.deepStrictEqual(
                oldProcessState.Owner,
                newProcessState.Owner,
                `Owner not migrated for ${newProcessId}`,
              );
              assert.deepStrictEqual(
                oldProcessState.Controllers,
                newProcessState.Controllers,
                `Controllers not migrated for ${newProcessId}`,
              );
            }
          }

          // write the existing columns and code verified column
          await fs.promises.appendFile(
            outputFilePath,
            // domain,oldProcessId,newProcessId,sourceCodeUpdated,sdkVerified,stateMigrated,initializeStateMessageId
            `${domain},${oldProcessId},${newProcessId},${sourceCodeUpdated},${sdkVerified},${initializeStateMessageId},true\n`,
          );
        });
      },
    ),
  );
}

main();
