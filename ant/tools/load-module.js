const AoLoader = require('@permaweb/ao-loader');
const fs = require('fs');
const path = require('path');

/* ao READ-ONLY Env Variables */
const env = {
  Process: {
    Id: '2',
    Tags: [{ name: 'Authority', value: 'XXXXXX' }],
  },
  Module: {
    Id: '1',
    Tags: [{ name: 'Authority', value: 'YYYYYY' }],
  },
};

async function main() {
  const wasmBinary = fs.readFileSync(
    path.join(__dirname, '../src/process.wasm'),
  );
  // Create the handle function that executes the Wasm
  const handle = await AoLoader(wasmBinary, {
    format: 'wasm32-unknown-emscripten',
    inputEncoding: 'JSON-1',
    outputEncoding: 'JSON-1',
    memoryLimit: '524288000', // in bytes
    computeLimit: (9e12).toString(),
    extensions: [],
  });

  const address = '7waR8v4STuwPnTck1zFVkQqJh5K9q9Zik4Y5-5dV7nk';
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
    ['Transfer', { Recipient: 'iKryOeZQMONi2965nKz528htMMN_sBcjlhc-VncoRjA' }],
    ['Total-Supply', {}],
  ];

  for (const [method, args] of testCases) {
    const tags = args
      ? Object.entries(args).map(([key, value]) => ({ name: key, value }))
      : [];
    // To spawn a process, pass null as the buffer
    const result = await handle(
      null,
      {
        Id: '3',
        ['Block-Height']: '1',
        // TEST INDICATES NOT TO RUN AUTHORITY CHECKS
        Owner: '7waR8v4STuwPnTck1zFVkQqJh5K9q9Zik4Y5-5dV7nk',
        Target: 'XXXXX',
        From: '7waR8v4STuwPnTck1zFVkQqJh5K9q9Zik4Y5-5dV7nk',
        Tags: [...tags, { name: 'Action', value: method }],
        Data: JSON.stringify({
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
      },
      env,
    );
    delete result.Memory;
    delete result.Assignments;
    delete result.Spawns;
    console.log(method);
    console.dir(result, { depth: null });
  }
}
main();
