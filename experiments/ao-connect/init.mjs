import {
    createDataItemSigner,
    spawn
} from "@permaweb/aoconnect";

import fs from 'fs'
import path from 'path'

const suAddress = 'uW1Qm8BRsfj-tjip0BkVV-CHy6sBPF0Db0H8b15rsD8'
const dirname = path.dirname(new URL(import.meta.url).pathname)
const jwk = JSON.parse(fs.readFileSync(dirname + '/wallet.json').toString())
await spawn({
    module: '6xSB_-rcVEc8znlSe3JZBYHRsFw5lcgjhLyR8b6leLA',
    scheduler: suAddress,
    signer: createDataItemSigner(jwk),
}).then((result) => {
    console.log('Spawned new process to scheduler', result)
}).catch((error) => {
    console.error('Failed to spawn new process', error)
})

