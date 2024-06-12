const AoLoader = require( "@permaweb/ao-loader");
const fs = require('fs');
const path = require('path');

/* ao READ-ONLY Env Variables */
const env = {
  Process: {
    Id: "2",
    Tags: [
      { name: "Authority", value: "XXXXXX" },
    ],
  },
};

async function main() {

const wasmBinary = fs.readFileSync(path.join(__dirname, 'process.wasm') );
// Create the handle function that executes the Wasm
const handle = await AoLoader(wasmBinary, {
  format: "wasm64-unknown-emscripten-draft_2024_02_15",
  inputEncoding: "JSON-1",
  outputEncoding: "JSON-1", 
  memoryLimit: "524288000", // in bytes
  computeLimit: 9e12.toString(),
  extensions: []
});

// To spawn a process, pass null as the buffer
const result = await handle(null, {
  Owner: "OWNER_ADDRESS",
  Target: "XXXXX",
  From: "YYYYYY",
  Tags: [
    { name: "Action", value: "Ping" },
  ],
  Data: "ping",
}, env);

console.dir(result, { depth: null});
} main();