import { createDataItemSigner, connect } from "@permaweb/aoconnect";
import { ANT, spawnANT } from "@ar.io/sdk";
import {
  devnetContract,
  jwk,
  migratedProcessId,
  teamMembers,
  signer,
  ioContract,
  arweave,
} from "./setup.js";
import {pLimit} from "plimit-lit";

const defaultTxId = "UyC5P5qKPZaltMmmZAWdakhlDXsBF6qmyrbWYFchRTk";
const luaCodeTxId = "wAvAD3KalWDEU_JB3QIX_Z27v8oCsnsfPtUDkGaPJns";
const throttle = pLimit(10);
(async () => {
  const records = await devnetContract.getArNSRecords({
    evaluationOptions: {
      evalTo: {
        blockHeight: 14990000,
      },
    },
  });

  const { message, result } = await connect();
  const uniqueSetOfContractTxIds = new Set(
    Object.values(records).map((record) => record.contractTxId),
  );
  const mapOfContractTxIdToAntTxId: Record<string, string> = {};
  await Promise.all(
    [...uniqueSetOfContractTxIds].map((contractTxId: string) =>
      throttle(async () => {
        // search graphql for the AO process id of the contractTxId and if it's using the module 'txId' we can skip
        const graphqlQuery = `
      {
    
        transactions(
          tags: [
            { name: "State-Contract-TX-ID", values: ["${contractTxId}"] }
            { name: "Action", values: ["Initialize-State"] }
            { name: "Source-Code-TX-ID", values: ["${luaCodeTxId}"] }
          ]
        ) {
          edges {
            node {
              id
              tags {
                name
                value
              }
            }
          }
        }
      }
    `;

        const res = await arweave.api.post("/graphql", { query: graphqlQuery });

        if (res.status !== 200) {
          console.error("Failed to query graphql for contract:", contractTxId, res.status);
          return;
        }

        const { data } = res.data;
        if (data.transactions.edges.length) {
          // parse out the process id
          const processId = data.transactions.edges[0].node.tags.find(
            (tag) => tag.name === "Process-Id",
          );

          // check the owner
          const ioANT = ANT.init({ processId: processId.value });
          const [owner, apexRecord] = await Promise.all([
            ioANT.getOwner(),
            ioANT.getRecord({ undername: "@" }),
          ]);

          // TODO: check that it's got the correct module id

          if (owner && apexRecord) {
            console.log(
              "Skipping already migrated contract",
              contractTxId,
              processId.value,
            );
            mapOfContractTxIdToAntTxId[contractTxId] = processId.value;
            return;
          }
        }

        // get the smartweave state
        const smartweaveANT = ANT.init({ contractTxId });
        const state = await smartweaveANT.getState().catch((e) => {
          console.error("Failed to get state for contract:", contractTxId, e);
        });

        if (!state) {
          console.error("Failed to get state for contract:", contractTxId);
          return;
        }

        if ((state as any).initState) {
          return;
        }

        // override the owner to be the calling wallet
        if ((state as any).controller) {
          state.controllers = [(state as any).controller];
          delete (state as any).controller;
        }

        // for now - only migrate wallets owned by team members
        if (!state.owner || !teamMembers.has(state.owner)) {
          console.log(
            "Skipping contract not owned by team member:",
            contractTxId,
          );
          return;
        }

        // migrate any broken records
        for (const [undername, record] of Object.entries(state.records)) {
          // if undername matches the name of the contract, skip
          if (typeof record === "string") {
            state.records[undername] = {
              transactionId: record || defaultTxId,
              ttlSeconds: 3600,
            };
          } else {
            state.records[undername] = {
              transactionId: record.transactionId || defaultTxId,
              ttlSeconds: Math.min(record.ttlSeconds || 3600, 3600),
            };
          }
        }

        const processId = await spawnANT({
          signer,
          luaCodeTxId,
          state,
          stateContractTxId: contractTxId,
        }).catch((e) => {
          console.error(
            "Failed to spawn process for contract:",
            contractTxId,
            e,
          );
        });

        if (!processId) {
          console.error("Failed to spawn process for contract:", contractTxId);
          return;
        }
        console.log("Spawned process for contract:", contractTxId, processId);
        mapOfContractTxIdToAntTxId[contractTxId] = processId;
      }),
    ),
  );

  await Promise.all(Object.entries(records).map(([name, record]) => throttle(async () => {
    // if we don't have a mapped process id, skip
    if (!mapOfContractTxIdToAntTxId[record.contractTxId]) {
      console.error(
        "No mapped process id for record:",
        name,
        record.contractTxId,
      );
      return;
    }

    // check that the record does not already exist
    const existingRecord = await ioContract.getArNSRecord({
      name: name,
    });

    if (existingRecord) {
      const aoIOAnt = ANT.init({ processId: existingRecord?.processId });

      // confirm basic interactions
      const [owner, apexRecord] = await Promise.all([
        aoIOAnt.getOwner(),
        aoIOAnt.getRecord({ undername: "@" }),
      ]);

      if (
        owner &&
        apexRecord &&
        existingRecord?.processId ===
          mapOfContractTxIdToAntTxId[record.contractTxId]
      ) {
        console.log("Record already migrated skipping...", name);
        return;
      }
    }

    const updatedRecord = {
      type: record.type,
      startTimestamp: record.startTimestamp * 1000, // use existing start timestamp
      // convert it to milliseconds and add 2 years
      ...(record.type === "lease"
        ? { endTimestamp: record.endTimestamp * 1000 }
        : {}), // use existing end timestamp
      processId: mapOfContractTxIdToAntTxId[record.contractTxId],
      undernameLimit: record.undernames,
      purchasePrice: Math.floor(record.purchasePrice),
    };
    const messageTxId = await message({
      process: migratedProcessId,
      tags: [
        {
          name: "Process-Id",
          value: mapOfContractTxIdToAntTxId[record.contractTxId],
        },
        { name: "Action", value: "AddRecord" },
        { name: "Name", value: name },
        { name: "Contract-Tx-Id", value: record.contractTxId },
        { name: "Smartweave-Record-Details", value: JSON.stringify(record) },
        { name: "AO-Record-Details", value: JSON.stringify(updatedRecord) },
      ],
      data: JSON.stringify(updatedRecord),
      signer: createDataItemSigner(jwk),
    });
    const res = await result({
      message: messageTxId,
      process: migratedProcessId,
    });

    if ((res as any).error) {
      console.error("Failed to add record:", name, res);
      return;
    }
    // get the update record
    const newAORecord = await ioContract.getArNSRecord({ name });
    if (!newAORecord) {
      console.error("Failed to get updated record:", name);
      return;
    }
    console.log("Migrated record successfully", {
      name,
      contractTxId: record.contractTxId,
      processId: mapOfContractTxIdToAntTxId[record.contractTxId],
    });
  })));

  const allRecords = await ioContract.getArNSRecords();
  console.log("Migrated records. Total count:", Object.keys(allRecords).length);

  // // migrate reserved names
  const reservedNames = await devnetContract.getArNSReservedNames({});
  for (const [name, reservedName] of Object.entries(reservedNames)) {
    const { message, result } = await connect(jwk);
    const messageTxId = await message({
      process: migratedProcessId,
      tags: [
        { name: "Action", value: "AddReservedName" },
        { name: "Name", value: name },
      ],
      data: JSON.stringify({
        ...(reservedName.endTimestamp
          ? { endTimestamp: Date.now() + 1000 * 60 * 60 * 24 * 365 * 1 }
          : {}), // 1 year
        ...(reservedName.target ? { target: reservedName.target } : {}),
      }),
      signer: createDataItemSigner(jwk),
    });
    const res = await result({
      message: messageTxId,
      process: migratedProcessId,
    });

    if ((res as any).error) {
      console.error("Failed to add reserved name:", name, res);
      continue;
    }
  }

  const allReservedNames = await ioContract.getArNSReservedNames();
  console.log(
    "Migrated reserved names. Total count:",
    Object.keys(allReservedNames).length,
  );
})();
