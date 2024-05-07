import {
    createDataItemSigner,
    spawn
} from "@permaweb/aoconnect";

import fs from 'fs'
import path from 'path'

async function init() {
    const dirname = path.dirname(new URL(import.meta.url).pathname)
    const jwk = JSON.parse(fs.readFileSync(dirname + '/wallet.json').toString())
    const process = await spawn({
        module: '6xSB_-rcVEc8znlSe3JZBYHRsFw5lcgjhLyR8b6leLA',
        scheduler: 'Lg6V6kGE_sn497UF57OOFQgo4RXMvulK-_0H3TzMcQ8',
        signer: createDataItemSigner(jwk),
    })

    console.log(process)
}

init()
