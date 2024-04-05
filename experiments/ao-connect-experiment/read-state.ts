// Here aoconnect will implicitly use the default nodes/units
import {
    result, // Importing the result function from aoconnect
    results, // Importing the results function from aoconnect
    message, // Importing the message function from aoconnect
    spawn, // Importing the spawn function from aoconnect
    monitor, // Importing the monitor function from aoconnect
    unmonitor, // Importing the unmonitor function from aoconnect
    dryrun, // Importing the dryrun function from aoconnect
    createDataItemSigner, // Importing the createDataItemSigner function from aoconnect
} from "@permaweb/aoconnect"; // Importing necessary functions from aoconnect package
import { generateWallet } from "./utils"; // Importing the generateWallet function from utils module

const processId = "H_3EirnLXUrdqQ2ouE4zB72biF_XknOd8DKCnEP0I1I" // Defining the processId constant

// Async function to read ANT state
export async function readANTState() {
    const { jwk } = await generateWallet(); // Generating a wallet and extracting the JWK
    const messageId = await message({ // Sending a message and getting the message ID
        process: processId, // Using the defined process ID
        tags: [{ name: "Action", value: "Info" }], // Defining tags for the message
        signer: createDataItemSigner(jwk) // Using the JWK to create a data item signer
    });
    const res = await result({ // Getting the result of a message using its ID
        message: messageId, // Using the generated message ID
        process: processId // Using the defined process ID
    });
    console.log(`chain message results:`); // Logging a message indicating chain message results
    console.dir(res, { depth: 30 }); // Logging the result with increased depth for object inspection

    const dryRead = await dryrun({ // Performing a dry run to simulate message execution
        process: processId, // Using the defined process ID
        tags: [{ name: "Action", value: "Info" }], // Defining tags for the dry run
    });
    console.log(`dry run results:`); // Logging a message indicating dry run results
    console.dir(dryRead, { depth: 30 }); // Logging the dry run result with increased depth for object inspection
}
