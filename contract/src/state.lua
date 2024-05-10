local state = { _version = '0.0.0' }
local demand = require('demand')
local json = require('json')

Name = Name or "Test IO"
Ticker = Ticker or "tIO"
Logo = Logo or "Sie_26dvgyok0PZD_-iQAFOhOd5YxDTkczOLoqTTL_A"

LastStateLoad = LastStateLoad or nil

Balances = Balances or {}
Records = Records or {}
Auctions = Auctions or {}
Reserved = Reserved or {}
Denomination = Denomination or 6
Gateways = Gateways or {}
Vaults = Vaults or {}
PrescribedObservers = PrescribedObservers or {}
Observations = Observations or {}
Distributions = Distributions or {}
Demand = Demand or {}

function state.loadState(data, currentTimestamp)
    local data, err = json.decode(data)
    if not data or err then
        -- Handle error (e.g., send an error response)
        return false, "Error decoding JSON data"
    end

    -- Counter for added or updated records.
    local recordsAddedOrUpdated = 0
    -- Ensure 'data.records' is present and iterate through the decoded data to update the Records table accordingly.
    if data.records then
        if type(data.records) == "table" then
            for key, value in pairs(data.records) do
                -- Preserve the existing processId if the record already exists.
                local existingProcessId = Records[key] and Records[key].processId

                -- Check if the record either doesn't exist or differs from the new value.
                if not Records[key] or (Records[key] and json.encode(Records[key]) ~= json.encode(value)) then
                    recordsAddedOrUpdated = recordsAddedOrUpdated + 1
                    Records[key] = value
                    Records[key].processId = existingProcessId or value.processId -- Preserve or initialize processId.
                end
            end
        else
            -- Handle the case where 'data.records' is not in the expected format.
            return false, "The 'records' field is missing or not in the expected format."
        end
    end

    local gatewaysAddedOrUpdated = 0
    if data.gateways then
        if type(data.gateways) == "table" then
            for key, value in pairs(data.gateways) do
                if not Gateways[key] or (Gateways[key] and json.encode(Gateways[key]) ~= json.encode(value)) then
                    gatewaysAddedOrUpdated = gatewaysAddedOrUpdated + 1
                    Gateways[key] = value
                end
            end
        else
            -- Handle the case where 'data.gateways' is not in the expected format.
            return false, "The 'gateways' field is missing or not in the expected format."
        end
    end

    local observationsAddedOrUpdated = 0
    if data.observations then
        if type(data.observations) == "table" then
            for key, value in pairs(data.observations) do
                if not Observations[key] or (Observations[key] and json.encode(Observations[key]) ~= json.encode(value)) then
                    observationsAddedOrUpdated = observationsAddedOrUpdated + 1
                    Observations[key] = value
                end
            end
        else
            -- Handle the case where 'data.observations' is not in the expected format.
            return false, "The 'gatewobservationsays' field is missing or not in the expected format."
        end
    end

    local distributionsUpdated = 0
    if data.distributions then
        if type(data.distributions) == "table" then
            Distributions = data.distributions
            distributionsUpdated = distributionsUpdated + 1
        else
            -- Handle the case where 'data.distributions' is not in the expected format.
            return false, "The 'distributions' field is missing or not in the expected format."
        end
    end

    local demandUpdated = 0
    if data.demandFactoring then
        if type(data.demandFactoring) == "table" then
            Demand = data.demandFactoring
            demandUpdated = demandUpdated + 1
        else
            -- Handle the case where 'data.demandFactoring' is not in the expected format.
            return false, "The 'demandFactoring' field is missing or not in the expected format."
        end
    end

    LastStateLoad = currentTimestamp

    return "Records Updated: " ..
        recordsAddedOrUpdated ..
        " Gateways Updated: " ..
        gatewaysAddedOrUpdated ..
        "  Observations Updated: " ..
        observationsAddedOrUpdated ..
        " Distributions Updated: " .. distributionsUpdated .. " Demand Updated: " .. demandUpdated
end

return state
