import { ANT } from '@ar.io/sdk';
import AoLoader from '@permaweb/ao-loader';
import fetchRetry from 'fetch-retry';
const fetch = fetchRetry(global.fetch);
import fs from 'fs';
import path from 'path';
import workerpool from 'workerpool';

const __dirname = path.dirname(new URL(import.meta.url).pathname);

const AOS_WASM = fs.readFileSync(
  path.join(__dirname, 'aos-cbn0KKrBZH7hdNkNokuXLtGryrWM--PjSTBqIzw9Kkk.wasm'),
);

export async function testProcessEvalCapability(id) {
  // check if eval can be called by pulling the wasm memory from the cu, mounting in ao loader, and running the eval
  let evalCapable = false;
  try {
    const ant = ANT.init({ processId: id });

    const state = await ant.getState();
    const owner = state?.Owner;

    const controller = new AbortController();
    const signal = controller.signal;
    const timeout = setTimeout(() => {
      controller.abort();
    }, 30000);

    const wasmMemory = await fetch(`https://cu.ao-testnet.xyz/${id}`, {
      method: 'GET',
      retries: 10,
      retryDelay: 1000,
      signal,
    })
      .then((res) => res.arrayBuffer())
      .finally(() => {
        clearTimeout(timeout);
      });

    const handle = await AoLoader(AOS_WASM, {
      format: 'wasm64-unknown-emscripten-draft_2024_02_15',
      inputEncoding: 'JSON-1',
      outputEncoding: 'JSON-1',
      memoryLimit: '524288000', // in bytes
      computeLimit: (9e12).toString(),
      extensions: [],
    });

    const evalRes = await handle(
      wasmMemory,
      {
        Owner: owner,
        From: owner,
        Timestamp: Date.now().toString(),
        Id: ''.padEnd(43, '1'),
        Tags: [{ name: 'Action', value: 'Eval' }],
        Data: 'Send({ Target = ao.id })',
        Module: ''.padEnd(43, '1'),
        ['Block-Height']: '1517003',
      },
      {
        Process: {
          Id: ''.padEnd(43, '1'),
          Owner: owner,
          Tags: [
            { name: 'Authority', value: 'XXXXXX' },
            {
              name: 'ANT-Registry-Id',
              value: 'ant-registry-'.padEnd(43, '1'),
            },
          ],
        },
        Module: {
          Id: ''.padEnd(43, '1'),
          Tags: [{ name: 'Authority', value: 'YYYYYY' }],
        },
      },
    );
    console.dir(evalRes?.Messages, { depth: null });
    evalCapable = evalRes?.Messages?.length > 0;
  } catch (error) {
    console.error(`Error fetching wasm memory for domain ${id}:`, error);
  }
  return evalCapable;
}

workerpool.worker({
  testProcessEvalCapability,
});
