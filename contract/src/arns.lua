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

function arns.buyRecord(name, purchaseType, years, from, timestamp, processId)
	-- don't catch, let the caller handle the error
	arns.assertValidBuyRecord(name, years, purchaseType, processId)
	if purchaseType == nil then
		purchaseType = "lease" -- set to lease by default
	end

	if years == nil then
		years = 1 -- set to 1 year by default
	end

	local baseRegistrionFee = arns.fees[#name]

	local totalRegistrationFee =
		arns.calculateRegistrationFee(purchaseType, baseRegistrionFee, years, demand.getDemandFactor())

	if token.getBalance(from) < totalRegistrationFee then
		error("Insufficient balance")
	end

	if arns.getAuction(name) then
		error("Name is in auction")
	end

	if arns.getRecord(name) and arns.getRecord(name).endTimestamp + constants.gracePeriodMs > timestamp then
		error("Name is already registered")
	end

	-- todo, handle reserved name timestamps
	local reservedForCaller = arns.getReservedName(name) and arns.getReservedName(name).target == from
	if arns.getReservedName(name) and arns.getReservedName(name).target ~= from then
		error("Name is reserved")
	end

	if not reservedForCaller and #name < 5 then
		error("Name not available for purchase")
	end

	if not reservedForCaller and (purchaseType == "permabuy" and #name < 12) then
		-- error("Name must be auctioned")
		-- TODO: for now - just state the name is not available for purchase
		error("Name not available for purchase")
	end

	local newRecord = {
		processId = processId,
		startTimestamp = timestamp,
		type = purchaseType,
		undernameCount = constants.DEFAULT_UNDERNAME_COUNT,
		purchasePrice = totalRegistrationFee,
	}

	-- Register the leased or permabought name
	if purchaseType == "lease" then
		newRecord.endTimestamp = timestamp + constants.oneYearMs * years
	end
	-- Transfer tokens to the protocol balance
	token.transfer(ao.id, from, totalRegistrationFee)
	arns.addRecord(name, newRecord)
	return arns.getRecord(name)
end

function arns.submitAuctionBid()
	utils.reply("submitAuctionBid is not implemented yet")
end

function arns.addRecord(name, record)
	arns.records[name] = record
	if arns.getReservedName(record.name) then
		arns.reserved[name] = nil
	end
end

function arns.extendLease(from, name, years, currentTimestamp)
	local record = arns.getRecord(name)
	-- throw error if invalid
	arns.assertValidExtendLease(record, currentTimestamp, years)
	local baseRegistrionFee = arns.fees[#name]
	local totalExtensionFee = arns.calculateExtensionFee(baseRegistrionFee, years, demand.getDemandFactor())

	if token.getBalance(from) < totalExtensionFee then
		error("Insufficient balance")
	end
	-- Transfer tokens to the protocol balance
	token.transfer(ao.id, from, totalExtensionFee)
	arns.records[name].endTimestamp = record.endTimestamp + constants.oneYearMs * years
	return arns.records[name]
end

function arns.calculateExtensionFee(baseFee, years, demandFactor)
	local extensionFee = arns.calculateAnnualRenewalFee(baseFee, years)
	return demandFactor * extensionFee
end

function arns.increaseUndernameCount(from, name, qty, currentTimestamp)
	-- validate record can increase undernames
	local record = arns.getRecord(name)

	-- throws errors on invalid requests
	arns.assertValidIncreaseUndername(record, qty, currentTimestamp)

	local yearsRemaining = constants.PERMABUY_LEASE_FEE_LENGTH
	if record.type == "lease" then
		yearsRemaining = arns.calculateYearsBetweenTimestamps(currentTimestamp, record.endTimestamp)
	end

	local existingUndernames = record.undernameCount
	local baseRegistrionFee = arns.fees[#name]
	local additionalUndernameCost =
		arns.calculateUndernameCost(baseRegistrionFee, qty, record.type, yearsRemaining, demand.getDemandFactor())

	if additionalUndernameCost < 0 then
		error("Invalid undername cost")
	end

	if token.getBalance(from) < additionalUndernameCost then
		error("Insufficient balance")
	end

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

-- internal functions
function arns.calculateLeaseFee(baseFee, years, demandFactor)
	local annualRegistrionFee = arns.calculateAnnualRenewalFee(baseFee, years)
	local totalLeaseCost = baseFee + annualRegistrionFee
	return demandFactor * totalLeaseCost
end

function arns.calculateAnnualRenewalFee(baseFee, years)
	local nameAnnualRegistrationFee = baseFee * constants.ANNUAL_PERCENTAGE_FEE
	local totalAnnualRenewalCost = nameAnnualRegistrationFee * years
	return totalAnnualRenewalCost
end

function arns.calculatePermabuyFee(baseFee, demandFactor)
	local permabuyPrice = baseFee + arns.calculateAnnualRenewalFee(baseFee, constants.PERMABUY_LEASE_FEE_LENGTH)
	return demandFactor * permabuyPrice
end

function arns.calculateRegistrationFee(purchaseType, baseFee, years, demandFactor)
	if purchaseType == "lease" then
		return arns.calculateLeaseFee(baseFee, years, demandFactor)
	elseif purchaseType == "permabuy" then
		return arns.calculatePermabuyFee(baseFee, demandFactor)
	end
end

function arns.calculateUndernameCost(baseFee, increaseQty, registrationType, years, demandFactor)
	local undernamePercentageFee = 0
	if registrationType == "lease" then
		undernamePercentageFee = constants.UNDERNAME_LEASE_FEE_PERCENTAGE
	elseif registrationType == "permabuy" then
		undernamePercentageFee = constants.UNDERNAME_PERMABUY_FEE_PERCENTAGE
	end

	local totalFeeForQtyAndYears = baseFee * undernamePercentageFee * increaseQty * years
	return demandFactor * totalFeeForQtyAndYears
end

function arns.calculateYearsBetweenTimestamps(startTimestamp, endTimestamp)
	local yearsRemainingFloat = math.floor((endTimestamp - startTimestamp) / constants.oneYearMs)
	return yearsRemainingFloat
end

function arns.assertValidBuyRecord(name, years, purchaseType, processId)
	-- Validate the presence and type of the 'name' field
	if type(name) ~= "string" then
		error("Name is required and must be a string.")
	end

	local startsWithAlphanumeric = name:match("^%w")
	local endsWithAlphanumeric = name:match("%w$")
	local middleValid = name:match("^[%w-]+$")
	local validLength = #name >= 1 and #name <= 51

	if not (startsWithAlphanumeric and endsWithAlphanumeric and middleValid and validLength) then
		error("Name pattern is invalid.")
	end

	-- TODO: validate atomic tags

	if not utils.isValidBase64Url(processId) then
		error("processId pattern is invalid.")
	end

	-- If 'years' is present, validate it as an integer between 1 and 5
	if years then
		if type(years) ~= "number" or years % 1 ~= 0 or years < 1 or years > 5 then
			return error("Name can only be leased between 1 and 5 years")
		end
	end

	-- Validate 'PurchaseType' field if present, ensuring it is either 'lease' or 'permabuy'
	if purchaseType then
		if not (purchaseType == "lease" or purchaseType == "permabuy") then
			error("type pattern is invalid.")
		end
	end
end

function arns.assertValidExtendLease(record, currentTimestamp, years)
	if not record then
		error("Name is not registered")
	end

	if record.type == "permabuy" then
		error("Name is permabought and cannot be extended")
	end

	if record.endTimestamp and record.endTimestamp + constants.gracePeriodMs < currentTimestamp then
		error("Name is expired")
	end

	local maxAllowedYears = arns.getMaxAllowedYearsExtensionForRecord(record, currentTimestamp)
	if years > maxAllowedYears then
		error("Cannot extend lease beyond 5 years")
	end
end

function arns.getMaxAllowedYearsExtensionForRecord(record, currentTimestamp)
	if not record.endTimestamp then
		return 0
	end

	if currentTimestamp > record.endTimestamp and currentTimestamp < record.endTimestamp + constants.gracePeriodMs then
		return constants.maxLeaseLengthYears
	end

	-- TODO: should we put this as the ceiling? or should we allow people to extend as soon as it is purchased
	local yearsRemainingOnLease = math.ceil((record.endTimestamp - currentTimestamp) / constants.oneYearMs)

	-- a number between 0 and 5 (MAX_YEARS)
	return constants.maxLeaseLengthYears - yearsRemainingOnLease
end

function arns.assertValidIncreaseUndername(record, qty, currentTimestamp)
	if not record then
		error("Name is not registered")
	end

	if
		record.endTimestamp
		and record.endTimestamp < currentTimestamp
		and record.endTimestamp + constants.gracePeriodMs > currentTimestamp
	then
		error("Name must be extended before additional unernames can be purchased")
	end

	if record.endTimestamp and record.endTimestamp + constants.gracePeriodMs < currentTimestamp then
		error("Name is expired")
	end

	if qty < 1 or qty > 9990 then
		error("Qty is invalid")
	end

	-- the new total qty
	if record.undernameCount + qty > constants.MAX_ALLOWED_UNDERNAMES then
		error(constants.ARNS_MAX_UNDERNAME_MESSAGE)
	end

	return true
end
return arns
