import {
  ANT,
  IO_TESTNET_PROCESS_ID,
  IO,
  AOProcess,
  createAoSigner,
  ArweaveSigner,
} from "@ar.io/sdk";
import { connect } from "@permaweb/aoconnect";
import path from "path";
import fs from "fs";
import { strict as assert } from "node:assert";
import pLimit from "p-limit";
import Arweave from "arweave";

const __dirname = path.dirname(new URL(import.meta.url).pathname);
const inputFilePath = process.argv.includes("--file")
  ? process.argv[process.argv.indexOf("--file") + 1]
  : null;
const dryRun = process.argv.includes("--dry-run") ? true : false;
const arweave = Arweave.init({
  host: "arweave.net",
  port: 443,
  protocol: "https",
});
const wallet = JSON.parse(
  fs.readFileSync(path.join(__dirname, "key.json"), "utf8"),
);
const signer = new ArweaveSigner(wallet);
const ao = connect({
  CU_URL: "https://cu.ar-io.dev",
});
async function main() {
  const csv = fs.readFileSync(path.join(__dirname, inputFilePath), "utf8");

  // print out address of wallet being used
  const address = await arweave.wallets.jwkToAddress(wallet);
  console.log(`Using wallet ${address} to migrate process ids on IO registry`);

  const migratedProcessIds = csv
    .split("\n")
    .slice(1) // skip header
    .map((line) => line.split(","))
    .filter(
      ([
        domain,
        oldProcessId,
        newProcessId,
        sourceCodeUpdated,
        sdkVerified,
        initializeStateMessageId,
        stateMatchVerified,
      ]) =>
        domain &&
        oldProcessId &&
        newProcessId &&
        sourceCodeUpdated &&
        sdkVerified &&
        initializeStateMessageId &&
        stateMatchVerified,
    );

  const adminProcess = new AOProcess({
    signer: createAoSigner(wallet),
    processId: IO_TESTNET_PROCESS_ID,
    ao: ao,
  });
  const io = IO.init({
    process: adminProcess,
  });

  const limit = pLimit(10);

  // output file
  const outputFilePath = path.join(__dirname, "final-migration-results.csv");
  fs.writeFileSync(outputFilePath, "domain,oldProcessId,newProcessId,sourceCodeUpdated,sdkVerified,initializeStateMessageId,stateMatchVerified,migratedOnRegistry,updateRecordMessageId\n");

  await Promise.all(
    migratedProcessIds.map(
      async ([
        domain,
        oldProcessId,
        newProcessId,
        sourceCodeUpdated,
        sdkVerified,
        initializeStateMessageId,
        stateMatchVerified,
      ]) => {
        return limit(async () => {
          // check that io has the arns record we are about to update
          const arnsRecord = await io.getArNSRecord({ name: domain });
          if (!arnsRecord) {
            console.error(`ARNs record not found for ${domain}`);
            return;
          }

          // get the process id currently used by the arns record, if it does not match new process id, it will be migrated
          const currentProcessId = arnsRecord.processId;
          if (currentProcessId === newProcessId) {
            // get AddRecord data item with name from graphql
            const messageId = await arweave.api.post('/graphql', {
              query: `
                {
                  transactions(tags: [{ name: "Action", values: ["AddRecord"] }, { name: "Name", values: ["${domain}"]}] sort:HEIGHT_DESC, first:1) {
                  edges {
                    node {
                      id
                    }
                  }
                }
              }
            `,
            }).then(({ data }) => data?.data?.transactions?.edges[0]?.node?.id);
            console.log(
              `Process id ${currentProcessId} already matches new process id ${newProcessId} for ${domain}. Skipping.`,
            );
            fs.appendFileSync(outputFilePath, `${domain},${oldProcessId},${newProcessId},${sourceCodeUpdated},${sdkVerified},${initializeStateMessageId},${stateMatchVerified},true,${messageId}\n`);
            // wait 3 seconds for the record to be updated
            await new Promise((resolve) => setTimeout(resolve, 3000));
            return;
          }

          console.log(
            `Process id ${currentProcessId} does not match new process id ${newProcessId} for ${domain}. Eligible for migration.`,
          );

          const updatedRecordData = {
            type: arnsRecord.type,
            startTimestamp: arnsRecord.startTimestamp,
            processId: newProcessId,
            undernameLimit: arnsRecord.undernameLimit,
            purchasePrice: arnsRecord.purchasePrice,
            ...(arnsRecord.type === "lease"
              ? { endTimestamp: arnsRecord.endTimestamp }
              : {}),
          };

          const {
            processId: _oldProcessId,
            ...previousRecordWithoutProcessId
          } = arnsRecord;
          const { processId: _newProcessId, ...newRecordWithoutProcessId } =
            updatedRecordData;

          // assert the only thing that is different is the process id
          assert.deepEqual(
            previousRecordWithoutProcessId,
            newRecordWithoutProcessId,
            "Updated record data should only differ in process id",
          );

          assert.equal(
            oldProcessId,
            _oldProcessId,
            "Old process id should be the same as the one in the record",
          );

          assert.equal(
            newProcessId,
            _newProcessId,
            "New process id should be the same as the one in the record",
          );

          // assert if it is a permabuy endTimestamp is empty and if a least timestamp is not empty
          if (arnsRecord.type === "permabuy") {
            assert.equal(
              arnsRecord.endTimestamp,
              undefined,
              "End timestamp should be empty for permabuy",
            );
          }

          if (arnsRecord.type === "lease") {
            assert.notEqual(
              arnsRecord.startTimestamp,
              undefined,
              "Start timestamp should not be empty for lease",
            );
          }

          console.log(`Updating record for ${domain} with process id ${newProcessId}`);

          if (dryRun) {
            console.log(
              `Dry run: would update record ${JSON.stringify(updatedRecordData)} for ${domain}`,
            );
            fs.appendFileSync(outputFilePath, `${domain},${oldProcessId},${newProcessId},${sourceCodeUpdated},${sdkVerified},${initializeStateMessageId},${stateMatchVerified},false,null\n`);
            return;
          }


          const updateRecordMessage = await adminProcess.send({
            signer: createAoSigner(signer),
            tags: [
              { name: "Action", value: "AddRecord" },
              { name: 'Name', value: domain},
            ],
            data: JSON.stringify(updatedRecordData),
          })

          console.log(`Update record message id: ${updateRecordMessage.id}`);
          // wait 3 seconds for the record to be updated
          await new Promise((resolve) => setTimeout(resolve, 3000));
          // assert that fetching the record after the update returns the updated record
          const updatedRecord = await io.getArNSRecord({ name: domain });
          assert.deepEqual(
            updatedRecord,
            updatedRecordData,
            "Updated record should be the same as the one in the registry",
          );

          fs.appendFileSync(outputFilePath, `${domain},${oldProcessId},${newProcessId},${sourceCodeUpdated},${sdkVerified},${initializeStateMessageId},${stateMatchVerified},true,${updateRecordMessage.id}\n`);
        });
      },
    ),
  );
}

main();
