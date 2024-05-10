-- CRON job responsible for

-- Removing expiried records for arns state
-- Removing expiried records for balances state
-- Remvoing expired reserved names
-- Removing gateways from the registry
-- Moving auctions to records
-- Update presribed observers for the epoch
-- Returning vaulted balances to owners
-- Distributing epoch rewards to obseververs and deletegates
local tick = {}

function tick.records(currentTimestamp)
    for key, record in pairs(Records) do
        if isExistingActiveRecord(record, currentTimestamp) == false then
            -- Remove the record that is expired TO DO
            Records[key] = nil
        end
    end
    return true
end

function tick.reservedNames(currentTimestamp)

return tick
