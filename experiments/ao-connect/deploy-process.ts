import {
    createDataItemSigner,
    connect,
    spawn,
} from "@permaweb/aoconnect";

import fs from 'fs'
import path from 'path'

const jwk = JSON.parse(fs.readFileSync(path.join(__dirname, 'wallet.json')).toString())

const main = async () => {
    const module = 'GRqfUmY_2QnqgmG9s3C9P3uSy01GRWjaPstNWwVEfJ8'
    const scheduler = 'uW1Qm8BRsfj-tjip0BkVV-CHy6sBPF0Db0H8b15rsD8'
    const processId = await spawn({
        // The Arweave TXID of the ao Module
        module: module,
        // The Arweave wallet address of a Scheduler Unit
        scheduler: scheduler,
        tags: [
            { name: "Memory-Limit", value: "500-mb" },
            { name: "Compute-Limit", value: "9000000000000" },
        ],
        // A signer function containing your wallet
        signer: createDataItemSigner(jwk),
    });
    console.log(processId)
}

main()
