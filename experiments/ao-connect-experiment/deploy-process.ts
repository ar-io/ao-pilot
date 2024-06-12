import { connect, createDataItemSigner } from '@permaweb/aoconnect'
import fs from 'fs'
import path from 'path'

const ao = connect()
const moduleId = "5DdJmW2L82aZz1BlYSSs-eDVWjLXJlT6LZ53y1l4O7U"
const scheduler = "_GQ33BkPtZrqxA84vM8Zk-N2aO0toNNu_C-l-rawrBA"

async function main() {

    const wallet = fs.readFileSync(path.join(__dirname, 'key.json'), 'utf-8')
    const signer = createDataItemSigner(JSON.parse(wallet))

    const processId = await ao.spawn({
        module: moduleId,
        scheduler,
        signer
    })
    await new Promise((resolve) => setTimeout(resolve, 10_000))

    // const processId = "v3r6Us2elpM-GXezJKbkTevQ4iKnWq4w8RWevK55YxM"

    const testCases: Array<Array<string | object>> = [
        ["Set-Controller", {"Controller": "".padEnd(43, "1")}]
    ]

    for (const [method, args] of testCases) {
        const tags = args ? Object.entries(args).map(([key, value]) => ({name: key, value})) : []
        const result = await ao.dryrun({
            process: processId,
            tags: [
                ...tags,
                {name: "Action", value: method as string}
            ],
            signer
        })

        console.log(result)
    }

}

main()