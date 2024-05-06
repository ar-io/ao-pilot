-- arns.lua
local utils = require '.utils'
local constants = require '.constants'
local json = require '.json'
local arns = {}

if not Records then
    Records = {}
end

if not Auctions then
    Auctions = {}
end

if not Reserved then
    Reserved = {}
    Reserved["gateway"] = {
        endTimestamp = 1725080400000,
        target = "QGWqtJdLLgm2ehFWiiPzMaoFLD50CnGuzZIPEdoDRGQ"
    }

    Reserved["help"] = {
        endTimestamp = 1725080400000,
        target = "QGWqtJdLLgm2ehFWiiPzMaoFLD50CnGuzZIPEdoDRGQ"
    }

    Reserved["io"] = {
        endTimestamp = 1725080400000,
        target = "QGWqtJdLLgm2ehFWiiPzMaoFLD50CnGuzZIPEdoDRGQ"
    }

    Reserved["nodes"] = {
        endTimestamp = 1725080400000,
        target = "QGWqtJdLLgm2ehFWiiPzMaoFLD50CnGuzZIPEdoDRGQ"
    }

    Reserved["www"] = {
        endTimestamp = 1725080400000,
        target = "QGWqtJdLLgm2ehFWiiPzMaoFLD50CnGuzZIPEdoDRGQ"
    }
end

-- Needs auctions
-- Needs demand factor
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
    end

    local availableRecord, err = utils.assertAvailableRecord(msg.From, name, msg.Timestamp, msg.Tags.PurchaseType,
        msg.Tags.Auction)
    if not availableRecord then
        -- Notify the original purchaser
        print('Name is already registered')
        print(err)
        ao.send({
            Target = msg.From,
            Tags = { Action = 'ArNS-Deny-Notice', Sender = msg.From, Name = tostring(msg.Tags.Name), ProcessId = tostring(msg.Tags.ProcessId) }
        })
        return false
    else
        print('This name is available for ' .. msg.Tags.PurchaseType .. ' purchase!')

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

function arns.extendLease(msg)
    if Records[msg.Tags.Name] == nil then
        -- NAME DOES NOT EXIST
        ao.send({
            Target = msg.From,
            Tags = { Action = 'ArNS-Invalid-Extend-Notice', Sender = msg.From, Name = tostring(msg.Tags.Name) }
        })
        return false
    end

    if Balances[msg.From] == nil then
        return false
    end

    if not utils.isLeaseRecord(Records[msg.Tags.Name]) then
        return false
    end

    return true
end

function arns.increaseUndernameCount(msg)
    local name = string.lower(msg.Tags.Name)
    -- validate record can increase undernames
    local validIncrease, err = utils.validateIncreaseUndernames(Records[name], msg.Tags.Qty, msg.Timestamp)
    if validIncrease == false then
        print("Error for name: " .. name)
        print(err)
        ao.send({
            Target = msg.From,
            Tags = { Action = 'ArNS-Invalid-Undername-Increase-Notice', Name = tostring(name) }
        })
        return false;
    end

    local record = Records[name]
    local endTimestamp
    if utils.isLeaseRecord(record) then
        endTimestamp = record.endTimestamp
    else
        endTimestamp = nil
    end

    local yearsRemaining
    if endTimestamp then
        yearsRemaining = utils.calculateYearsBetweenTimestamps(msg.Timestamp, endTimestamp)
    else
        yearsRemaining = constants.PERMABUY_LEASE_FEE_LENGTH -- Assuming PERMABUY_LEASE_FEE_LENGTH is defined somewhere
    end

    local existingUndernames = record.undernames

    local additionalUndernameCost = utils.calculateUndernameCost(name, msg.Tags.Qty, record.type,
        yearsRemaining)

    if not utils.walletHasSufficientBalance(msg.From, additionalUndernameCost) then
        print('Not enough tokens for adding undernames.')
        ao.send({
            Target = msg.From,
            Tags = { Action = 'ArNS-Insufficient-Funds', Name = tostring(name) }
        })
        return false
    end

    -- Transfer tokens to the protocol balance
    if not Balances[msg.From] then Balances[msg.From] = 0 end
    if not Balances[ao.id] then Balances[ao.id] = 0 end
    Balances[msg.From] = Balances[msg.From] - additionalUndernameCost
    Balances[ao.id] = Balances[ao.id] + additionalUndernameCost

    local incrementedUndernames = existingUndernames + msg.Tags.Qty
    Records[name].undernames = incrementedUndernames
    print('Increased undernames for: ' .. name .. " to " .. incrementedUndernames .. " undernames")

    ao.send({
        Target = msg.Tags.Sender,
        Tags = { Action = 'ArNS-Increase-Undername-Notice', Name = tostring(name), IncrementedUndernames = tostring(incrementedUndernames) }
    })
    return true
end

function arns.getRecord(msg)
    -- Ensure the 'Name' tag is present and the record exists before proceeding.
    if msg.Tags.Name and Records[msg.Tags.Name] then
        -- Prepare and send a response with the found record's details.
        local recordDetails = Records[msg.Tags.Name]
        ao.send({
            Target = msg.From,
            Tags = {
                Action = 'Record-Resolved',
                Name = msg.Tags.Name,
                ContractTxId = recordDetails.ContractTxId,
                ProcessId = recordDetails.ProcessId
            },
            Data = json.encode(recordDetails)
        })
        return json.encode(recordDetails)
    else
        -- Send an error response if the record name is not provided or the record does not exist.
        ao.send({
            Target = msg.From,
            Tags = {
                Action = 'Get-Record-Error',
                ['Message-Id'] = msg.Id, -- Ensure message ID is passed for traceability.
                Error = 'Requested non-existent record'
            }
        })
        return false
    end
end

function arns.getRecords(msg)
    ao.send({
        Action = 'Records-Resolved',
        Target = msg.From,
        Data =
            json.encode(Records)
    })
    return json.encode(Records)
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
