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
import { arweave, generateWallet, sleep } from "./utils";
import fs from 'fs'
import path from 'path'
import { TurboFactory } from "@ardrive/turbo-sdk";


export async function deployANT() {
    // generate wallet to be used for our ao process
    const { jwk } = await generateWallet()

    // deploy our AO module to arweave
    const turbo = TurboFactory.authenticated({ privateKey: jwk })
    console.log("uploading ao module via turbo")
    const { id: antModuleId, owner, dataCaches, fastFinalityIndexes } = await turbo.uploadFile({
        fileStreamFactory: () => fs.createReadStream(path.resolve(__dirname + '/ant_module.lua')),
        fileSizeFactory: () => fs.statSync(path.resolve(__dirname + '/ant_module.lua')).size,
        dataItemOpts: {
            tags: [
                { name: "Data-Protocol", value: 'ao' },
                { name: "Type", value: "Module" },
                { name: "Memory-Limit", value: "500-mb" },
                { name: "Compute-Limit", value: "9000000000000" },
                { name: "Module-Format", value: "wasm32-unknown-emscripten" },
                { name: "Input-Encoding", value: "JSON-1" },
                { name: "Output-Encoding", value: "JSON-1" },
                { name: "Variant", value: "ao.TN.1" },
                { name: "Content-Type", value: "application/wasm" }
            ]
        }
    });
    console.log(`uploaded file`)
    console.dir({
        id: antModuleId,
        owner,
        dataCaches,
        fastFinalityIndexes
    })
    let status: any = null
    let attempts = 0

    while (status === null) {
        attempts++
        console.log(`waiting 5 seconds for antModule confirmation, attempt ${attempts}`)
        await sleep(5000)
        status = (await arweave.transactions.getStatus(antModuleId)).confirmed
        if (attempts > 1) {
            break;
        }
    }

    console.log(`module id confirmed: ${antModuleId}`)


    const scheduler = "TZ7o7SIZ06ZEJ14lXwVtng1EtSx60QkPy-kh-kdAXog"
    const processId = await spawn({
        // The Arweave TXID of the ao Module
        module: antModuleId,
        // The Arweave wallet address of a Scheduler Unit
        scheduler,
        // A signer function containing your wallet
        signer: createDataItemSigner(jwk),
        /*
          Refer to a Processes' source code or documentation
          for tags that may effect its computation.
        */
    });

    console.log(`Succesfully deployed ANT process.`)
    console.dir({
        owner: await arweave.wallets.jwkToAddress(jwk),
        processId
    })
}
deployANT()