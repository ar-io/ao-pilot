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
import { generateWallet } from "./utils";

const processId = "H_3EirnLXUrdqQ2ouE4zB72biF_XknOd8DKCnEP0I1I"

export async function readANTState() {
    const { jwk } = await generateWallet()
    const messageId = await message({
        process: processId,
        tags: [{ name: "Action", value: "Info" }],
        signer: createDataItemSigner(jwk)
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

// output

// chain message results:
// {
//   Messages: [
//     {
//       Tags: [
//         { value: 'ao', name: 'Data-Protocol' },
//         { value: 'ao.TN.1', name: 'Variant' },
//         { value: 'Message', name: 'Type' },
//         {
//           value: 'H_3EirnLXUrdqQ2ouE4zB72biF_XknOd8DKCnEP0I1I',
//           name: 'From-Process'
//         },
//         {
//           value: '1SafZGlZT4TLI8xoc0QEQ4MylHhuyQUblxD8xLKvEKI',
//           name: 'From-Module'
//         },
//         { value: '179', name: 'Ref_' },
//         {
//           value: 'iKryOeZQMONi2965nKz528htMMN_sBcjlhc-VncoRjA',
//           name: 'ProcessOwner'
//         },
//         { value: '[]', name: 'Controllers' },
//         {
//           value: 'Sie_26dvgyok0PZD_-iQAFOhOd5YxDTkczOLoqTTL_A',
//           name: 'Logo'
//         },
//         { value: 'ant-token-experiment-2', name: 'Name' },
//         { value: 'ANT-AO-EXP1', name: 'Ticker' },
//         { value: '1', name: 'Denomination' }
//       ],
//       Anchor: '00000000000000000000000000000179',
//       Target: 'mgs6-9Z8xi-XLfKvvEs_5ypEgyPv56kurYuBqVp8JQk'
//     }
//   ],
//   Spawns: [],
//   Output: [],
//   GasUsed: 612243672
// }
// dry run results:
// {
//   Messages: [
//     {
//       Tags: [
//         { value: 'ao', name: 'Data-Protocol' },
//         { value: 'ao.TN.1', name: 'Variant' },
//         { value: 'Message', name: 'Type' },
//         {
//           value: 'H_3EirnLXUrdqQ2ouE4zB72biF_XknOd8DKCnEP0I1I',
//           name: 'From-Process'
//         },
//         {
//           value: '1SafZGlZT4TLI8xoc0QEQ4MylHhuyQUblxD8xLKvEKI',
//           name: 'From-Module'
//         },
//         { value: '180', name: 'Ref_' },
//         {
//           value: 'iKryOeZQMONi2965nKz528htMMN_sBcjlhc-VncoRjA',
//           name: 'ProcessOwner'
//         },
//         { value: '[]', name: 'Controllers' },
//         {
//           value: 'Sie_26dvgyok0PZD_-iQAFOhOd5YxDTkczOLoqTTL_A',
//           name: 'Logo'
//         },
//         { value: 'ant-token-experiment-2', name: 'Name' },
//         { value: 'ANT-AO-EXP1', name: 'Ticker' },
//         { value: '1', name: 'Denomination' }
//       ],
//       Anchor: '00000000000000000000000000000180',
//       Target: '1234'
//     }
//   ],
//   Spawns: [],
//   Output: [],
//   GasUsed: 446993263
// }