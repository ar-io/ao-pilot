const { createAntAosLoader } = require('./utils');
const { describe, it } = require('node:test');
const assert = require('node:assert');

describe('Should load AOS-ANT', async () => {
  const { handle: originalHandle, memory: startMemory } =
    await createAntAosLoader();

  async function handle(options = {}, mem = startMemory) {
    return originalHandle(
      mem,
      {
        ...DEFAULT_HANDLE_OPTIONS,
        ...options,
      },
      AO_LOADER_HANDLER_ENV,
    );
  }

  it('Should fetch the balances of the ANT', async () => {
    const result = await handle({
      Tags: [{ name: 'Action', value: 'Balances' }],
    });
    const balances = JSON.parse(result.Messages[0].Data);
    assert(balances);
    const balanceEntries = Object.entries(balances);
    assert(balanceEntries.length === 1);
    assert(balanceEntries[0][0] === STUB_ADDRESS);
    assert(balanceEntries[0][1] === 1);
  });
});
