const path = require('path');
const fs = require('fs');
const Arweave = require('arweave');
const { bundle } = require('./lua-bundler.cjs');

const arweave = Arweave.init({
  host: 'arweave.net',
  port: 443,
  protocol: 'https',
});

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

  const wallet = fs.readFileSync(path.join(__dirname, 'key.json'), 'utf-8');
  const jwk = JSON.parse(wallet);
  const address = await arweave.wallets.jwkToAddress(jwk);

  const tx = await arweave.createTransaction({ data: bundledLua }, jwk);
  tx.addTag('App-Name', 'AOS-ANT-LUA');
  tx.addTag('App-Version', '0.0.1');
  tx.addTag('Content-Type', 'text/x-lua');
  tx.addTag('Author', 'Permanent Data Solutions');
  await arweave.transactions.sign(tx, jwk);
  await arweave.transactions.post(tx);

  console.log('Transaction ID:', tx.id);
}

main();
