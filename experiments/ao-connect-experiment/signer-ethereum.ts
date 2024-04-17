import { connect } from "@permaweb/aoconnect";
import { createEthereumDataItemSigner } from "./utils";

const privateKey = "0x0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";

const processId = "aS-8j-h_XFLsO9AQaJoxQ-ariR-LKnpb76cjJyLc944"

export async function readANTState() {

const { message, result, dryrun } = await connect({
    GRAPHQL_URL: "https://arweave.net/graphql",
    MU_URL: "http://vilenarios.com:3005",
    CU_URL: "http://vilenarios.com:6363",
    GATEWAY_URL: "https://arweave.net",
} as any)

console.log("sending message")
    const messageId = await message({
        process: processId,
        tags: [{ name: "Action", value: "Transfer" }, {name: "Recipient", value: "PdE0UmhXZm1MZKmQphmOttfFxR9tfQGp0UNdAVwVg2Q"}, {name: "Quantity", value: "1000"}],
        signer: createEthereumDataItemSigner(privateKey) as any

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