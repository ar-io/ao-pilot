local state = { _version = '0.0.0' }
Name = Name or "Test IO"
Ticker = Ticker or "tIO"
Logo = Logo or "Sie_26dvgyok0PZD_-iQAFOhOd5YxDTkczOLoqTTL_A"

if not Denomination then
    Denomination = 6
end

if not Balances then
    Balances = {}
end

if not Gateways then
    Gateways = {}
end

if not Vaults then
    Vaults = {}
end

if not PrescribedObservers then
    PrescribedObservers = {}
end

if not Observations then
    Observations = {}
end


return state
