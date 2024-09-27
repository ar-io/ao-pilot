import {
  IO,
  IO_DEVNET_PROCESS_ID,
  ArweaveSigner,
  AOProcess,
  IOToken,
} from '@ar.io/sdk';
import { connect } from '@permaweb/aoconnect';
import Arweave from 'arweave';
import fs from 'node:fs';
import path from 'node:path';

const dirname = new URL('.', import.meta.url).pathname;
const arweave = Arweave.init({
  host: 'arweave.net',
  port: 443,
  protocol: 'https',
});
const liveWallet = JSON.parse(
  fs.readFileSync(path.join(dirname, 'key.json'), 'utf8'),
);
const liveSigner = new ArweaveSigner(liveWallet);
const aoClient = connect({
  CU_URL: 'https://cu.ar-io.dev',
});

const randomName = () => {
  let name = '';
  const characters = 'abcdefghijklmnopqrstuvwxyz0123456789';
  for (let i = 0; i < 50; i++) {
    const randomIndex = Math.floor(Math.random() * characters.length);
    name += characters[randomIndex];
  }
  return name;
};

async function main() {
  const testWallet = await arweave.wallets.generate();
  const testSigner = new ArweaveSigner(testWallet);
  const io = IO.init({
    process: new AOProcess({
      ao: aoClient,
      processId: IO_DEVNET_PROCESS_ID,
    }),
    signer: testSigner,
  });
  // transfer necessary funds to the test wallet
  const tempIo = IO.init({
    process: new AOProcess({
      ao: aoClient,
      processId: IO_DEVNET_PROCESS_ID,
    }),
    signer: liveSigner,
  });
  await tempIo.transfer({
    target: await arweave.wallets.jwkToAddress(testWallet),
    qty: new IOToken(20000).toMIO().valueOf(),
  });

  await io
    .increaseUndernameLimit({
      name: 'ardrive',
      increaseCount: 1,
    })
    .then((res) => console.log(res))
    .catch((error) => console.error(error));

  // write to each api on the write
  const name = randomName();
  const gateway = '1H7WZIWhzwTH9FIcnuMqYkTsoyv1OTfGa_amvuYwrgo';
  // const buyRecordArgs = [
  //   ...Array(100).map(() => ({
  //     name: randomName(),
  //     years: 1,
  //     type: 'lease',
  //     processId: ''.padEnd(43, '12'),
  //   })),
  //   {
  //     name,
  //     years: 1,
  //     type: 'lease',
  //     processId: ''.padEnd(43, '12'),
  //   },
  //   {
  //     name,
  //     years: 1,
  //     type: 'lease',
  //     processId: ''.padEnd(10, '12'),
  //   },
  //   {
  //     name,
  //     years: 10,
  //     type: 'lease',
  //     processId: ''.padEnd(43, '12'),
  //   },
  //   {
  //     name,
  //     years: 1,
  //     type: 'BOOM SHAKALA MY MAN',
  //     processId: ''.padEnd(43, '12'),
  //   },
  //   {
  //     name: ''.padEnd(500, 'a'),
  //     years: 1,
  //     type: 'lease',
  //     processId: ''.padEnd(43, '12'),
  //   },
  // ];
  // buyRecordArgs.forEach((args) => {
  //   io.buyRecord(args).catch((error) => console.error(error));
  // });

  // const leaseArgs = [
  //   {
  //     name,
  //     years: 1,
  //   },
  //   {
  //     name: ''.padEnd(500, 'a'),
  //     years: 1,
  //   },
  //   {
  //     name,
  //     years: Infinity,
  //   },
  //   {
  //     name,
  //     years: -Infinity,
  //   },
  //   {
  //     name,
  //     years: NaN,
  //   },
  //   {
  //     name,
  //     years: null,
  //   },
  // ];

  // leaseArgs.forEach((args) => {
  //   io.extendLease(args).catch((error) => console.error(error));
  // });

  const increaseUndernameArgs = [
    {
      name: 'ardrive',
      increaseCount: 1,
    },
    //   {
    //     name,
    //     increaseCount: 0,
    //   },
    //   {
    //     name,
    //     increaseCount: -1,
    //   },
    //   {
    //     name,
    //     increaseCount: Infinity,
    //   },
    //   {
    //     name,
    //     increaseCount: -Infinity,
    //   },
    //   {
    //     name,
    //     increaseCount: NaN,
    //   },
    //   {
    //     name,
    //     increaseCount: null,
    //   },
  ];
  increaseUndernameArgs.forEach((args) => {
    io.increaseUndernameLimit(args).catch((error) => console.error(error));
  });

  // const delegateStakeArgs = [
  //   {
  //     target: name,
  //     stakeQty: 1000,
  //   },
  //   {
  //     target: name,
  //     stakeQty: 0,
  //   },
  //   {
  //     target: name,
  //     stakeQty: -1,
  //   },
  //   {
  //     target: name,
  //     stakeQty: Infinity,
  //   },
  //   {
  //     target: name,
  //     stakeQty: -Infinity,
  //   },
  //   {
  //     target: name,
  //     stakeQty: NaN,
  //   },
  //   {
  //     target: name,
  //     stakeQty: null,
  //   },
  // ];
  // delegateStakeArgs.forEach((args) => {
  //   io.delegateStake(args).catch((error) => console.error(error));
  // });

  // const increaseOperatorStakeArgs = [
  //   {
  //     increaseQty: 1000,
  //   },
  //   {
  //     increaseQty: 0,
  //   },
  //   {
  //     increaseQty: -1,
  //   },
  //   {
  //     increaseQty: Infinity,
  //   },
  //   {
  //     increaseQty: -Infinity,
  //   },
  //   {
  //     increaseQty: NaN,
  //   },
  //   {
  //     increaseQty: null,
  //   },
  // ];
  // increaseOperatorStakeArgs.forEach((args) => {
  //   io.increaseOperatorStake(args).catch((error) => console.error(error));
  // });
  // const decreaseDelegateStakeArgs = [
  //   {
  //     target: name,
  //     decreaseQty: 1000,
  //   },
  //   {
  //     target: name,
  //     decreaseQty: 0,
  //   },
  //   {
  //     target: name,
  //     decreaseQty: -1,
  //   },
  //   {
  //     target: name,
  //     decreaseQty: Infinity,
  //   },
  //   {
  //     target: name,
  //     decreaseQty: -Infinity,
  //   },
  //   {
  //     target: name,
  //     decreaseQty: NaN,
  //   },
  //   {
  //     target: name,
  //     decreaseQty: null,
  //   },
  // ];
  // decreaseDelegateStakeArgs.forEach((args) => {
  //   io.decreaseDelegateStake(args).catch((error) => console.error(error));
  // });

  // const decreaseOperatorStakeArgs = [
  //   {
  //     decreaseQty: 1000,
  //   },
  //   {
  //     decreaseQty: 0,
  //   },
  //   {
  //     decreaseQty: -1,
  //   },
  //   {
  //     decreaseQty: Infinity,
  //   },
  //   {
  //     decreaseQty: -Infinity,
  //   },
  //   {
  //     decreaseQty: NaN,
  //   },
  //   {
  //     decreaseQty: null,
  //   },
  // ];
  // decreaseOperatorStakeArgs.forEach((args) => {
  //   io.decreaseOperatorStake(args).catch((error) => console.error(error));
  // });

  // const transferArgs = [
  //   {
  //     target: gateway,
  //     qty: 1000,
  //   },
  //   {
  //     target: gateway,
  //     qty: 0,
  //   },
  //   {
  //     target: gateway,
  //     qty: -1,
  //   },
  //   {
  //     target: gateway,
  //     qty: Infinity,
  //   },
  //   {
  //     target: gateway,
  //     qty: -Infinity,
  //   },
  //   {
  //     target: gateway,
  //     qty: NaN,
  //   },
  //   {
  //     target: gateway,
  //     qty: null,
  //   },
  // ];
  // transferArgs.forEach((args) => {
  //   io.transfer(args).catch((error) => console.error(error));
  // });

  // const joinNetworkArgs = [
  //   {
  //     operatorStake: new IOToken(10000).toMIO().valueOf(),
  //     allowDelegatedStaking: true,
  //     delegateRewardShareRatio: 0.5,
  //     fqdn: name,
  //     label: name,
  //     minDelegatedStake: 100,
  //     note: 'note',
  //     port: 443,
  //     properties: ''.padEnd(43, '12'),
  //     autoStake: true,
  //     observerAddress: gateway,
  //   },
  //   {
  //     operatorStake: 1000,
  //     allowDelegatedStaking: true,
  //     delegateRewardShareRatio: 0.5,
  //     fqdn: name,
  //     label: name,
  //     minDelegatedStake: 100,
  //     note: 'note',
  //     port: 443,
  //     properties: ''.padEnd(10, '12'),
  //     autoStake: true,
  //     observerAddress: gateway,
  //   },
  //   {
  //     operatorStake: 1000,
  //     allowDelegatedStaking: true,
  //     delegateRewardShareRatio: 0.5,
  //     fqdn: name,
  //     label: name,
  //     minDelegatedStake: 100,
  //     note: 'note',
  //     port: 443,
  //     properties: ''.padEnd(43, '12'),
  //     autoStake: true,
  //     observerAddress: gateway,
  //   },
  //   {
  //     operatorStake: 1000,
  //     allowDelegatedStaking: true,
  //     delegateRewardShareRatio: 0.5,
  //     fqdn: ''.padEnd(500, 'a'),
  //     label: name,
  //     minDelegatedStake: 100,
  //     note: 'note',
  //     port: 443,
  //     properties: ''.padEnd(43, '12'),
  //     autoStake: true,
  //     observerAddress: gateway,
  //   },
  // ];

  // joinNetworkArgs.forEach((args) => {
  //   io.joinNetwork(args).catch((error) => console.error(error));
  // });

  // io.leaveNetwork().catch((error) => console.error(error));
}

main();
