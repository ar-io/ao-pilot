const path = require('path');
const fs = require('fs');
const { bundle } = require('./lua-bundler.cjs');

async function main() {
  console.log('Bundling Lua...');

  const bundledLua = bundle(path.join(__dirname, '../src/aos-ant.lua'));

  if (!fs.existsSync(path.join(__dirname, '../dist'))) {
    fs.mkdirSync(path.join(__dirname, '../dist'));
  }

  fs.writeFileSync(
    path.join(__dirname, '../dist/aos-ant-bundled.lua'),
    bundledLua,
  );
  console.log(
    'Bundled Lua written to:',
    path.join(__dirname, '../dist/aos-ant-bundled.lua'),
  );
}

main();
