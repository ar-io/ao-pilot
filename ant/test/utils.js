const AoLoader = require('@permaweb/ao-loader');
const {
  AOS_WASM,
  AO_LOADER_HANDLER_ENV,
  AO_LOADER_OPTIONS,
  BUNDLED_AOS_ANT_LUA,
  DEFAULT_ANT_STATE,
  DEFAULT_HANDLE_OPTIONS,
} = require('../tools/constants');

/**
 * Loads the AOS-ANT wasm binary and returns the handle function with program memory
 * @returns {Promise<{handle: Function, memory: WebAssembly.Memory}>}
 */
async function createAntAosLoader() {
  const handle = await AoLoader(AOS_WASM, AO_LOADER_OPTIONS);
  const evalRes = await handle(
    null,
    {
      ...DEFAULT_HANDLE_OPTIONS,
      Tags: [{ name: 'Action', value: 'Eval' }],
      Data: BUNDLED_AOS_ANT_LUA,
    },
    AO_LOADER_HANDLER_ENV,
  );
  return {
    handle,
    memory: evalRes.Memory,
  };
}
