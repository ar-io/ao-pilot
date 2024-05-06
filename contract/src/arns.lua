-- arns.lua

local utils = require 'utils'
local constants = require 'constants'
local arns = {}
if not Records then
    Records = {}
end
if not Auctions then
    Auctions = {}
end
if not Reserved then
    Reserved = {}
end
local auctions = {}
local reserved = {}

function arns.buyRecord(msg)
    local name = msg.Tags.Name
    local type = 'lease'
    local processTxId = msg.Tags.ProcessId

    if(name == nil or processTxId == nil) then
        -- utils.reply("name is required")
        return false
    end

    if msg.Tags.PurchaseType == 'permabuy' then 
        type = msg.Tags.PurchaseType 
    end

    --  TODO: active lease check
    if(Records[name] ~= nil) then
        -- utils.reply("name already exists")
        return 'false'
    end

    if(auctions[name] ~= nil) then
        -- utils.reply("name is in auction")
        return false
    end

    if(reserved[name] ~= nil) then
        -- utils.reply("name is reserved")
        return false
    end
    
    -- TODO: get the price of the name and check if the user has enough balance
    local price = 0
    Records[name] = {
        purchasePrice = price,
        type = type,
        undernameCount = 10,
        processTxId = processTxId
    }
    
    if(type == "lease") then 
        Records[name].endTimestamp = os.clock() + constants.oneYearSeconds * 1000
    end

    return Records[name]
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

function arns.getRecord(name)
    if(name == nil) then
        utils.reply("name is required")
    end

    if(Records[name] == nil) then
        utils.reply("name does not exist")
    end

    utils.reply(Records[name])
end

function arns.getAuction(name)
    if(name == nil) then
        utils.reply("name is required")
    end

    if(auctions[name] == nil) then
        utils.reply("name does not exist")
    end

    utils.reply(auctions[name])
end

function arns.getReservedName()
    -- TODO: implement
    utils.reply("getReservedName is not implemented yet")
end

return arns
