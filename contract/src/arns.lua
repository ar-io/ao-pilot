-- arns.lua

local utils = require 'utils'
local constants = require 'constants'
local arns = {}
local records = {}
local auctions = {}
local reserved = {}

function arns.buyRecord(name, type, processTxId, caller)
    if(name == nil or type == nil or processTxId == nil) then
        utils.reply("name is required")
    end

    --  TODO: active lease check
    if(records[name] ~= nil) then
        utils.reply("name already exists")
    end

    if(auctions[name] ~= nil) then
        utils.reply("name is in auction")
    end

    if(reserved[name] ~= nil) then
        utils.reply("name is reserved")
    end
    
    -- TODO: get the price of the name and check if the user has enough balance
    local price = 0
    records[name] = {
        owner = caller,
        price = price,
        type = type,
        undernameCount = 10,
        processTxId = processTxId
    }
    
    if(type == "lease") then 
        records[name].endTimestamp = os.clock() + constants.oneYearSeconds * 1000
    end

    return records[name]
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

    if(records[name] == nil) then
        utils.reply("name does not exist")
    end

    utils.reply(records[name])
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
