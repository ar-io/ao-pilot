const { connect, createDataItemSigner } = require("@permaweb/aoconnect");
const fs = require("fs");

const jwk = JSON.parse(
  fs.readFileSync("F:\\Source\\ao-pilot\\wallet.json", "utf-8")
);
const data = fs.readFileSync(
  "F:\\Source\\ao-pilot\\balances-test.json",
  "utf-8"
);

async function main() {
  const { message } = await connect();
  const result = await message({
    process: "B9auSXSSG7urEZ3ceJIekOEJ4GGnN6yqmT4dVMnvHU8",
    signer: createDataItemSigner(jwk),
    tags: [{ name: "Action", value: "Load-Balances" }],
    data: data,
  });
  console.log(result);
}

main();
