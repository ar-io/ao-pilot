import {
    createDataItemSigner,
    connect,
} from "@permaweb/aoconnect";

import fs from 'fs'
import path from 'path'

const processId = 'Wq0LrvyY9tqRtQcxQcKAYfa0F1Yp9Uomkio4PrUlugE'
const jwk = JSON.parse(fs.readFileSync(path.join(__dirname, 'wallet.json')).toString())

const main = async () => {
    const { message, result } = await connect(jwk)
    const messageTxId = await message({
        process: processId,
        tags: [
            { name: 'ProcessId', value: processId},
            { name: 'Action', value: 'BuyRecord' },
            { name: 'Name', value: 'dylan' },
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
