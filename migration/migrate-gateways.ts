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

const main = async () => {
    // fetch gateways from contract
    const devnetContract = ArIO.init({
        contractTxId: '_NctcA2sRy1-J4OmIQZbYFPM17piNcbdBPH2ncX2RL8'
    })
    const gateways = await devnetContract.getGateways();
    const arweave = Arweave.init({
        host: 'arweave.net',
        port: 443,
        protocol: 'https',
    });
    const currentBlock = await arweave.blocks.getCurrent();
    const millisecondsPerBlock = 1000 * 2 * 60; // two minutes

    for (const [address, gateway] of Object.entries(gateways)) {
        const { message, result } = await connect(jwk)
        const startTimestamp = await arweave.blocks.getByHeight(gateway.start).then(block => block.timestamp)
        const endHeightDiff = gateway.end ? gateway.end - gateway.start : 0
        const endTimestamp = gateway.end ? currentBlock.timestamp + (endHeightDiff * millisecondsPerBlock) : 0
        const messageTxId = await message({
            process: processId,
            tags: [
                { name: 'ProcessId', value: processId},
                { name: 'Action', value: 'AddGateway' },
                { name: 'Address', value: address},
            ],
            data: JSON.stringify({
                observerAddress: gateway.observerWallet,
                operatorStake: gateway.operatorStake,
                settings: gateway.settings,
                // TODO: fetch the block height of the gateway block height
                startTimestamp: startTimestamp,
                status: gateway.status,
                stats: {
                    ...gateway.stats,
                    // give them the max amount of passed
                    "passedConsecutiveEpochs": gateway.stats.passedEpochCount,
                },
                // TODO: fetch the block height of the gateway block height
                endTimestamp: endTimestamp,
                delegates: gateway.delegates,
                vaults: gateway.vaults,

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
