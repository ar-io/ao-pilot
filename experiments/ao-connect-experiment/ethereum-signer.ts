import { createDataItemSigner, dryrun, message, result } from "@permaweb/aoconnect";
import { EthereumSigner } from "arbundles";
import { DataItem, createData } from "warp-arbundles";

const privateKey = "0x0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";

const signer = new EthereumSigner(privateKey);

const processId = "H_3EirnLXUrdqQ2ouE4zB72biF_XknOd8DKCnEP0I1I"

export function createDataItemEthereumSigner (ethSigner: EthereumSigner) {
    /**
     * createDataItem can be passed here for the purposes of unit testing
     * with a stub
     */
    const signer = async ({ data, tags, target, anchor }: any) => {
        const dataItem = createData(data, ethSigner, { tags, target, anchor })
        return dataItem.sign(ethSigner)
          .then(async () => ({
            id: await dataItem.id,
            raw: await dataItem.getRaw()
          }))
      }
  
    return signer
  }

export async function readANTState() {

    const messageId = await message({
        process: processId,
        tags: [{ name: "Action", value: "Info" }],
        signer: createDataItemEthereumSigner(signer) as any
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