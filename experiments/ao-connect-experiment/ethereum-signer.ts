import { dryrun, message, result, createDataItemSigner } from "@permaweb/aoconnect";
import { arweave, createArweaveDataItemSigner, createEthereumDataItemSigner, generateWallet } from "./utils";

const privateKey = "0x0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";

const processId = "H_3EirnLXUrdqQ2ouE4zB72biF_XknOd8DKCnEP0I1I"

export async function readANTState() {
const jwk = await arweave.wallets.generate()
    const messageId = await message({
        process: processId,
        tags: [{ name: "Action", value: "Info" }],
        //signer: createDataItemSigner(jwk) as any
        // signer: createArweaveDataItemSigner(jwk) as any
       signer: createEthereumDataItemSigner(privateKey) as any
    })
    const res = await result({
        message: messageId,
        process: processId
    })
    // console.log(`chain message results:`)
    // console.dir(res, { depth: 30 })

    const dryRead = await dryrun({
        process: processId,
        tags: [{ name: "Action", value: "Info" }],

    })
    // console.log(`dry run results:`)
    // console.dir(dryRead, { depth: 30 })
}

readANTState()