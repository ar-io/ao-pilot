import { createDataItemSigner, connect } from "@permaweb/aoconnect";
import { IOToken } from "@ar.io/sdk";
import { devnetContract, ioContract, jwk, migratedProcessId } from "./setup.js";

(async () => {
  // fetch gateways from contract
  const gateways = await devnetContract.getGateways({
    evaluationOptions: {
      evalTo: {
        blockHeight: 14990000,
      },
    },
  });
  const { message, result } = await connect();
  const defaultStartTimestamp = new Date('06/25/2024').getTime()
  for (const [address, gateway] of Object.entries(gateways)) {
    if (gateway.status === "leaving") {
      continue;
    }

    // exclude if we already migrated this gateway
    const gatewayData = await ioContract.getGateway({ address });
    if (gatewayData) {
      console.log('Skipping already migrated gateway', address)
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
        settings: {
          ...gateway.settings,
          minDelegatedStake: new IOToken(500).toMIO().valueOf(),
        },
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
  if (allGateways){
    console.log('Migrated gateways. Total count:', Object.keys(allGateways).length)
  }
})();
