import Arweave from "arweave";
import path from "path";
import fs from "fs";

const __dirname = path.dirname(new URL(import.meta.url).pathname);
const restart = process.argv.includes("--restart");
const inputFilePath = process.argv.includes("--file")
  ? process.argv[process.argv.indexOf("--file") + 1]
  : null;
const wallet = JSON.parse(
  fs.readFileSync(path.join(__dirname, "key.json"), "utf8"),
);
const testnet = process.argv.includes("--testnet");
const arweave = Arweave.init({
  host: "arweave.net",
  port: 443,
  protocol: "https",
});
const index = process.argv.includes("--index")
  ? process.argv[process.argv.indexOf("--index") + 1]
  : null;

async function main() {
  const csv = fs.readFileSync(path.join(__dirname, inputFilePath), "utf8");

  const postfix = index ? `-${index}` : "";

  const outputFilePath = path.join(
    __dirname,
    `deduplicated-processids-${testnet ? "testnet" : "devnet"}${postfix}.csv`,
  );

  // print out address of wallet being used
  const address = await arweave.wallets.jwkToAddress(wallet);
  console.log(`Using wallet ${address} to evaluate ants`);

  const alreadyCreatedProcessIds = csv
    .split("\n")
    .slice(1) // skip header
    .map((line) => line.split(","))
    .filter(
      ([domain, oldProcessId, newProcessId]) =>
        domain && oldProcessId && newProcessId && oldProcessId !== newProcessId,
    );

  // create output csv if not exists including eval result
  if (!fs.existsSync(outputFilePath) || restart) {
    fs.writeFileSync(outputFilePath, "domain,oldProcessId,newProcessId\n", {
      flag: "w",
    });
  }

  const processMap = new Map();

  // process map - don't re-evaluate ants that have already been evaluated

  for (const [domain, oldProcessId, newProcessId] of alreadyCreatedProcessIds) {
    console.log(`Evaluating ant ${newProcessId}`);

    // don't eval if we already have on the process map
    if (processMap.has(oldProcessId)) {
      console.log(`Skipping ${oldProcessId} as it has already been created`);
      fs.writeFileSync(
        outputFilePath,
        `${domain},${oldProcessId},${processMap.get(oldProcessId)}\n`,
        {
          flag: "a",
        },
      );
      continue;
    }

    fs.writeFileSync(
      outputFilePath,
      `${domain},${oldProcessId},${newProcessId}\n`,
      {
        flag: "a",
      },
    );

    processMap.set(oldProcessId, newProcessId);
  }
}

main();
