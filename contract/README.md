## AO/IO Contract

[![codecov](https://codecov.io/github/ar-io/ao-pilot/graph/badge.svg?token=0VUJ3RH9X1)](https://codecov.io/github/ar-io/ao-pilot)

The implementation of the ar.io network contract is written in lua and deployed as an AO process on Arweave. The contract is responsible for managing the network state, handling transactions, and enforcing the network rules. Refer to the [contract whitepaper] for more details on the network rules and the contract design.

Handlers:

### Arweave Name Service (ArNS)

- `BuyRecord` - buy a record
- `ExtendLease` - extend the lease of a record
- `IncreaseUndernameLimit` - increase the undername limit of a record

## Gateway Registry

- `JoinNetwork` - join a network
- `LeaveNetwork` - leave a network
- `UpdateGatewaySettings` - update a gateway settings
- `IncreaseOperatorStake`- increase operator stake
- `DecreaseOperatorStake` - decrease operator stake
- `DelegateStake` - delegate stake to an existing gateway
- `DecreaseDelegatedStake` - decrease delegated stake to an existing gateway

## Observer Incentive Protocol (OIP)

- `SaveObservations` - save observations for a given epoch
- `Observations` - get observations for a given Epoch
- `PrescribedObservers` - get prescribed observers for a given Epoch
- `PrescribedNames` - get prescribed names for a given Epoch

## Epoch

- `Epoch` - get epoch details
- `Epochs` - get all epochs

[contract whitepaper]: https://ar.io/whitepaper
