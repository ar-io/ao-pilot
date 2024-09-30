import {
  ANT,
  ANT_LUA_ID,
  ANT_REGISTRY_ID,
  AOProcess,
  AOS_MODULE_ID,
  ArweaveSigner,
  DEFAULT_SCHEDULER_ID,
  createAoSigner,
  spawnANT,
} from '@ar.io/sdk';
import { connect } from '@permaweb/aoconnect';
import path from 'path';
import fs from 'fs';

const __dirname = path.dirname(new URL(import.meta.url).pathname);
const outputFilePath = path.join(__dirname, 'new-arns-processid-mapping.csv');

const wallet = JSON.parse(
  fs.readFileSync(path.join(__dirname, 'key.json'), 'utf8'),
);
const signer = new ArweaveSigner(wallet);

const aoClient = connect({
  CU_URL: 'https://cu.ar-io.dev',
});

async function main() {
  /**
  Script 1:
    Inputs: None
    Outputs: CSV or JSON file with:
    Domain Name
    Current ANT Process ID
Script 2:
    Inputs: CSV or JSON from Script 1
    Outputs: CSV or JSON with:
    Domain name
    ANT ID of CLONED process

    Primary Business Logic:
      Pull ANT Info
      Spawn new ANT
      Call spawned ANT Initialize-State handler with previous Info
 */

  // get the csv from the previous script
  const csv = fs.readFileSync(
    path.join(__dirname, 'arns-processid-mapping.csv'),
    'utf8',
  );
  const [oldRecordsHeader, ...oldRecords] = csv
    .split('\n')
    .map((line) => line.split(','))
    .filter(([domain, processId]) => domain !== '');

  // create output csv if not exists
  if (!fs.existsSync(outputFilePath)) {
    fs.writeFileSync(outputFilePath, 'domain,processId\n', { flag: 'w' });
  }
  const [provisionedHeader, ...provisionedRecords] = fs
    .readFileSync(outputFilePath, 'utf8')
    .split('\n')
    .map((line) => line.split(','))
    .filter(([domain, processId]) => domain !== '');

  const provisionedDomains = provisionedRecords.map(
    ([domain, processId]) => domain,
  );
  // filter out domains that already have an ANT provisioned
  const recordsToProvision = oldRecords.filter(([domain, processId]) => {
    return !provisionedDomains.includes(domain);
  });

const total = oldRecords.length;
let provisioned = Math.max(1, oldRecords.length - recordsToProvision.length);
let spawnTimePerAnt = 0;
let totalSpawnTime = 0;
for (const record of recordsToProvision) {
    const startTime = Date.now();
    try {
        console.log(`Provisioning ${record[0]} | ${provisioned} / ${total}...`);
        const [domain, processId] = record;

        async function spawnAntWithRetry() {
            const controller = new AbortController();
            const { signal } = controller;
            const timeout = setTimeout(() => {
                controller.abort();
            }, 30_000);

            try {
                const newAntId = await Promise.race([
                    aoClient.spawn({
                        signer: createAoSigner(signer),
                        module: AOS_MODULE_ID,
                        scheduler: DEFAULT_SCHEDULER_ID,
                        tags: [
                            {
                                name: 'ANT-Registry-Id',
                                value: ANT_REGISTRY_ID,
                            },
                        ],
                    }),
                    new Promise((_, reject) => {
                        signal.addEventListener('abort', () => {
                            reject(new Error('Spawn request aborted, took longer than 30 seconds'));
                        });
                    }),
                ]);

                clearTimeout(timeout);
                return newAntId;
            } catch (error) {
                clearTimeout(timeout);
                console.error('Error:', error);
                // Retry after abort
                return spawnAntWithRetry();
            }
        }

        const newAntId = await spawnAntWithRetry();
        fs.writeFileSync(outputFilePath, `${domain},${newAntId}\n`, {
            flag: 'a',
        });
        provisioned++;

        const endTime = Date.now();
        const spawnTime = endTime - startTime;
        totalSpawnTime += spawnTime;
        spawnTimePerAnt = totalSpawnTime / provisioned;
        console.info(
            `Estimated time remaining: ${(spawnTimePerAnt * (total - provisioned)) / 1000 / 60} minutes`,
        );
    } catch (error) {
        console.error('Error:', error);
    }
}
  // verify all the domains have been provisioned
  const [_, ...newProvisionedRecords] = fs
    .readFileSync(outputFilePath, 'utf8')
    .split('\n')
    .map((line) => line.split(','))
    .filter(([domain, processId]) => domain !== '');
  const newProvisionedDomains = newProvisionedRecords.map(
    ([domain, processId]) => domain,
  );
  const missingDomains = oldRecords.filter(
    ([domain, processId]) => !newProvisionedDomains.includes(domain),
  );
  if (missingDomains.length > 0) {
    console.error('Some domains were not provisioned:', missingDomains);
  }
}

main();