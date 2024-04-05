// Import required modules
const { connect, createDataItemSigner } = require("@permaweb/aoconnect");
const fs = require("fs");

// Load JSON Web Key (jwk) from file
const jwk = JSON.parse(
  fs.readFileSync("F:\\Source\\ao-pilot\\wallet.json", "utf-8")
);

// Load data from JSON file
const data = fs.readFileSync(
  "F:\\Source\\ao-pilot\\arns-records-1391469.json",
  "utf-8"
);

// Define the main asynchronous function
async function main() {
  // Connect to the Arweave network
  const { message } = await connect();
  // Send a message to the network for processing data
  const result = await message({
    process: "TyduW6spZTr3gkdIsdktduJhgtilaR_ex5JukK8gI9o", // Process ID for data processing
    signer: createDataItemSigner(jwk), // Sign data with the provided JSON Web Key (jwk)
    tags: [{ name: "Action", value: "Load-Records" }], // Tags to associate with the data
    data: data, // Data to be processed and stored on the Arweave network
  });
  // Print the result of the network operation
  console.log(result);
}

// Call the main function to start the process
main();
