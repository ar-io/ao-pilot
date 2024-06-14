const AoLoader = require('@permaweb/ao-loader');
const fs = require('fs');
const path = require('path');

const address = ''.padEnd(43, 'a');
/* ao READ-ONLY Env Variables */
const env = {
  Process: {
    Id: ''.padEnd(43, '1'),
    Owner: address,
    Tags: [{ name: 'Authority', value: 'XXXXXX' }],
  },
  Module: {
    Id: ''.padEnd(43, '1'),
    Tags: [{ name: 'Authority', value: 'YYYYYY' }],
  },
};

async function main() {
  const wasmBinary = fs.readFileSync(
    path.join(
      __dirname,
      'fixtures/aos-9afQ1PLf2mrshqCTZEzzJTR2gWaC9zNPnYgYEqg1Pt4.wasm',
    ),
  );
  // read the lua code from the dist
  const luaCode = fs.readFileSync(
    path.join(__dirname, '../dist/aos-ant-bundled.lua'),
    'utf-8',
  );
  // for initializing ant state
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
  // Create the handle function that executes the Wasm
  const options = {
    format: 'wasm32-unknown-emscripten',
    inputEncoding: 'JSON-1',
    outputEncoding: 'JSON-1',
    memoryLimit: '524288000', // in bytes
    computeLimit: (9e12).toString(),
    extensions: [],
  };

  const testCases = [
    ['Eval', { Module: ''.padEnd(43, '1') }, luaCode],
    ['Initialize-State', {}, initState],
    ['Info', {}],
    ['Get-Records', {}],
    ['Transfer', { Recipient: 'iKryOeZQMONi2965nKz528htMMN_sBcjlhc-VncoRjA' }],
  ];

  const handle = await AoLoader(wasmBinary, options);
  // memory dump of the evaluated program
  let programState = undefined;
  const defaultHandleOptions = {
    Id: ''.padEnd(43, '1'),
    ['Block-Height']: '1',
    // important to set the address so that that `Authority` check passes. Else the `isTrusted` with throw an error.
    Owner: address,
    Module: 'ANT',
    Target: ''.padEnd(43, '1'),
    From: address,
  };

  for (const [method, args, data] of testCases) {
    const tags = args
      ? Object.entries(args).map(([key, value]) => ({ name: key, value }))
      : [];
    // To spawn a process, pass null as the buffer
    const result = await handle(
      programState,
      {
        ...defaultHandleOptions,
        Tags: [...tags, { name: 'Action', value: method }],
        Data: data,
      },
      env,
    );

    programState = result.Memory;
    console.log(method);
    console.dir(result.Messages[0]?.Data, { depth: null });
  }
}
main();
