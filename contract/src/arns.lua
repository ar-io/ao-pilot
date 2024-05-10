-- arns.lua
local utils = require("utils")
local constants = require("constants")
local token = require('token')
local arns = {}

Balances = Balances or {}
Records = Records or {}
Auctions = Auctions or {}
Reserved = Reserved or {}
DemandFactor = DemandFactor or {}

--- Function to purchase a record.
-- @param name string: The name of the record to buy.
-- @param purchaseType string: The type of purchase (e.g., 'lease', 'own').
-- @param years number: The number of years for the record purchase.
-- @param from string: The origin of the purchase.
-- @param timestamp number: The UNIX timestamp of when the purchase was made.
-- @param processId string: A unique identifier for the processing transaction.
function arns.buyRecord(name, purchaseType, years, from, auction, timestamp, processId)
	-- don't catch, let the caller handle the error
	local validRecord = utils.validateBuyRecord(name, years, purchaseType, auction, processId)
	if validRecord == false then
		return  error("Failed to validate buy recor")
	end

	if purchaseType == nil then
		purchaseType = "lease" -- set to lease by default
	end

	if years == nil then
		years = 1 -- set to 1 year by default
	end

	local totalRegistrationFee = utils.calculateRegistrationFee(purchaseType, name, years)

	if not Balances[from] or Balances[from] < totalRegistrationFee then
		error("Insufficient funds")
	end

	if Auctions[name] then
		error("Name is in auction")
	end

	if Records[name] then
		error("Name is already registered")
	end

	if Reserved[name] and Reserved[name].target ~= from then
		error('Name is reserved')
	end

	-- Transfer tokens to the protocol balance
	token.transfer(ao.id, from, totalRegistrationFee)

	local newRecord = {
		processId = processId,
		startTimestamp = timestamp,
		type = purchaseType,
		undernameCount = constants.DEFAULT_UNDERNAME_COUNT,
		purchasePrice = totalRegistrationFee,
	}

	-- Register the leased or permabought name
	if purchaseType == "lease" then
		newRecord.endTimestamp = timestamp + constants.MS_IN_A_YEAR * years
	end

	Records[name] = newRecord
	Reserved[name] = nil -- delete reserved if necessary
	return newRecord
end

function arns.submitAuctionBid()
	utils.reply("submitAuctionBid is not implemented yet")
end

function arns.extendLease(from, name, years, timestamp)
	local record = Records[name]
	local validExtend, validExtendErr = utils.validateExtendLease(record, timestamp, years)
	if validExtend == false then
		return false, validExtendErr
	end

	local totalExtensionFee = utils.calculateExtensionFee(name, years, record.type)
	-- Transfer tokens to the protocol balance
	token.transfer(ao.id, from, totalExtensionFee)

	Records[name].endTimestamp = Records[name].endTimestamp + constants.MS_IN_A_YEAR * years
	return Records[name]
end

function arns.increaseUndernameCount(from, name, qty, timestamp)
	-- validate record can increase undernames
	local record = arns.getRecord(name)
	local validIncrease = utils.validateIncreaseUndernames(record, tonumber(qty), timestamp)
	if validIncrease == false then
		return false, err
	end

	local endTimestamp
	if utils.isLeaseRecord(record) then
		endTimestamp = record.endTimestamp
	end

	local yearsRemaining = constants.PERMABUY_LEASE_FEE_LENGTH
	if endTimestamp then
		yearsRemaining = utils.calculateYearsBetweenTimestamps(timestamp, endTimestamp)
	end

	local existingUndernames = record.undernameCount
	local additionalUndernameCost = utils.calculateUndernameCost(name, qty, record.type, yearsRemaining)

	-- Transfer tokens to the protocol balance
	token.transfer(ao.id, from, additionalUndernameCost)
	Records[name].undernameCount = existingUndernames + qty
	return Records[name]
end

function arns.getRecord(name)
	if Records[name] == nil then
		error("Name does not exist")
	end
	return Records[name]
end

function arns.getRecords()
	return Records
end

function arns.getAuction(name)
	if Auctions[name] == nil then
		error("Name does not exist")
	end
	return Auctions[name]
end

function arns.getAuctions()
	return Auctions
end

function arns.getReservedName(name)
	if Reserved[name] == nil then
		error("Resreved name does not exist")
	end
	return Reserved[name]
end

function arns.addReservedName(name, details)
	if Reserved[name] then
		error("Name is already reserved")
	end

	if Records[name] then
		error("Name is already registered")
	end

	if Auctions[name] then
		error("Name is in auction")
	end

	Reserved[name] = details
	return Reserved[name]
end

function arns.getReservedNames()
	return Reserved
end

return arns
