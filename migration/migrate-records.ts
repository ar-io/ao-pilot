import { createDataItemSigner, connect } from "@permaweb/aoconnect";
import {
  ANT,
  ArIO,
  ArweaveSigner,
  IO,
  spawnANT,
} from "@ar.io/sdk";
import Arweave from "arweave";

import fs from "fs";
import path from "path";

const dirname = new URL(import.meta.url).pathname;
const jwk = JSON.parse(
  fs.readFileSync(path.join(dirname, "../wallet.json")).toString(),
);
const migratedProcessId = "DxzlVyR08GcfaY3jUTHN3XnRxBc4LJcuUpbSexb2q5w";
const defaultTxId = "UyC5P5qKPZaltMmmZAWdakhlDXsBF6qmyrbWYFchRTk";
const luaCodeTxId = 'wAvAD3KalWDEU_JB3QIX_Z27v8oCsnsfPtUDkGaPJns'
const main = async () => {
  // fetch gateways from contract
  const devnetContract = ArIO.init({
    contractTxId: 'bLAgYxAdX2Ry-nt6aH2ixgvJXbpsEYm28NgJgyqfs-U',
  });
  const aoContract = IO.init({
    processId: migratedProcessId,
  });
  const records = await devnetContract.getArNSRecords({
    evaluationOptions: {
      evalTo: {
        blockHeight: 14990000,
      },
    },
  });
  const arweave = Arweave.init({
    host: "arweave.net",
    port: 443,
    protocol: "https",
  });
  const owner = await arweave.wallets.jwkToAddress(jwk);
  const { message, result } = await connect();
  const signer = new ArweaveSigner(jwk);
  const uniqueSetOfContractTxIds = new Set(
    Object.values(records).map((record) => record.contractTxId),
  );
  const mapOfContractTxIdToAntTxId: Record<string, string> = {};
  for (const contractTxId of uniqueSetOfContractTxIds) {
    // get the smartweave state
    const smartweaveANT = ANT.init({ contractTxId });
    const state = await smartweaveANT.getState().catch((e) => {
      console.error("Failed to get state for contract:", contractTxId, e);
    });

    if (!state) {
      console.error("Failed to get state for contract:", contractTxId);
      continue;
    }

    if ((state as any).initState) {
      continue;
    }

    // for now we'll override owner and controllers to be the calling wallet
    state.owner = owner;
    state.controllers = [owner];
    state.balances = { [owner]: 1 };
    // override the owner to be the calling wallet
    //  state.controllers = [(state as any).controller || owner] || [...state.controllers, owner]

    if ((state as any).controller) {
      delete (state as any).controller;
    }

    // migrate any broken records
    for (const [undername, record] of Object.entries(state.records)) {
      if (typeof record === "string") {
        state.records[undername] = {
          transactionId: record || defaultTxId,
          ttlSeconds: 3600,
        };
      } else {
        state.records[undername] = {
          transactionId: record.transactionId || defaultTxId,
          ttlSeconds: record.ttlSeconds || 3600,
        };
      }
    }
    console.log("Updated ANT state for contract:", contractTxId, state);
    const processId = await spawnANT({
      signer,
      luaCodeTxId,
      state,
      stateContractTxId: contractTxId,
    });
    console.log('Spawned ANT process', processId, 'for contract', contractTxId)
    mapOfContractTxIdToAntTxId[contractTxId] = processId;
    break;
  }
  // const currentBlock = await arweave.blocks.getCurrent();
  for (const [name, record] of Object.entries(records)) {
    // if we don't have a mapped process id, skip
    if (!mapOfContractTxIdToAntTxId[record.contractTxId]) {
      console.error(
        "No mapped process id for record:",
        name,
        record.contractTxId,
      );
      continue;
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
        { name: "AO-Record-Details", value: JSON.stringify(updatedRecord)},
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
      continue;
    }
    // get the update record
    const newAORecord = await aoContract.getArNSRecord({ name });
    if (!newAORecord) {
      console.error("Failed to get updated record:", name);
      continue;
    }
    console.log("Updated record successfully!", name, newAORecord);
  }

  console.log("Finished migrating records", 
    mapOfContractTxIdToAntTxId,
  )

  // // migrate reserved names
  const reservedNames = await devnetContract.getArNSReservedNames({});
  for (const [name, reservedName] of Object.entries(reservedNames)) {
      const { message, result } = await connect(jwk)
      const messageTxId = await message({
          process: migratedProcessId,
          tags: [
              { name: 'Action', value: 'AddReservedName' },
              { name: 'Name', value: name},
          ],
          data: JSON.stringify({
              ...reservedName.endTimestamp ? { endTimestamp: (Date.now()) + (1000 * 60 * 60 * 24 * 365 * 1)  }: {}, // 1 year
              ...reservedName.target ? { target: reservedName.target }: {},
          }),
          signer: createDataItemSigner(jwk),
      });
      console.log('Sent data to process', messageTxId)
      const res = await result({
          message: messageTxId,
          process: migratedProcessId
      })
      console.log('Result:', res)
  }
};

main();
