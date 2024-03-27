import {
    createDataItemSigner,
    connect,
    //  spawn
} from "@permaweb/aoconnect";

//import { Tag } from "arweave/node/lib/transaction";
import Arweave from "arweave";
//import { TurboFactory } from "@ardrive/turbo-sdk";

import fs from 'fs'
import path from 'path'

const arweave = Arweave.init({
    host: 'localhost',
    port: 4000,
    protocol: 'http',
})

async function init() {

    const jwk = JSON.parse(fs.readFileSync(path.resolve(__dirname + '/key.json')).toString())

    const { message, result } = await connect({
        GATEWAY_URL: "http://localhost:4000",
        MU_URL: "http://localhost:4002",
        CU_URL: "http://localhost:4004",
    })

    try {

        const processId = "fk6JSrpIu4u1By1ILM0uasBF1hqIfm18VlURTpCGQCo"

        console.log(`Succesfully deployed ANT process.`)
        console.dir({
            owner: await arweave.wallets.jwkToAddress(jwk),
            processId
        })

        const messageId = await message({
            process: processId,
            tags: [{ name: "Action", value: "Init" }],
            signer: createDataItemSigner(jwk)
        });

        const resultData = await result({
            process: processId,
            message: messageId
        });

        console.dir({ resultData }, { depth: 10 })

    } catch (error) {
        console.error(error)
    }


}

init()