import fs from 'fs';
import { AOProcess, IO, ANT, IO_TESTNET_PROCESS_ID } from '@ar.io/sdk';
import { connect } from '@permaweb/aoconnect';
import { pLimit } from 'plimit-lit';
import { toCsvSync } from '@iwsio/json-csv-node';
import arweaveGraphql from 'arweave-graphql';

const cleanSourceCodeId = 'RuoUVJOCJOvSfvvi_tn0UPirQxlYdC4_odqmORASP8g';

function createDomainLink(domain) {
  return `https://${domain}.arweave.net`;
}
function createEntityLink(processId) {
  return `https://www.ao.link/#/entity/${processId}`;
}

async function getProcessEvalMessageIDsNotFromArIO(processId) {
  // Dcd4bnUAxJ
  const messages = await fetch(
    `https://su-router.ao-testnet.xyz/${processId}?limit=100000`,
    {
      method: 'GET',
    },
  ).then((res) => res.json());
  const evalMessages = messages.edges.reduce((acc, edge) => {
    if (
      edge.node.message.tags.some(
        (tag) => tag.name === 'Action' && tag.value === 'Eval',
      ) &&
      !edge.node.message.tags.some((tag) => tag.name === 'Source-Code-TX-ID')
    ) {
      acc.push(edge.node.message.id);
    }
    return acc;
  }, []);

  return { evalMessages };
}

async function getPermawebDeployManifestIds({ owners, ids }) {
  let cursor = null;
  let hasNextPage = true;
  let manifestIds = [];
  while (hasNextPage) {
    const res = await arweaveGraphql('arweave.net/graphql').getTransactions({
      after: cursor,
      owners,
      ids,
      tags: [
        { name: 'App-Name', values: ['Permaweb-Deploy'] },
        {
          name: 'Content-Type',
          values: ['application/x.arweave-manifest+json'],
        },
      ],
    });
    const { edges, pageInfo } = res.transactions;
    manifestIds = manifestIds.concat(
      edges.map((edge) => ({
        owner: edge.node.owner.address,
        manifestId: edge.node.id,
      })),
    );
    cursor = pageInfo.endCursor;
    hasNextPage = pageInfo.hasNextPage;
  }

  return manifestIds;
}

async function main() {
  const aoClient = connect({
    CU_URL: 'https://cu.ar-io.dev',
  });
  const io = IO.init({
    process: new AOProcess({
      ao: aoClient,
      processId: IO_TESTNET_PROCESS_ID,
    }),
  });

  const arnsRecords = await io.getArNSRecords({
    limit: 3000,
  });

  const domainProcessIdMapping = arnsRecords.items.reduce(
    (acc, arnsNameRecord) => {
      acc[arnsNameRecord.name] = arnsNameRecord.processId;
      return acc;
    },
    {},
  );
  console.log('fetching permaweb deploy manifests...');

  const affectedDomains = [];
  let totalDomains = Object.keys(domainProcessIdMapping).length;
  let scannedCount = 1;

  const limit = pLimit(30);
  const manifestAntIdResolvedIdsMap = {};
  async function analyze(domain, antId) {
    try {
      console.log(
        `Processing domain ${scannedCount} / ${totalDomains}:`,
        `"${domain}"`,
      );
      const ant = ANT.init({ processId: antId });
      const state = await ant.getState();
      const sourceCodeId = state?.['Source-Code-TX-ID'];
      const owner = state?.Owner;

      const relatedManifestIds = Object.values(state.Records)
        .map((record) => record?.transactionId)
        .filter(
          (txId) =>
            txId !== undefined &&
            typeof txId === 'string' &&
            txId.length === 43,
        );

      manifestAntIdResolvedIdsMap[antId] = relatedManifestIds;

      const { evalMessages } = await getProcessEvalMessageIDsNotFromArIO(
        antId,
      ).catch((e) => {
        console.error(e);
        return [];
      });

      if (owner && sourceCodeId && sourceCodeId !== cleanSourceCodeId) {
        affectedDomains.push({
          ['ArNS Domain']: domain,
          ['Process ID']: antId,
          ['Owner ID']: owner,
          ['Custom Eval Message Count']: evalMessages.length,
          ['ArNS Domain Link']: createDomainLink(domain),
          ['Process ID Link']: createEntityLink(antId),
          ['Owner Link']: createEntityLink(owner),
          relatedManifestIds,
        });
        console.log(
          `Domain ${domain} is detected to be affected, current affected domains count: ${Object.keys(affectedDomains).length}`,
        );
      }
      scannedCount++;
    } catch (error) {
      console.error('Error processing domain:', domain, error);
      affectedDomains.push({
        ['ArNS Domain']: domain,
        ['Process ID']: antId,
        ['Owner ID']: 'unknown',
        ['Custom Eval Message Count']: 'unknown',
        ['ArNS Domain Link']: createDomainLink(domain),
        ['Process ID Link']: createEntityLink(antId),
        ['Owner Link']: 'unknown',
        ['Error']: 'Not reachable',
        relatedManifestIds: [],
      });
    }
  }
  await Promise.all(
    Object.entries(domainProcessIdMapping).map(([domain, antId]) =>
      limit(() => analyze(domain, antId)),
    ),
  );

  console.log('fetching permaweb deploy manifests...');
  // need to batch into sets of 500
  const flatIds = Object.values(manifestAntIdResolvedIdsMap).flat();
  const batches = [];
  for (let i = 0; i < flatIds.length; i += 500) {
    batches.push(flatIds.slice(i, i + 500));
  }

  async function updateAffectedDomains(batch) {
    const manifestIds = await getPermawebDeployManifestIds({
      ids: batch,
    });
    manifestIds.forEach(({ owner, manifestId }) => {
      affectedDomains.forEach((domain) => {
        if (domain?.relatedManifestIds?.includes(manifestId)) {
          domain['Used Permaweb Deploy'] = true;
        }
      });
    });
  }

  await Promise.all(
    batches.map((batch) => limit(() => updateAffectedDomains(batch))),
  );
  // write json file
  fs.writeFileSync(
    'affected-domains.json',
    JSON.stringify(affectedDomains, null, 2),
  );
  // create csv
  const csv = toCsvSync(affectedDomains, {
    fields: [
      {
        name: 'ArNS Domain',
        label: 'ArNS Domain',
      },
      {
        name: 'Process ID',
        label: 'Process ID',
      },
      {
        name: 'Owner ID',
        label: 'Owner ID',
      },
      {
        name: 'Custom Eval Message Count',
        label: 'Custom Eval Message Count',
      },
      {
        name: 'Used Permaweb Deploy',
        label: 'Used Permaweb Deploy',
      },
      {
        name: 'ArNS Domain Link',
        label: 'ArNS Domain Link',
      },
      {
        name: 'Process ID Link',
        label: 'Process ID Link',
      },
      {
        name: 'Owner Link',
        label: 'Owner Link',
      },
    ],
    fieldSeparator: ',',
    ignoreHeader: false,
  });

  fs.writeFileSync('affected-domains.csv', csv);
}

main();
