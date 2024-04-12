import { EthereumSigner } from "arbundles";
import Arweave from "arweave";
import fs from 'fs'
import { createData, ArweaveSigner, DataItem } from "warp-arbundles";

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

export function createArweaveDataItemSigner (wallet: any) {
    const signer = async ({ data, tags, target, anchor }: any) => {
      const arSigner = new ArweaveSigner(wallet)
      const dataItem = createData(data, arSigner, { tags, target, anchor })
      
      const res = await dataItem.sign(arSigner)
        .then(async () => ({
          id: await dataItem.id,
          raw: await dataItem.getRaw()
        }))

        console.dir({
            valid: await dataItem.isValid(),
            signature: await dataItem.signature,
            owner: await dataItem.owner,
            tags: await dataItem.tags,
            id: await dataItem.id,
            res
          }, { depth: 2 })
        return res
    }
  
    return signer
  }

  export function createEthereumDataItemSigner (pk: string) {
    /**
     * createDataItem can be passed here for the purposes of unit testing
     * with a stub
     */
    const ethSigner = new EthereumSigner(pk)
    const signer = async ({ data, tags, target, anchor }: any) => {
        const dataItem = createData(data, ethSigner, { tags, target, anchor})

        const res = await dataItem.sign(ethSigner)
          .then(async (b:Buffer) => ({
            id: await dataItem.id,
            raw: await dataItem.getRaw(),

          })).catch((e)=> console.error(e))
          console.dir({
            valid: await EthereumSigner.verify(ethSigner.publicKey, await dataItem.getSignatureData(), dataItem.rawSignature),
            signature: await dataItem.signature,
            owner: await dataItem.owner,
            tags: await dataItem.tags,
            id: await dataItem.id,
            res
          }, { depth: 2 })
      return res
      }
  
    return signer
  }
