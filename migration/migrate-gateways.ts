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
    for (const [address, gateway] of Object.entries(gateways)) {
        const { message, result } = await connect(jwk)
        if (gateway.status === 'leaving') {
            console.log('Skipping leaving gateway', address)
            continue
        }
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
                startTimestamp: currentBlock.timestamp * 1000,
                status: 'joined', // only joined are migrated
                stats: {
                    totalEpochCount: 0,
                    passedEpochCount: 0,
                    observedEpochCount: 0,
                    prescribedEpochCount: 0,
                    failedConsecutiveEpochs: 0,
                    passedConsecutiveEpochs: 0,
                },
                endTimestamp: 0,
                // TODO: we will wipe delegates in testnet migration, this is useful in devnet for testing
                delegates: Object.keys(gateway.delegates).reduce((acc: Record<string, any>, delegateAddress: string) => {
                    const delegate = {
                        startTimestamp: currentBlock.timestamp * 1000,
                        delegatedStake: gateway.delegates[delegateAddress].delegatedStake,
                        vaults: Object.keys(gateway.delegates[delegateAddress].vaults).reduce((acc: Record<string, any>, vaultAddress: string) => {
                            acc[vaultAddress] = {
                                startTimestamp: currentBlock.timestamp * 1000,
                                endTimestamp: currentBlock.timestamp * 1000,
                                balance: gateway.delegates[delegateAddress].vaults[vaultAddress].balance,
                            }
                            return acc
                        }, {})
                    }
                    acc[delegateAddress] = delegate
                    return acc;
                }, {}), // result delegates
                vaults: {}, // reset vaults
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
    // use the ar-io-sdk to get gateways from IO contract
}

main()
