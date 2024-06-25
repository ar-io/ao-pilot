import { IOToken } from "@ar.io/sdk";
import {
  devnetContract,
  excludeWallets,
  ioContract,
  teamMembers,
} from "./setup.js";

(async () => {
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
    if (teamMembers.has(address)) {
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
    if (teamMembers.has(delegate)) {
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
  const updatedBalances = await ioContract.getBalances().catch((e: any) => {
    console.error("Failed to get updated balances:", e);
  });

  if (updatedBalances) {
    console.log(
      "Updated balances. Total count",
      Object.keys(updatedBalances).length,
    );
  }
})();
