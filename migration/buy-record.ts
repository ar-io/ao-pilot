import {
    createDataItemSigner,
    connect,
} from "@permaweb/aoconnect";

import fs from 'fs'
import path from 'path'

const processId = 'GaQrvEMKBpkjofgnBi_B3IgIDmY_XYelVLB6GcRGrHc'
const dirname = new URL(import.meta.url).pathname
const jwk = JSON.parse(fs.readFileSync(path.join(dirname, '../wallet.json')).toString())

const main = async () => {
    const { message, result } = await connect(jwk)
    const messageTxId = await message({
        process: processId,
        tags: [
            { name: 'ProcessId', value: processId},
            { name: 'Action', value: 'BuyRecord' },
            { name: 'PurchaseType', value: 'lease'},
        ],
        signer: createDataItemSigner(jwk),
    });
    console.log('Sent data to process', messageTxId)
    const res = await result({
        message: messageTxId,
        process: processId
    })
    console.log('Result:', res)
}

main()
