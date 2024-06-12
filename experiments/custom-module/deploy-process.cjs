const { connect, createDataItemSigner } = require( '@permaweb/aoconnect')
const fs = require('fs')
const path = require('path')

const ao = connect({
    GATEWAY_URL: "https://arweave.net",
})
const moduleId = "VkhT634aGkBAAdXH9XLDMJIBGnp_XowYK7U14fQhhuY"
const scheduler = "_GQ33BkPtZrqxA84vM8Zk-N2aO0toNNu_C-l-rawrBA"

async function main() {

    const wallet = fs.readFileSync(path.join(__dirname, 'key.json'), 'utf-8')
    const signer = createDataItemSigner(JSON.parse(wallet))

    // const processId = await ao.spawn({
    //     module: moduleId,
    //     scheduler,
    //     signer
    // })
    // await new Promise((resolve) => setTimeout(resolve, 10_000))

     const processId = "WftWSU4dKylywVFbGU5w8pqTKwv6aJ3p6j6yIYHg6q4"

    const testCases = [
        ["Set-Controller", {"Controller": "".padEnd(43, "1")}]
    ]

    for (const [method, args] of testCases) {
        const tags = args ? Object.entries(args).map(([key, value]) => ({name: key, value})) : []
        const result = await ao.dryrun({
            process: processId,
            tags: [
                ...tags,
                {name: "Action", value: method}
            ],
            signer
        })

        console.log(result)
    }

}

main()