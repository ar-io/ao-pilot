import {
    createDataItemSigner,
    connect,
} from "@permaweb/aoconnect";
import { ArIO } from "@ar.io/sdk";
import Arweave from 'arweave'

import fs from 'fs'
import path from 'path'

const processId = 'GaQrvEMKBpkjofgnBi_B3IgIDmY_XYelVLB6GcRGrHc'
const dirname = new URL(import.meta.url).pathname
const jwk = JSON.parse(fs.readFileSync(path.join(dirname, '../wallet.json')).toString())
// const scheduler = '_GQ33BkPtZrqxA84vM8Zk-N2aO0toNNu_C-l-rawrBA' // tom's scheduler
const main = async () => {
    // fetch gateways from contract
    const devnetContract = ArIO.init({
        contractTxId: '_NctcA2sRy1-J4OmIQZbYFPM17piNcbdBPH2ncX2RL8'
    })
    const records = await devnetContract.getArNSRecords();
    const arweave = Arweave.init({
        host: 'arweave.net',
        port: 443,
        protocol: 'https',
    });
    // const uniqueSetOfContractTxIds = new Set(Object.values(records).map(record => record.contractTxId))
    // const mapOfContractTxIdToAntTxId: Record<string, string> = {}
    // spawn ANT using ANT module (or inject source code) for each contract
    // for (const contractTxId of uniqueSetOfContractTxIds) {
    //     const processId = await spawn({
    //         // The Arweave TXID of the ao Module
    //         module: '', // TODO: replace with the actual module tx id
    //         scheduler: scheduler,
    //         tags: [
    //             { name: "Memory-Limit", value: "500-mb" },
    //             { name: "Compute-Limit", value: "9000000000000" },
    //             { name: "ContractTxId", value: contractTxId}
    //         ],
    //         // A signer function containing your wallet
    //         signer: createDataItemSigner(jwk),
    //     });
    //     mapOfContractTxIdToAntTxId[contractTxId] = processId
    // }
    const currentBlock = await arweave.blocks.getCurrent();
    for (const [name, record] of Object.entries(records)) {
        const { message, result } = await connect(jwk)
        const messageTxId = await message({
            process: processId,
            tags: [
                { name: 'ProcessId', value: processId},
                { name: 'Action', value: 'AddRecord' },
                { name: 'Name', value: name},
            ],
            data: JSON.stringify({
                type: record.type,
                // convert it to milliseconds and add 2 years
                endTimestamp: record.type === 'lease' ? (currentBlock.timestamp * 1000) + (1000 * 60 * 60 * 24 * 365 * 2) : 0, // 2 years
                contractTxId: record.contractTxId,
                undernameLimit: record.undernames,
                purchasePrice: record.purchasePrice,
            }),
            signer: createDataItemSigner(jwk),
        });
        console.log('Sent data to process', messageTxId)
        const res = await result({
            message: messageTxId,
            process: processId
        })
        console.log('Result:', res)
    }

    // migrate reserved names
    const reservedNames = await devnetContract.getArNSReservedNames({});
    for (const [name, reservedName] of Object.entries(reservedNames)) {
        const { message, result } = await connect(jwk)
        const messageTxId = await message({
            process: processId,
            tags: [
                { name: 'ProcessId', value: processId},
                { name: 'Action', value: 'AddReservedName' },
                { name: 'Name', value: name},
            ],
            data: JSON.stringify({
                ...reservedName.endTimestamp ? { endTimestamp: (currentBlock.timestamp * 1000) + (1000 * 60 * 60 * 24 * 365 * 1)  }: {}, // 1 year
                ...reservedName.target ? { target: reservedName.target }: {},
            }),
            signer: createDataItemSigner(jwk),
        });
        console.log('Sent data to process', messageTxId)
        const res = await result({
            message: messageTxId,
            process: processId
        })
        console.log('Result:', res)
    }
}

main()
