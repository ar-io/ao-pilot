const { connect, createDataItemSigner } = require("@permaweb/aoconnect");
const fs = require("fs");

const jwk = JSON.parse(
  fs.readFileSync("F:\\Source\\ao-pilot\\wallet.json", "utf-8")
);
const data = fs.readFileSync(
  "F:\\Source\\ao-pilot\\arns-records-1392718.json",
  "utf-8"
);

async function main() {
  const { message } = await connect();
  const result = await message({
    process: "03vGIXBKHZG967IO_VmdHYDzNLi8G93LAFYA1W0T9yo",
    signer: createDataItemSigner(jwk),
    tags: [{ name: "Action", value: "Load-Records" }],
    data: data,
  });
  console.log(result);
}

main();
