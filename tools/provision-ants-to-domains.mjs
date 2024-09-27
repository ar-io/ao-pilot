import {
  IO,
  ANTRegistry,
  ANT,
  AOProcess,
  ArweaveSigner,
  spawnANT,
  createAoSigner,
  ANT_REGISTRY_ID,
} from '@ar.io/sdk';
import { connect } from '@permaweb/aoconnect';
import { pLimit } from 'plimit-lit';
import fs from 'node:fs';
import path from 'node:path';

const __dirname = path.dirname(new URL(import.meta.url).pathname);

const createDomainsFirstToTest = true;

const validSourceCodeId = 'RuoUVJOCJOvSfvvi_tn0UPirQxlYdC4_odqmORASP8g';

const wallet = JSON.parse(
  fs.readFileSync(path.join(__dirname, 'key.json'), 'utf8'),
);
const signer = new ArweaveSigner(wallet);

const ioProcessId = 'zLbdWU3368h-I-hb9oSrDxbGX-6YbrxAVmfYNDt2vW0';
const aoClient = connect({
  CU_URL: 'https://cu.ar-io.dev',
});
const io = IO.init({
  process: new AOProcess({
    ao: aoClient,
    processId: ioProcessId,
  }),
  signer,
});
const ioAosClient = new AOProcess({
  ao: aoClient,
  processId: ioProcessId,
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
    const domainsToProvision = JSON.parse(
      fs.readFileSync(
        path.join(__dirname, 'domains-to-provision.json'),
        'utf8',
      ),
    );

    const arnsRecords = await io.getArNSRecords({
      limit: 100000,
    });
    const recordsToProvision = arnsRecords.items.filter((record) =>
      domainsToProvision.includes(record.name),
    );

    if (createDomainsFirstToTest) {
      const buyLimit = pLimit(100);
      const missingDomains = domainsToProvision.filter(
        (domain) =>
          !recordsToProvision.find((record) => record.name === domain),
      );
      await Promise.all(
        missingDomains.map((domain) =>
          buyLimit(() =>
            io
              .buyRecord({
                name: domain,
                years: 1,
                type: 'lease',
                processId: 'RohqxhMo2NXJE2QsPz0CVbydj3_r-Uk2adofl226mGM', // random ANT
              })
              .catch(console.error),
          ),
        ),
      );
    }

    const limit = pLimit(50);
    const recordCount = recordsToProvision.length;
    let processedCount = 0;

    const newRecords = {};

    async function provisionDomainWithNewAnt(record) {
      try {
        console.log(
          `Provisioning ${record.name} (${++processedCount}/${recordCount})`,
        );
        const { name: domainName, ...arnsRecord } = record;

        const ant = ANT.init({ processId: record.processId });
        const state = await ant.getState();
        const newAntId = await spawnANT({
          signer: createAoSigner(signer),
          state: {
            owner: state.Owner,
            balances: state.Balances,
            controllers: state.Controllers,
            records: state.Records,
            name: state.Name,
            ticker: state.Ticker,
          },
          ao: aoClient,
          stateContractTxId: record.processId,
          luaCodeTxId: validSourceCodeId,
        });
        antRegistry
          .register({
            processId: newAntId,
          })
          .catch(console.error);
        newRecords[domainName] = { ...arnsRecord, processId: newAntId };
      } catch (error) {
        console.error(error);
      }
    }

    await Promise.all(
      recordsToProvision.map((record) =>
        limit(() => provisionDomainWithNewAnt(record)),
      ),
    );

    function createEvalRecordOverwrite(domain, record) {
      return record.type == 'lease'
        ? `Records["${domain}"] = {
                      processId = "${record.processId}",
                      startTimestamp = ${record.startTimestamp},
                      endTimestamp = ${record.endTimestamp},
                      type = "${record.type}",
                      undernameLimit = ${record.undernameLimit},
                      purchasePrice = ${record.purchasePrice},
              }`
        : `Records["${domain}"] = {
                      processId = "${record.processId}",
                      startTimestamp = ${record.startTimestamp},
                      type = "${record.type}",
                      undernameLimit = ${record.undernameLimit},
                      purchasePrice = ${record.purchasePrice},
              }`;
    }
    // create single eval string
    const evalString = Object.entries(newRecords)
      .map(([domain, record]) => {
        return createEvalRecordOverwrite(domain, record);
      })
      .join('\n');
    await ioAosClient.send({
      tags: [{ name: 'Action', value: 'Eval' }],
      data: evalString,
      signer: createAoSigner(signer),
    });
  } catch (error) {
    console.error(error);
  }
}

main();
