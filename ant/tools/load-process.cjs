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
  Module: {
    Id: "1",
    Tags: [
      { name: "Authority", value: "YYYYYY" },
    ],
  },
};

async function main() {

const wasmBinary = fs.readFileSync(path.join(__dirname, '../src/process.wasm') );
// Create the handle function that executes the Wasm
const handle = await AoLoader(wasmBinary, {
  format: "wasm32-unknown-emscripten",
  inputEncoding: "JSON-1",
  outputEncoding: "JSON-1", 
  memoryLimit: "524288000", // in bytes
  computeLimit: 9e12.toString(),
  extensions: []
});

// To spawn a process, pass null as the buffer
const result = await handle(null, {
  Id: "3",
  ["Block-Height"]: "1",
  // TEST INDICATES NOT TO RUN AUTHORITY CHECKS
  Owner: "test",
  Target: "XXXXX",
  From: "YYYYYY",
  Tags: [
    { name: "Action", value: "Set-Controller" },
    { name: "Controller", value: "".padEnd(43, '1') },
  ],
}, env);

console.dir(result, { depth: null});
} main();