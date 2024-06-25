import { ArIO, IOToken, IO, ArweaveSigner } from "@ar.io/sdk";

import fs from "fs";
import path from "path";

const migratedProcessId = "GaQrvEMKBpkjofgnBi_B3IgIDmY_XYelVLB6GcRGrHc";
const smartWeaveTxId = "bLAgYxAdX2Ry-nt6aH2ixgvJXbpsEYm28NgJgyqfs-U";
const dirname = new URL(import.meta.url).pathname;
const jwk = JSON.parse(
  fs.readFileSync(path.join(dirname, "../wallet.json")).toString(),
);

// give team members additional tokens
const teamMembers = new Set([
    "6Z-ifqgVi1jOwMvSNwKWs6ewUEQ0gU9eo4aHYC3rN1M", // anthony
    "nszYSUJvtlFXssccPaQWZaVpkXgJHcVM7XhcP5NEt7w", // jonathon,
    "GtDQcrr2QRdoZ-lKto_S_SpzEwiZiHVaj3x4jAgRh4o", // stephen
    "ZjmB2vEUlHlJ7-rgJkYP09N5IzLPhJyStVrK5u9dDEo", // dylan.ar
    "1H7WZIWhzwTH9FIcnuMqYkTsoyv1OTfGa_amvuYwrgo", // permagate.ar
    "NdZ3YRwMB2AMwwFYjKn1g88Y9nRybTo0qhS1ORq_E7g", // phil
    "7waR8v4STuwPnTck1zFVkQqJh5K9q9Zik4Y5-5dV7nk", // atticus
    "N4h8M9A9hasa3tF47qQyNvcKjm4APBKuFs7vqUVm-SI", // steven
    "9jfM0uzGNc9Mkhjo1ixGoqM7ygSem9wx_EokiVgi0Bs", // gisela
    "hNtcagQ0tlXOLM8uhwI408efFSI5DiqHGoP_BqUfzOQ", // david
    // TODO: add anyone else
]);
const excludeWallets = new Set([smartWeaveTxId, teamMembers]); // TODO: add team wallets

const main = async () => {
  // fetch gateways from contract
  const devnetContract = ArIO.init({
    contractTxId: smartWeaveTxId,
  });
  const ioContract = IO.init({
    processId: migratedProcessId,
    signer: new ArweaveSigner(jwk),
  });
  const balances = await devnetContract.getBalances({
    evaluationOptions: {
      evalTo: {
        blockHeight: 14990000,
      },
    },
  });
  const gateways = await devnetContract.getGateways({
    evaluationOptions: {
      evalTo: {
        blockHeight: 14990000,
      },
    },
  });

  // anyone with a balance 750 IO
  for (const address of Object.keys(balances)) {
    // exclude bad wallets and team wallets
    if (excludeWallets.has(address)) {
      continue;
    }

    await ioContract
      .transfer(
        {
          target: address,
          qty: new IOToken(750).toMIO().valueOf(),
        },
        {
          tags: [{ name: "X-Transfer-Reason", value: "Balance-Holder" }],
        },
      )
      .catch((e: any) => {
        console.error("Failed to transfer tokens for balance holder:", e);
      });
  }

  // give gateway operators an additional 1000 IO
  for (const [address, gateway] of Object.entries(gateways)) {
    if (gateway.status === "leaving") {
      // console.log('Skipping leaving gateway', address)
      continue;
    }
    // exclude bad wallets and team wallets
    if (excludeWallets.has(address)) {
      continue;
    }
    await ioContract
      .transfer(
        {
          target: address,
          qty: new IOToken(1000).toMIO().valueOf(),
        },
        {
          tags: [{ name: "X-Transfer-Reason", value: "Gateway-Operator" }],
        },
      )
      .catch((e: any) => {
        console.error("Failed to transfer tokens for gateway operator:", e);
      });
  }

  // give delegates of gateways 750 tokens (only once)
  const delegates = Object.values(gateways).reduce((acc: string[], gateway) => {
    for (const delegate of Object.keys(gateway.delegates)) {
      if (acc.includes(delegate)) {
        continue;
      }
      acc.push(delegate);
    }
    return acc;
  }, []);

  const uniqueDelegates = Array.from(new Set(delegates));
  for (const delegate of uniqueDelegates) {
    // exclude other wallets
    if (excludeWallets.has(delegate)) {
      continue;
    }
    await ioContract
      .transfer(
        {
          target: delegate,
          qty: new IOToken(750).toMIO().valueOf(),
        },
        {
          tags: [{ name: "X-Transfer-Reason", value: "Gateway-Delegate" }],
        },
      )
      .catch((e: any) => {
        console.error("Failed to transfer tokens for delegate:", e);
      });
  }

    for (const teamMember of teamMembers) {
        await ioContract
            .transfer(
                {
                    target: teamMember,
                    qty: new IOToken(1_000_000).toMIO().valueOf(),
                },
                {
                    tags: [{ name: "X-Transfer-Reason", value: "AR-IO-Team-Member" }],
                },
            )
            .catch((e: any) => {
                console.error("Failed to transfer tokens for team member:", e);
            });
    }

  // get the updated balances on io contract
  const updatedBalances = await ioContract.getBalances();
  console.log("Updated balances:", updatedBalances);
};

main();
