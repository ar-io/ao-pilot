import { connect } from "@permaweb/aoconnect";
import { createSolanaDataItemSigner } from "./utils";

import * as SolanaWeb3 from '@solana/web3.js';
import b58 from 'bs58'


const processId = "aS-8j-h_XFLsO9AQaJoxQ-ariR-LKnpb76cjJyLc944"

export async function readANTState() {
    const privateKey = b58.encode(SolanaWeb3.Keypair.generate().secretKey)

const { message, result, dryrun, spawn } = await connect({
    GRAPHQL_URL: "https://arweave.net/graphql",
    MU_URL: "http://vilenarios.com:3005",
    CU_URL: "http://vilenarios.com:6363",
    GATEWAY_URL: "https://arweave.net",
} as any)

console.log("sending message")
    const messageId = await message({
        process: processId,
        tags: [{ name: "Action", value: "Transfer" }, {name: "Recipient", value: "PdE0UmhXZm1MZKmQphmOttfFxR9tfQGp0UNdAVwVg2Q"}, {name: "Quantity", value: "1000"}],
       signer: createSolanaDataItemSigner(privateKey) as any

    })
    console.log(`messageId: ${messageId}`)
    console.log("reading results")
    const res = await result({
        message: messageId,
        process: processId
    })
    console.log(`chain message results:`)
    console.dir(res, { depth: 30 })

    console.log("reading dry run results")
    const dryRead = await dryrun({
        process: processId,
        tags: [{ name: "Action", value: "Transfer" }, {name: "Recipient", value: "PdE0UmhXZm1MZKmQphmOttfFxR9tfQGp0UNdAVwVg2Q"}, {name: "Quantity", value: "1000"}],


    })
    console.log(`dry run results:`)
    console.dir(dryRead, { depth: 30 })
}

readANTState()