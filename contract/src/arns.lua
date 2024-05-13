-- arns.lua
local utils = require("utils")
local constants = require("constants")
local token = Token or require("token")
local demand = Demand or require("demand")
local arns = {
	reserved = {},
	records = {},
	auctions = {},
	fees = constants.genesisFees,
}
function arns.buyRecord(name, purchaseType, years, from, auction, timestamp, processId)
	-- don't catch, let the caller handle the error
	utils.assertValidBuyRecord(name, years, purchaseType, auction, processId)

	if purchaseType == nil then
		purchaseType = "lease" -- set to lease by default
	end

	if years == nil then
		years = 1 -- set to 1 year by default
	end

	local baseRegistrionFee = arns.fees[#name]

	local totalRegistrationFee = utils.calculateRegistrationFee(purchaseType, baseRegistrionFee, years, demand.getDemandFactor())

	if token.getBalance(from) < totalRegistrationFee then
		error("Insufficient funds")
	end

	if arns.getAuction(name) then
		error("Name is in auction")
	end

	if arns.getRecord(name) then
		error("Name is already registered")
	end

	if arns.getReservedName(name) and arns.getReservedName(name).target ~= from then
		error("Name is reserved")
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

	arns.records[name] = newRecord
	arns.reserved[name] = nil
	return newRecord
end

function arns.submitAuctionBid()
	utils.reply("submitAuctionBid is not implemented yet")
end

function arns.extendLease(from, name, years, timestamp)
	local record = arns.getRecord(name)
	-- throw error if invalid
	utils.assertValidExtendLease(record, timestamp, years)
	local baseRegistrionFee = arns.fees[#name]
	local totalExtensionFee = utils.calculateExtensionFee(baseRegistrionFee, years, demand.getDemandFactor())
	-- Transfer tokens to the protocol balance
	token.transfer(ao.id, from, totalExtensionFee)

	arns.records[name].endTimestamp = record.endTimestamp + constants.MS_IN_A_YEAR * years
	return arns.records[name]
end

function arns.calculateExtensionFee(name, years, purchaseType)
	local record = arns.getRecord(name)
	local yearsRemaining = utils.calculateYearsBetweenTimestamps(record.endTimestamp, timestamp)
	local extensionFee = utils.calculateUndernameCost(name, years, purchaseType, yearsRemaining)
	return extensionFee
end

function arns.increaseUndernameCount(from, name, qty, timestamp)
	-- validate record can increase undernames
	local record = arns.getRecord(name)

	-- throws errors on invalid requests
	utils.assertValidIncreaseUndername(record, qty, timestamp)

	local endTimestamp
	if utils.isLeaseRecord(record) then
		endTimestamp = record.endTimestamp
	end

	local yearsRemaining = constants.PERMABUY_LEASE_FEE_LENGTH
	if endTimestamp then
		yearsRemaining = utils.calculateYearsBetweenTimestamps(timestamp, endTimestamp)
	end

	local existingUndernames = record.undernameCount
	local baseRegistrionFee = arns.fees[#name]
	local additionalUndernameCost = utils.calculateUndernameCost(baseRegistrionFee, qty, record.type, yearsRemaining, demand.getDemandFactor())

	-- Transfer tokens to the protocol balance
	token.transfer(ao.id, from, additionalUndernameCost)
	arns.records[name].undernameCount = existingUndernames + qty
	return arns.records[name]
end

function arns.getRecord(name)
	return arns.records[name]
end

function arns.getRecords()
	return arns.records
end

function arns.getAuction(name)
	return arns.auctions[name]
end

function arns.getAuctions()
	return arns.auctions
end

function arns.getReservedName(name)
	return arns.reserved[name]
end

function arns.addReservedName(name, details)
	if arns.getReservedName(name) then
		error("Name is already reserved")
	end

	if arns.getRecord(name) then
		error("Name is already registered")
	end

	if arns.getAuction(name) then
		error("Name is in auction")
	end
	arns.reserved[name] = details
	return arns.reserved[name]
end

function arns.getReservedNames()
	return arns.reserved
end

function arns.addRecord(name, record)
	arns.records[name] = record
end

return arns
