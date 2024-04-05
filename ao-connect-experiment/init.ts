// Import necessary libraries and modules
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

// Initialize Arweave instance with local host settings
const arweave = Arweave.init({
    host: 'localhost',
    port: 4000,
    protocol: 'http',
})

// Initialize main function
async function init() {
    // Load key file from local directory
    const jwk = JSON.parse(fs.readFileSync(path.resolve(__dirname + '/key.json')).toString())

    // Connect to AO permaweb nodes
    const { message, result } = await connect({
        GATEWAY_URL: "http://localhost:4000",
        MU_URL: "http://localhost:4002",
        CU_URL: "http://localhost:4004",
    })

    try {
        // Define process ID for the ANT process
        const processId = "fk6JSrpIu4u1By1ILM0uasBF1hqIfm18VlURTpCGQCo"

        // Log success message and display owner's address and process ID
        console.log(`Succesfully deployed ANT process.`)
        console.dir({
            owner: await arweave.wallets.jwkToAddress(jwk),
            processId
        })

        // Send a message to the AO network to initialize the process
        const messageId = await message({
            process: processId,
            tags: [{ name: "Action", value: "Init" }],
            signer: createDataItemSigner(jwk)
        });

        // Get the result of the process from the AO network
        const resultData = await result({
            process: processId,
            message: messageId
        });

        // Display the result data
        console.dir({ resultData }, { depth: 10 })

    } catch (error) {
        // Handle errors if any occur during the process
        console.error(error)
    }
}

// Call the init function to start the process
init()
