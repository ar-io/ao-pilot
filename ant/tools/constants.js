const fs = require('fs');
const path = require('path');
const STUB_ADDRESS = ''.padEnd(43, '1');
/* ao READ-ONLY Env Variables */
const AO_LOADER_HANDLER_ENV = {
  Process: {
    Id: ''.padEnd(43, '1'),
    Owner: STUB_ADDRESS,
    Tags: [{ name: 'Authority', value: 'XXXXXX' }],
  },
  Module: {
    Id: ''.padEnd(43, '1'),
    Tags: [{ name: 'Authority', value: 'YYYYYY' }],
  },
};

const AO_LOADER_OPTIONS = {
  format: 'wasm32-unknown-emscripten',
  inputEncoding: 'JSON-1',
  outputEncoding: 'JSON-1',
  memoryLimit: '524288000', // in bytes
  computeLimit: (9e12).toString(),
  extensions: [],
};

const AOS_WASM = fs.readFileSync(
  path.join(
    __dirname,
    'fixtures/aos-9afQ1PLf2mrshqCTZEzzJTR2gWaC9zNPnYgYEqg1Pt4.wasm',
  ),
);

const BUNDLED_AOS_ANT_LUA = fs.readFileSync(
  path.join(__dirname, '../dist/aos-ant-bundled.lua'),
  'utf-8',
);

const DEFAULT_ANT_STATE = JSON.stringify({
  balances: { [STUB_ADDRESS]: 1 },
  controllers: [STUB_ADDRESS],
  name: 'ANT-ARDRIVE',
  owner: STUB_ADDRESS,
  records: {
    '@': {
      transactionId: 'UyC5P5qKPZaltMmmZAWdakhlDXsBF6qmyrbWYFchRTk',
      ttlSeconds: 3600,
    },
  },
  ticker: 'ANT',
});

const DEFAULT_HANDLE_OPTIONS = {
  Id: ''.padEnd(43, '1'),
  ['Block-Height']: '1',
  // important to set the address so that that `Authority` check passes. Else the `isTrusted` with throw an error.
  Owner: STUB_ADDRESS,
  Module: 'ANT',
  Target: ''.padEnd(43, '1'),
  From: STUB_ADDRESS,
};

module.exports = {
  BUNDLED_AOS_ANT_LUA,
  DEFAULT_ANT_STATE,
  AOS_WASM,
  AO_LOADER_OPTIONS,
  AO_LOADER_HANDLER_ENV,
  STUB_ADDRESS,
  DEFAULT_HANDLE_OPTIONS,
};
