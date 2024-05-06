-- arns.lua
local utils = require '.utils'
local constants = require '.constants'
local arns = {}

if not Records then
    Records = {}
end

if not Auctions then
    Auctions = {}
end

function arns.buyRecord(msg)
    local name = string.lower(msg.Tags.Name)
    local validRecord, validRecordErr = utils.validateBuyRecord(msg.Tags)
    if msg.Tags.PurchaseType == nil then
        msg.Tags.PurchaseType = 'lease' -- set to lease by default
    end

    if msg.Tags.Years == nil then
        msg.Tags.Years = 1 -- set to 1 year by default
    end

    if validRecord == false then
        print("Error for name: " .. name)
        print(validRecordErr)
        ao.send({
            Target = msg.From,
            Tags = { Action = 'ArNS-Invalid-Record-Notice', Sender = msg.From, Name = tostring(msg.Tags.Name), ProcessId = tostring(msg.Tags.ProcessId) }
        })
        return false
    end

    local totalRegistrationFee = utils.calculateRegistrationFee(msg.Tags.PurchaseType, name, msg.Tags.Years)
    if not utils.walletHasSufficientBalance(msg.From, totalRegistrationFee) then
        print('Not enough tokens for this name')
        ao.send({
            Target = msg.From,
            Tags = { Action = 'ArNS-Insufficient-Funds', Sender = msg.From, Name = tostring(msg.Tags.Name), ProcessId = tostring(msg.Tags.ProcessId) }
        })
        return false
    end

    if Auctions[name] then
        print('Name is under auction')
        ao.send({
            Target = msg.From,
            Tags = { Action = 'ArNS-Deny-Notice', Sender = msg.From, Name = tostring(msg.Tags.Name), ProcessId = tostring(msg.Tags.ProcessId) }
        })
        return false
    elseif utils.isExistingActiveRecord(Records[name], msg.Timestamp) then
        -- Notify the original purchaser
        print('Name is already registered')
        ao.send({
            Target = msg.From,
            Tags = { Action = 'ArNS-Deny-Notice', Sender = msg.From, Name = tostring(msg.Tags.Name), ProcessId = tostring(msg.Tags.ProcessId) }
        })
        return false
    else
        print('This name is available for purchase!')

        -- Transfer tokens to the protocol balance
        if not Balances[msg.From] then Balances[msg.From] = 0 end
        if not Balances[ao.id] then Balances[ao.id] = 0 end
        Balances[msg.From] = Balances[msg.From] - totalRegistrationFee
        Balances[ao.id] = Balances[ao.id] + totalRegistrationFee

        -- Register the leased or permabought name
        if msg.Tags.PurchaseType == 'lease' then
            Records[name] = {
                processId = msg.Tags.ProcessId,
                endTimestamp = msg.Timestamp + constants.MS_IN_A_YEAR * msg.Tags.Years,
                startTimestamp = msg.Timestamp,
                type = "lease",
                undernames = constants.DEFAULT_UNDERNAME_COUNT,
                purchasePrice = totalRegistrationFee
            }
        elseif msg.Tags.PurchaseType == 'permabuy' then
            Records[name] = {
                processId = msg.Tags.ProcessId,
                startTimestamp = msg.Timestamp,
                type = "permabuy",
                undernames = constants.DEFAULT_UNDERNAME_COUNT,
                purchasePrice = totalRegistrationFee
            }
        end
        print('Added record: ' .. name)

        ao.send({
            Target = msg.From,
            Tags = { Action = 'ArNS-Purchase-Notice', Name = tostring(msg.Tags.Name), ProcessId = tostring(msg.Tags.ProcessId) }
        })
    end
    return true
end

function arns.submitAuctionBid()
    utils.reply("submitAuctionBid is not implemented yet")
end

function arns.extendLease()
    -- TODO: implement
    utils.reply("extendLease is not implemented yet")
end

function arns.increaseUndernameCount()
    -- TODO: implement
    utils.reply("increaseUndernameCount is not implemented yet")
end

function arns.getRecord()
    -- TODO: implement
    utils.reply("getRecord is not implemented yet")
end

function arns.getAuction()
    -- TODO: implement
    utils.reply("getAuction is not implemented yet")
end

function arns.getReservedName()
    -- TODO: implement
    utils.reply("getReservedName is not implemented yet")
end

return arns
