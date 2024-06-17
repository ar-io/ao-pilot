const path = require('node:path');
const fs = require('node:fs');
const test = require('node:test');
const assert = require('node:assert');
const { bundle } = require('./lua-bundler');

test('Should bundle Lua file', () => {
  const bundledLua = bundle(path.join(__dirname, '../src/aos-ant.lua'));
  assert.strictEqual(
    bundledLua,
    fs.readFileSync(
      path.join(__dirname, '../dist/aos-ant-bundled.lua'),
      'utf-8',
    ),
  );
});
