import {
  ANT,
  ANT_LUA_ID,
  ANT_REGISTRY_ID,
  AOProcess,
  AOS_MODULE_ID,
  ArweaveSigner,
  DEFAULT_SCHEDULER_ID,
  createAoSigner,
  evolveANT,
} from '@ar.io/sdk';
import { connect } from '@permaweb/aoconnect';
import path from 'path';
import fs from 'fs';

const __dirname = path.dirname(new URL(import.meta.url).pathname);
const inputFilePath = path.join(__dirname, 'new-arns-processid-mapping.csv');
const outputFilePath = path.join(__dirname, 'initialized-arns-processid-mapping.csv');

const wallet = JSON.parse(
  fs.readFileSync(path.join(__dirname, 'key.json'), 'utf8'),
);
const signer = new ArweaveSigner(wallet);

const aoClient = connect({
  CU_URL: 'https://cu.ar-io.dev',
});

function createDomainIdMappingFromCsv(csv) {
  const [header, ...records] = csv
    .split('\n')
    .map((line) => line.split(','))
    .filter(([domain, processId]) => domain !== '');

    return records
}

async function main() {
    const csv = fs.readFileSync(inputFilePath, 'utf8');
    const provisionedRecords = createDomainIdMappingFromCsv(csv);
    
    for (const [domain, processId] of provisionedRecords) {
  
      await evolveANT({
          processId,
          luaCodeTxId: 'RuoUVJOCJOvSfvvi_tn0UPirQxlYdC4_odqmORASP8g',
          signer: createAoSigner(signer),
          ao: aoClient,
        })

        const antAosClient = new AOProcess({
          processId,
          ao: aoClient,
        })

         await antAosClient.send({
            tags: [
              { name: 'Action', value: 'Initialize-State' },
              ...(stateContractTxId !== undefined
                ? [{ name: 'State-Contract-TX-ID', value: stateContractTxId }]
                : []),
            ],
            data: JSON.stringify(state),
            signer,
          });
  }
}


main();