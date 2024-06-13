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
const moduleId = 'QK1G2K9V2a_WKVkQFdjr3hjWcSjutnMTFxIXeg_3LMQ';
const scheduler = '_GQ33BkPtZrqxA84vM8Zk-N2aO0toNNu_C-l-rawrBA';

async function main() {
  const wallet = fs.readFileSync(path.join(__dirname, 'key.json'), 'utf-8');
  const address = await arweave.wallets.jwkToAddress(JSON.parse(wallet));
  const signer = createDataItemSigner(JSON.parse(wallet));

  // const processId = await ao.spawn({
  //   module: moduleId,
  //   scheduler,
  //   signer,
  // });
  const processId = 'AxHXaiKg7c4FAYZ5eo4OPAaEhmB0I0PRxLqzW6ZNHXk';
  console.log('Process ID:', processId);
  console.log('Waiting 20 seconds to ensure process is readied.');
  await new Promise((resolve) => setTimeout(resolve, 2_000));
  console.log('Continuing...');

  const testCases = [
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
    ['Initialize-State', {}],
  ];

  for (const [method, args] of testCases) {
    const tags = args
      ? Object.entries(args).map(([key, value]) => ({ name: key, value }))
      : [];
    const result = await ao.dryrun({
      process: processId,
      tags: [...tags, { name: 'Action', value: method }],
      data: JSON.stringify({
        balances: { '7waR8v4STuwPnTck1zFVkQqJh5K9q9Zik4Y5-5dV7nk': 1 },
        controllers: ['7waR8v4STuwPnTck1zFVkQqJh5K9q9Zik4Y5-5dV7nk'],
        name: 'ANT-ARDRIVE',
        owner: '7waR8v4STuwPnTck1zFVkQqJh5K9q9Zik4Y5-5dV7nk',
        records: {
          '@': {
            transactionId: 'UyC5P5qKPZaltMmmZAWdakhlDXsBF6qmyrbWYFchRTk',
            ttlSeconds: 3600,
          },
        },
        ticker: 'ANT',
      }),
      signer,
    });

    console.dir({ method, result }, { depth: null });
  }
}

main();
