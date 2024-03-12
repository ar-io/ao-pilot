// Here aoconnect will implicitly use the default nodes/units
import {
    result,
    results,
    message,
    spawn,
    monitor,
    unmonitor,
    dryrun,
    createDataItemSigner,
} from "@permaweb/aoconnect";
import { generateWallet } from "./utils";

const processId = "H_3EirnLXUrdqQ2ouE4zB72biF_XknOd8DKCnEP0I1I"

export async function readANTState() {
    const { jwk } = await generateWallet()
    const messageId = await message({
        process: processId,
        tags: [{ name: "Action", value: "Info" }],
        signer: createDataItemSigner(jwk)
    })
    const res = await result({
        message: messageId,
        process: processId
    })
    console.log(`chain message results:`)
    console.dir(res, { depth: 30 })

    const dryRead = await dryrun({
        process: processId,
        tags: [{ name: "Action", value: "Info" }],

    })
    console.log(`dry run results:`)
    console.dir(dryRead, { depth: 30 })
}

readANTState()