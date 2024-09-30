import {
  IO,
  ANTRegistry,
  ANT,
  AOProcess,
  ArweaveSigner,
  spawnANT,
  createAoSigner,
  ANT_REGISTRY_ID,
  IO_TESTNET_PROCESS_ID,
} from '@ar.io/sdk';
import { connect } from '@permaweb/aoconnect';
import { pLimit } from 'plimit-lit';
import fs from 'node:fs';
import path from 'node:path';
import Arweave from 'arweave';

const arweave = Arweave.init({});

const __dirname = path.dirname(new URL(import.meta.url).pathname);

const createDomainsFirstToTest = true;

const validSourceCodeId = 'RuoUVJOCJOvSfvvi_tn0UPirQxlYdC4_odqmORASP8g';

const wallet = JSON.parse(
  fs.readFileSync(path.join(__dirname, 'key.json'), 'utf8'),
);
const signer = new ArweaveSigner(wallet);

const ioProcessId = 'LPripodPe6cCIJ6rnRcFY4nv-5qXtL_TcfLBiZGs_Gc';
const aoClient = connect({
  CU_URL: 'https://cu.ar-io.dev',
});

const ioAosClient = new AOProcess({
  ao: aoClient,
  processId: ioProcessId,
});
const io = IO.init({
  process: ioAosClient,
  signer,
});

const antRegistry = ANTRegistry.init({
  process: new AOProcess({
    ao: aoClient,
    processId: ANT_REGISTRY_ID,
  }),
  signer,
});

async function main() {
  try {
    // array of domains to provision
    console.log('devnet owner', await arweave.wallets.jwkToAddress(wallet));
    const domainsToProvision = JSON.parse(
      fs.readFileSync(
        path.join(__dirname, 'domains-to-provision.json'),
        'utf8',
      ),
    );
    console.log('fetching testnet records');
    const testnetArNSRecords = await IO.init({
      process: new AOProcess({
        processId: IO_TESTNET_PROCESS_ID,
        ao: aoClient,
      }),
    }).getArNSRecords({
      limit: 100000,
    });

    console.log('fetching test registry records');
    const arnsRecords = await io.getArNSRecords({
      limit: 100000,
    });
    const oldArnsRecordsToProvision = arnsRecords.items.filter((record) =>
      domainsToProvision.includes(record.name),
    );

    if (createDomainsFirstToTest) {
      const buyLimit = pLimit(100);
      const missingDomains = domainsToProvision.filter(
        (domain) =>
          !oldArnsRecordsToProvision.find((record) => record.name === domain),
      );

      await Promise.all(
        missingDomains.map((domain) =>
          buyLimit(() => {
            console.log(`Buying ${domain}`);
            const testnetProcessId = testnetArNSRecords.items.find(
              (record) => record.name === domain,
            ).processId;
            io.buyRecord({
              name: domain,
              years: 1,
              type: 'lease',
              processId: testnetProcessId, // random ANT
            }).catch(console.error);
          }),
        ),
      );
    }

    // create output file if not exists
    if (!fs.existsSync(path.join(__dirname, 'provision-output.json'))) {
      const currentRecords = oldArnsRecordsToProvision.reduce(
        (acc, nameRecord) => {
          const { name: domain, ...record } = nameRecord;
          acc[domain] = { old: record };
          return acc;
        },
        {},
      );
      fs.writeFileSync(
        path.join(__dirname, 'provision-output.json'),
        JSON.stringify(currentRecords, null, 2),
      );
    }
    // filter out already provisioned domains
    const provisionedRecords = JSON.parse(
      fs.readFileSync(path.join(__dirname, 'provision-output.json'), 'utf8'),
    );
    const recordsToProvision = oldArnsRecordsToProvision.reduce(
      (acc, nameRecord) => {
        const { name: domain } = nameRecord;
        if (!provisionedRecords[domain]?.new) {
          acc.push(nameRecord);
        }
        return acc;
      },
      [],
    );

    async function provisionDomainWithNewAnt(record) {
      try {
        console.log(
          `Provisioning ${record.name} (${++processedCount}/${recordCount})`,
        );

        const ant = ANT.init({ processId: record.processId });
        const state = await ant.getState();
        console.log(`Spawning new ANT for ${record.name}`);
        const newAntId = await spawnANT({
          signer: createAoSigner(signer),
          state: {
            owner: state?.Owner,
            balances: state?.Balances,
            controllers: state?.Controllers,
            records: state?.Records,
            name: state?.Name,
            ticker: state?.Ticker,
          },
          ao: aoClient,
          stateContractTxId: record.processId,
          luaCodeTxId: validSourceCodeId,
        });
        console.log(`Registering ANT spawned with processId: ${newAntId}`);
        antRegistry
          .register({
            processId: newAntId,
          })
          .catch(console.error);
        // write result to output file with previous domain and new domain record
        const currentRecords = JSON.parse(
          fs.readFileSync(
            path.join(__dirname, 'provision-output.json'),
            'utf8',
          ),
        );
        const { name, ...domainRecord } = record;
        currentRecords[record.name] = {
          old: record,
          new: {
            ...domainRecord,
            processId: newAntId,
          },
        };
        fs.writeFileSync(
          path.join(__dirname, 'provision-output.json'),
          JSON.stringify(currentRecords, null, 2),
        );
      } catch (error) {
        console.error(error);
      }
    }

    const recordCount = oldArnsRecordsToProvision.length;
    let processedCount =
      oldArnsRecordsToProvision.length - recordsToProvision.length;

    const limit = pLimit(50);
    console.log('Provisioning records');
    await Promise.all(
      recordsToProvision.map((record) =>
        limit(() => provisionDomainWithNewAnt(record)),
      ),
    );

    function createEvalRecordOverwrite(domain, record) {
      return record.type == 'lease'
        ? `NameRegistry.records["${domain}"] = {
                      processId = "${record.processId}",
                      startTimestamp = ${record.startTimestamp},
                      endTimestamp = ${record.endTimestamp},
                      type = "${record.type}",
                      undernameLimit = ${record.undernameLimit},
                      purchasePrice = ${record.purchasePrice},
              }`
        : `NameRegistry.records["${domain}"] = {
                      processId = "${record.processId}",
                      startTimestamp = ${record.startTimestamp},
                      type = "${record.type}",
                      undernameLimit = ${record.undernameLimit},
                      purchasePrice = ${record.purchasePrice},
              }`;
    }
    // create single eval string
    const evalString = Object.entries(provisionedRecords)
      .map(([domain, record]) => {
        return createEvalRecordOverwrite(domain, record.new);
      })
      .join('\n');
    console.log(`Overwriting records with eval string`);
    const overwriteMsg = await ioAosClient.send({
      // tsi_org
      tags: [{ name: 'Action', value: 'Eval' }],
      data: evalString,
      signer: createAoSigner(signer),
    });
    console.log('Eval overwrite message:', overwriteMsg);
    // verify that the new records are in place
    const newlyProvisionedRecords = await io.getArNSRecords({
      limit: 100000,
    });

    const recordsToVerify = newlyProvisionedRecords.items.filter((record) =>
      Object.keys(provisionedRecords).includes(record.name),
    );
    // check that the record processId matches the provisioned record
    const verified = recordsToVerify.every((record) => {
      const provisionedRecord = provisionedRecords[record.name].new;

      return record.processId === provisionedRecord.processId;
    });
    console.log('Verification:', verified ? 'success' : 'failed');
  } catch (error) {
    console.error(error);
  }
}

main();
