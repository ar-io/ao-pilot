import Arweave from "arweave";
import fs from 'fs'

export const arweave = Arweave.init({
    host: 'arweave.net',
    protocol: 'https',
    port: 443
})

export async function generateWallet() {
    const jwk = await arweave.wallets.generate()
    const walletFileName = 'key.json'
    await fs.writeFileSync(walletFileName, JSON.stringify(jwk))
    return { jwk, walletFileName }
}

export function sleep(ms: number) {
    return new Promise((resolve) => setTimeout(resolve, ms));
}