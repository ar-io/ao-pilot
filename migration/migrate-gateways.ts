import { createDataItemSigner, connect } from "@permaweb/aoconnect";
import { ArIO, IOToken, IO } from "@ar.io/sdk";

import fs from "fs";
import path from "path";

const migratedProcessId = "DxzlVyR08GcfaY3jUTHN3XnRxBc4LJcuUpbSexb2q5w";
const smartWeaveTxId = "bLAgYxAdX2Ry-nt6aH2ixgvJXbpsEYm28NgJgyqfs-U";
const dirname = new URL(import.meta.url).pathname;
const jwk = JSON.parse(
  fs.readFileSync(path.join(dirname, "../wallet.json")).toString(),
);

const main = async () => {
  // fetch gateways from contract
  const devnetContract = ArIO.init({
    contractTxId: smartWeaveTxId,
  });
  const ioContract = IO.init({
    processId: migratedProcessId,
  });
  const gateways = await devnetContract.getGateways({
    evaluationOptions: {
      evalTo: {
        blockHeight: 14990000,
      },
    },
  });
  const { message, result } = await connect();
  const defaultStartTimestamp = 1719273600000;
  for (const [address, gateway] of Object.entries(gateways)) {
    if (gateway.status === "leaving") {
      // console.log('Skipping leaving gateway', address)
      continue;
    }
    const messageTxId = await message({
      process: migratedProcessId,
      tags: [
        { name: "Action", value: "AddGateway" },
        { name: "Address", value: address },
      ],
      data: JSON.stringify({
        observerAddress: gateway.observerWallet,
        operatorStake: new IOToken(50_000).toMIO().valueOf(),
        settings: gateway.settings,
        startTimestamp: defaultStartTimestamp, // 30 days ago
        status: "joined", // only joined are migrated
        totalDelegatedStake: 0, // result delegates,
        stats: {
          totalEpochCount: 0,
          passedEpochCount: 0,
          failedEpochCount: 0,
          observedEpochCount: 0,
          prescribedEpochCount: 0,
          failedConsecutiveEpochs: 0,
          passedConsecutiveEpochs: 0,
        },
        endTimestamp: 0,
        delegates: {}, // result delegates
        vaults: {}, // reset vaults
      }),
      signer: createDataItemSigner(jwk),
    });
    // console.log('Sent data to process', messageTxId)
    const res = await result({
      message: messageTxId,
      process: migratedProcessId,
    });
    if ((res as any).error) {
      console.error("Failed to add gateway:", res);
      continue;
    }
  }
  // use the ar-io-sdk to get gateways from IO contract
  const allGateways = await ioContract.getGateways();
  console.log("All gateways:", allGateways);
};

main();
