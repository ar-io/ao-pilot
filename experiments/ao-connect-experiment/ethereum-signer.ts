// Import necessary modules for creating data item signer, dry run, message, and result
import { createDataItemSigner, dryrun, message, result } from "@permaweb/aoconnect";
import { EthereumSigner } from "arbundles";
import { DataItem, createData } from "warp-arbundles";

// Define a private key for Ethereum signing
const privateKey = "0x0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";

// Create an Ethereum signer instance using the private key
const signer = new EthereumSigner(privateKey);

// Define the process ID for message processing
const processId = "H_3EirnLXUrdqQ2ouE4zB72biF_XknOd8DKCnEP0I1I"

// Define a function to create a data item using an Ethereum signer
export function createDataItemEthereumSigner (ethSigner: EthereumSigner) {
    /**
     * createDataItem can be passed here for the purposes of unit testing
     * with a stub
     */
    const signer = async ({ data, tags, target, anchor }: any) => {
        // Create a data item with specified data, Ethereum signer, tags, target, and anchor
        const dataItem = createData(data, ethSigner, { tags, target, anchor })
        // Sign the data item using the Ethereum signer
        return dataItem.sign(ethSigner)
          .then(async () => ({
            // Return the ID and raw data of the signed data item
            id: await dataItem.id,
            raw: await dataItem.getRaw()
          }))
      }
  
    return signer
  }

// Define an async function to read ANT state
export async function readANTState() {
    // Send a message with specified process ID, tags, and signer
    const messageId = await message({
        process: processId,
        tags: [{ name: "Action", value: "Info" }],
        signer: createDataItemEthereumSigner(signer) as any
    })
    // Get the result of the message based on the message ID and process ID
    const res = await result({
        message: messageId,
        process: processId
    })
    // Log the chain message results
    console.log(`chain message results:`)
    console.dir(res, { depth: 30 })

    // Perform a dry run with specified process ID and tags
    const dryRead = await dryrun({
        process: processId,
        tags: [{ name: "Action", value: "Info" }],
    })
    // Log the dry run results
    console.log(`dry run results:`)
    console.dir(dryRead, { depth: 30 })
}

// Call the readANTState function to initiate the process
readANTState()
