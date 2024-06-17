const { describe, it } = require('node:test');
const assert = require('node:assert');
const AoLoader = require('@permaweb/ao-loader');
const {
  AOS_WASM,
  AO_LOADER_HANDLER_ENV,
  AO_LOADER_OPTIONS,
  BUNDLED_AOS_ANT_LUA,
  DEFAULT_ANT_STATE,
  DEFAULT_HANDLE_OPTIONS,
} = require('./constants');

const testCases = [
  ['Eval', { Module: ''.padEnd(43, '1') }, BUNDLED_AOS_ANT_LUA],
  ['Initialize-State', {}, DEFAULT_ANT_STATE],
  ['Info', {}],
  ['Get-Records', {}],
  ['Transfer', { Recipient: 'iKryOeZQMONi2965nKz528htMMN_sBcjlhc-VncoRjA' }],
];

describe('Should load AOS-ANT', async () => {
  // Mostly to ensure the aos binary fixture is present
  it('Should create handle function with the aos wasm binary', async () => {
    const handle = await AoLoader(AOS_WASM, AO_LOADER_OPTIONS);
    assert(handle);
  });

  it('Should load the ANT lua into the AOS wasm process and execute test cases in order to modify the state.', async (t) => {
    let testProgramMemory = null;
    testCases.map(async ([method, args, data]) => {
      t.test(`Should call ${method}`, async () => {
        const tags = Object.entries(args).map(([name, value]) => ({
          name,
          value,
        }));
        const handle = await AoLoader(AOS_WASM, AO_LOADER_OPTIONS);
        const result = await handle(
          testProgramMemory,
          {
            ...DEFAULT_HANDLE_OPTIONS,
            Tags: [...tags, { name: 'Action', value: method }],
            Data: data,
          },
          AO_LOADER_HANDLER_ENV,
        );
        testProgramMemory = result.Memory;
        assert(result);
      });
    });
  });
});
