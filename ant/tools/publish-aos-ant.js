const Arweave = require('arweave');
const path = require('path');
const fs = require('fs');

const arweave = Arweave.init({
  host: 'arweave.net',
  port: 443,
  protocol: 'https',
});
async function main() {
  const bundledLua = fs.readFileSync(
    path.join(__dirname, '../dist/aos-ant-bundled.lua'),
    'utf-8',
  );
  const wallet = fs.readFileSync(path.join(__dirname, 'key.json'), 'utf-8');
  const jwk = JSON.parse(wallet);
  const address = await arweave.wallets.jwkToAddress(jwk);

  console.log(`Publish AOS ANT Lua with address ${address}`);

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
