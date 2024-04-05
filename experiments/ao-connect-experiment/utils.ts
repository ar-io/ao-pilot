import Arweave from "arweave";
import fs from 'fs'

// Initialize Arweave connection
export const arweave = Arweave.init({
    host: 'arweave.net',
    protocol: 'https',
    port: 443
})

// Function to generate a new Arweave wallet and save it to a JSON file
export async function generateWallet() {
    // Generate a new wallet
    const jwk = await arweave.wallets.generate()
    // Define the filename for the wallet JSON file
    const walletFileName = 'key.json'
    // Write the generated wallet to a JSON file
    await fs.writeFileSync(walletFileName, JSON.stringify(jwk))
    // Return the generated wallet object and the filename
    return { jwk, walletFileName }
}

// Function to pause execution for a specified number of milliseconds
export function sleep(ms: number) {
    return new Promise((resolve) => setTimeout(resolve, ms));
}
