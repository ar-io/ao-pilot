-- arns.lua
local utils = require(".utils")
local constants = require(".constants")
local arns = {}

if not Balances then
	Balances = {}
end

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
		target = "QGWqtJdLLgm2ehFWiiPzMaoFLD50CnGuzZIPEdoDRGQ",
	}

	Reserved["help"] = {
		endTimestamp = 1725080400000,
		target = "QGWqtJdLLgm2ehFWiiPzMaoFLD50CnGuzZIPEdoDRGQ",
	}

	Reserved["io"] = {
		endTimestamp = 1725080400000,
		target = "QGWqtJdLLgm2ehFWiiPzMaoFLD50CnGuzZIPEdoDRGQ",
	}

	Reserved["nodes"] = {
		endTimestamp = 1725080400000,
		target = "QGWqtJdLLgm2ehFWiiPzMaoFLD50CnGuzZIPEdoDRGQ",
	}

	Reserved["www"] = {
		endTimestamp = 1725080400000,
		target = "QGWqtJdLLgm2ehFWiiPzMaoFLD50CnGuzZIPEdoDRGQ",
	}
end

-- Needs auctions
-- Needs demand factor

--- Function to purchase a record.
-- @param name string: The name of the record to buy.
-- @param purchaseType string: The type of purchase (e.g., 'lease', 'own').
-- @param years number: The number of years for the record purchase.
-- @param from string: The origin of the purchase.
-- @param timestamp number: The UNIX timestamp of when the purchase was made.
-- @param processId string: A unique identifier for the processing transaction.
function arns.buyRecord(name, purchaseType, years, from, auction, timestamp, processId)
	local validRecord, validRecordErr = utils.validateBuyRecord(name, years, purchaseType, auction, processId)
	if purchaseType == nil then
		purchaseType = "lease" -- set to lease by default
	end

	if years == nil then
		years = 1 -- set to 1 year by default
	end

	if validRecord == false then
		return false, validRecordErr
	end

	local totalRegistrationFee = utils.calculateRegistrationFee(purchaseType, name, years)

	if not Balances[from] or Balances[from] < totalRegistrationFee then
		return false, "Insufficient balance"
	end

	if Auctions[name] then
		return false, "Name is in auction"
	end

	if Records[name] then
		return false, "Name already exists"
	end

	-- Transfer tokens to the protocol balance
	if not Balances[from] then
		Balances[from] = 0
	end
	if not Balances[ao.id] then
		Balances[ao.id] = 0
	end
	Balances[from] = Balances[from] - totalRegistrationFee
	Balances[ao.id] = Balances[ao.id] + totalRegistrationFee

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
	return newRecord
end

function arns.submitAuctionBid()
	utils.reply("submitAuctionBid is not implemented yet")
end

function arns.extendLease(msg)
	if Records[msg.Tags.Name] == nil then
		-- NAME DOES NOT EXIST
		ao.send({
			Target = from,
			Tags = { Action = "ArNS-Invalid-Extend-Notice", Sender = from, Name = tostring(msg.Tags.Name) },
		})
		return false
	end

	if Balances[from] == nil then
		return false
	end

	if not utils.isLeaseRecord(Records[msg.Tags.Name]) then
		return false
	end

	return true
end

function arns.increaseUndernameCount(name, from, qty, timestamp)
	-- validate record can increase undernames
	local record = Records[name]
	if record == nil then
		return false, Records[name]
	end
	local validIncrease, err = utils.validateIncreaseUndernames(record, tonumber(qty), timestamp)
	if validIncrease == false then
		return false, err
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
		yearsRemaining = utils.calculateYearsBetweenTimestamps(timestamp, endTimestamp)
	else
		yearsRemaining = constants.PERMABUY_LEASE_FEE_LENGTH -- Assuming PERMABUY_LEASE_FEE_LENGTH is defined somewhere
	end

	local existingUndernames = record.undernameCount

	local additionalUndernameCost = utils.calculateUndernameCost(name, qty, record.type, yearsRemaining)

	if not utils.walletHasSufficientBalance(from, additionalUndernameCost) then
		return false, "Insufficient balance"
	end

	-- Transfer tokens to the protocol balance
	if not Balances[from] then
		Balances[from] = 0
	end
	if not Balances[ao.id] then
		Balances[ao.id] = 0
	end
	Balances[from] = Balances[from] - additionalUndernameCost
	Balances[ao.id] = Balances[ao.id] + additionalUndernameCost

	local incrementedUndernames = existingUndernames + qty
	Records[name].undernameCount = incrementedUndernames
	return Records[name]
end

function arns.getRecord(name)
	if Records[name] == nil then
		return nil
	end
	return Records[name]
end

function arns.getRecords()
	return Records
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
