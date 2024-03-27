const { connect, createDataItemSigner } = require("@permaweb/aoconnect");
const fs = require("fs");

const jwk = JSON.parse(
  fs.readFileSync("F:\\Source\\ao-pilot\\wallet.json", "utf-8")
);
const data = fs.readFileSync(
  "F:\\Source\\ao-pilot\\arns-records-1391469.json",
  "utf-8"
);

async function main() {
  const { message } = await connect();
  const result = await message({
    process: "TyduW6spZTr3gkdIsdktduJhgtilaR_ex5JukK8gI9o",
    signer: createDataItemSigner(jwk),
    tags: [{ name: "Action", value: "Load-Records" }],
    data: data,
  });
  console.log(result);
}

main();
