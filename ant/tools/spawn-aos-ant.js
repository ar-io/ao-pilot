const { connect, createDataItemSigner } = require('@permaweb/aoconnect');
const fs = require('fs');
const path = require('path');
const Arweave = require('arweave');

const arweave = Arweave.init({
  host: 'arweave.net',
  port: 443,
  protocol: 'https',
});

const ao = connect({
  GATEWAY_URL: 'https://arweave.net',
});
const moduleId = '9afQ1PLf2mrshqCTZEzzJTR2gWaC9zNPnYgYEqg1Pt4';
const scheduler = '_GQ33BkPtZrqxA84vM8Zk-N2aO0toNNu_C-l-rawrBA';

async function main() {
  const luaCode = fs.readFileSync(
    path.join(__dirname, '../dist/aos-ant-bundled.lua'),
    'utf-8',
  );

  const wallet = fs.readFileSync(path.join(__dirname, 'key.json'), 'utf-8');
  const address = await arweave.wallets.jwkToAddress(JSON.parse(wallet));
  const signer = createDataItemSigner(JSON.parse(wallet));

  const initState = JSON.stringify({
    balances: { [address]: 1 },
    controllers: [address],
    name: 'ANT-ARDRIVE',
    owner: address,
    records: {
      '@': {
        transactionId: 'UyC5P5qKPZaltMmmZAWdakhlDXsBF6qmyrbWYFchRTk',
        ttlSeconds: 3600,
      },
    },
    ticker: 'ANT',
  });

  const processId = await ao.spawn({
    module: moduleId,
    scheduler,
    signer,
  });

  console.log('Process ID:', processId);
  console.log('Waiting 20 seconds to ensure process is readied.');
  await new Promise((resolve) => setTimeout(resolve, 20_000));
  console.log('Loading ANT Lua code...');

  const testCases = [
    ['Eval', {}, luaCode],
    ['Info', {}],
    ['Set-Controller', { Controller: ''.padEnd(43, '1') }],
    ['Remove-Controller', { Controller: ''.padEnd(43, '1') }],
    ['Set-Name', { Name: 'Test Name' }],
    ['Set-Ticker', { Ticker: 'TEST' }],
    [
      'Set-Record',
      {
        'Transaction-Id': ''.padEnd(43, '1'),
        'TTL-Seconds': '1000',
        'Sub-Domain': '@',
      },
    ],
    [
      'Set-Record',
      {
        'Transaction-Id': ''.padEnd(43, '1'),
        'TTL-Seconds': '1000',
        'Sub-Domain': 'bob',
      },
    ],
    ['Remove-Record', { 'Sub-Domain': 'bob' }],
    ['Balance', {}],
    ['Balance', { Recipient: address }],
    ['Balances', {}],
    ['Get-Controllers', {}],
    ['Get-Records', {}],
    ['Get-Record', { 'Sub-Domain': '@' }],
    ['Initialize-State', {}, initState],
    ['Transfer', { Recipient: 'ZjmB2vEUlHlJ7-rgJkYP09N5IzLPhJyStVrK5u9dDEo' }],
  ];

  for (const [method, args, data] of testCases) {
    const tags = args
      ? Object.entries(args).map(([key, value]) => ({ name: key, value }))
      : [];
    const result = await ao.dryrun({
      process: processId,
      tags: [...tags, { name: 'Action', value: method }],
      data,
      signer,
      Owner: address,
      From: address,
    });

    console.dir({ method, result }, { depth: null });
  }
}

main();
