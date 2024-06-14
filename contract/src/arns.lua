-- arns.lua
local utils = require("utils")
local constants = require("constants")
local balances = require("balances")
local demand = require("demand")
local arns = {}

NameRegistry = NameRegistry or {
	reserved = {},
	records = {},
	-- TODO: auctions
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

	local baseRegistrionFee = demand.getFees()[#name]

	local totalRegistrationFee =
		arns.calculateRegistrationFee(purchaseType, baseRegistrionFee, years, demand.getDemandFactor())

	if balances.getBalance(from) < totalRegistrationFee then
		error("Insufficient balance")
	end

	if arns.getRecord(name) and arns.getRecord(name).endTimestamp + constants.gracePeriodMs > timestamp then
		error("Name is already registered")
	end

	-- TODO: handle reserved name timestamps (they should be pruned, so not immediately necessary)
	if arns.getReservedName(name) and arns.getReservedName(name).target ~= from then
		error("Name is reserved")
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
	balances.transfer(ao.id, from, totalRegistrationFee)
	arns.addRecord(name, newRecord)
	demand.tallyNamePurchase(totalRegistrationFee)
	return arns.getRecord(name)
end

function arns.addRecord(name, record)
	NameRegistry.records[name] = record

	-- remove reserved name if it exists in reserved
	if arns.getReservedName(record.name) then
		NameRegistry.reserved[name] = nil
	end
end

function arns.extendLease(from, name, years, currentTimestamp)
	local record = arns.getRecord(name)
	-- throw error if invalid
	arns.assertValidExtendLease(record, currentTimestamp, years)
	local baseRegistrionFee = demand.getFees()[#name]
	local totalExtensionFee = arns.calculateExtensionFee(baseRegistrionFee, years, demand.getDemandFactor())

	if balances.getBalance(from) < totalExtensionFee then
		error("Insufficient balance")
	end

	-- modify the record with the new end timestamp
	arns.modifyRecordEndTimestamp(name, record.endTimestamp + constants.oneYearMs * years)

	-- Transfer tokens to the protocol balance
	balances.transfer(ao.id, from, totalExtensionFee)
	demand.tallyNamePurchase(totalExtensionFee)
	return arns.getRecord(name)
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

	local baseRegistrionFee = demand.getFees()[#name]
	local additionalUndernameCost =
		arns.calculateUndernameCost(baseRegistrionFee, qty, record.type, yearsRemaining, demand.getDemandFactor())

	if additionalUndernameCost < 0 then
		error("Invalid undername cost")
	end

	if balances.getBalance(from) < additionalUndernameCost then
		error("Insufficient balance")
	end

	-- update the record with the new undername count
	arns.modifyRecordUndernameCount(name, qty)

	-- Transfer tokens to the protocol balance
	balances.transfer(ao.id, from, additionalUndernameCost)
	demand.tallyNamePurchase(additionalUndernameCost)
	return arns.getRecord(name)
end

function arns.getRecord(name)
	local records = arns.getRecords()
	return records[name]
end

function arns.getActiveArNSNamesBetweenTimestamps(startTimestamp, endTimestamp)
	local records = arns.getRecords()
	local activeNames = {}
	for name, record in pairs(records) do
		if
			record.type == "permabuy"
			or (
				record.type == "lease"
				and record.endTimestamp
				and record.startTimestamp
				and record.startTimestamp <= startTimestamp
				and record.endTimestamp >= endTimestamp
			)
		then
			table.insert(activeNames, name)
		end
	end
	return activeNames
end

function arns.getRecords()
	local records = utils.deepCopy(NameRegistry.records)
	return records or {}
end

function arns.getReservedNames()
	local reserved = utils.deepCopy(NameRegistry.reserved)
	return reserved or {}
end

function arns.getReservedName(name)
	local reserved = arns.getReservedNames()
	return reserved[name]
end

function arns.modifyRecordUndernameCount(name, qty)
	local record = arns.getRecord(name)
	if not record then
		error("Name is not registered")
	end
	-- if qty brings it over the limit, throw error
	if record.undernameCount + qty > constants.MAX_ALLOWED_UNDERNAMES then
		error(constants.ARNS_MAX_UNDERNAME_MESSAGE)
	end

	NameRegistry.records[name].undernameCount = record.undernameCount + qty
end

function arns.modifyRecordEndTimestamp(name, newEndTimestamp)
	local record = arns.getRecord(name)
	if not record then
		error("Name is not registered")
	end

	-- if new end timestamp + existing timetamp is > 5 years throw error
	if newEndTimestamp > record.startTimestamp + constants.maxLeaseLengthYears * constants.oneYearMs then
		error("Cannot extend lease beyond 5 years")
	end

	NameRegistry.records[name].endTimestamp = newEndTimestamp
end

function arns.addReservedName(name, details)
	if arns.getReservedName(name) then
		error("Name is already reserved")
	end

	if arns.getRecord(name) then
		error("Name is already registered")
	end

	NameRegistry.reserved[name] = details
	return arns.getReservedName(name)
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
	-- assert name is valid pattern
	assert(type(name) == "string", "Name is required and must be a string.")
	assert(#name >= 1 and #name <= 51, "Name pattern is invalid.")
	assert(name:match("^%w") and name:match("%w$") and name:match("^[%w-]+$"), "Name pattern is invalid.")

	-- If 'years' is present, validate it as an integer between 1 and 5
	assert(
		years == nil or (type(years) == "number" and years % 1 == 0 and years >= 1 and years <= 5),
		"Years is invalid. Must be an integer between 1 and 5"
	)

	-- assert purchase type if present is lease or permabuy
	assert(purchaseType == nil or purchaseType == "lease" or purchaseType == "permabuy", "PurchaseType is invalid.")

	-- assert processId is valid pattern
	assert(type(processId) == "string", "ProcessId is required and must be a string.")
	assert(utils.isValidBase64Url(processId), "ProcessId pattern is invalid.")
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

function arns.removeRecord(name)
	NameRegistry.records[name] = nil
end

function arns.removeReservedName(name)
	NameRegistry.reserved[name] = nil
end

-- prune records that have expired
function arns.pruneRecords(currentTimestamp)
	-- identify any records that are leases and that have expired, account for a one week grace period in seconds
	for name, record in pairs(arns.getRecords()) do
		if record.type == "lease" and record.endTimestamp + constants.gracePeriodMs < currentTimestamp then
			arns.removeRecord(name)
		end
	end
end

-- identify any reserved names that have expired, account for a one week grace period in seconds
function arns.pruneReservedNames(currentTimestamp)
	local reserved = arns.getReservedNames()
	for name, details in pairs(reserved) do
		if details.endTimestamp and details.endTimestamp <= currentTimestamp then
			arns.removeReservedName(name)
		end
	end
end

return arns
