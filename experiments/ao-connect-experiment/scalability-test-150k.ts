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
import { sleep } from "./utils";
import fs from 'fs'
import path from 'path'

// Function to deploy ANT tokens to the Arweave network
export async function deployANT() {
    // must be owner of the process
    const jwk = JSON.parse(fs.readFileSync(path.resolve(__dirname + '/key.json')).toString())

    const processId = "KOI03f6TWbcRJWatkhvpFtayzc326xP3yAEkL9EiE5E"
    const recordsToSet = 150_000;
    let validated = false
    const messageIds = []
    // Loop to set records with specified tags and signer
    for (let i = recordsToSet; --i; i === 1) {
        // dont overload the network, sleep 3 seconds between data items.
        //sleep(400)
        const tags = [
            { name: "Action", value: "SetRecord" },
            { name: "SubDomain", value: `${i}` },
            { name: "TransactionId", value: ''.padEnd(43, "k") },
            { name: "TtlSeconds", value: "3600" },
        ]
        // Send a message to set a record with the specified process, tags, and signer
        const messageId = await message({
            process: processId,
            tags,
            signer: createDataItemSigner(jwk)
        }).catch((e) => `Unable to set record ${i}` + e.message)
        console.log(messageId)
    }
    // Dry run to get records from the specified process
    const records = await dryrun({
        process: processId,
        tags: [{ name: 'Action', value: "Records" }]
    })

    // Output final results after the scalability test
    console.log("Finished scalability test")
    console.dir({
        recordCount: Object.keys(records).length,
        recordsSize: Buffer.from(JSON.stringify(records)).byteLength,
        expectedRecordCount: recordsToSet
    }, { depth: 10 })
}
deployANT()
