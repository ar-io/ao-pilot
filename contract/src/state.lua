local state = { _version = '0.0.0' }
local demand = require('demand')

Name = Name or "Test IO"
Ticker = Ticker or "tIO"
Logo = Logo or "Sie_26dvgyok0PZD_-iQAFOhOd5YxDTkczOLoqTTL_A"
Denomination = Denomination or 6
Balances = Balances or {}
Gateways = Gateways or {}
Vaults = Vaults or {}
PrescribedObservers = PrescribedObservers or {}
Observations = Observations or {}
Distributions = Distributions or {}
Demand = Demand or demand

return state
