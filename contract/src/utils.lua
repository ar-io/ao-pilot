local constants = require("constants")
local base64 = require("base64")
local crypto = require("crypto.init")
local utils = {}

function utils.hasMatchingTag(tag, value)
	return Handlers.utils.hasMatchingTag(tag, value)
end

function utils.reply(msg)
	Handlers.utils.reply(msg)
end

--- Validates the fields of a 'buy record' message for compliance with expected formats and value ranges.
-- This function checks the following fields in the message:
-- 1. 'name' - Required and must be a string matching specific naming conventions.
-- 2. 'processId' - Optional, must match a predefined pattern (including a special case 'atomic' or a standard 43-character base64url string).
-- 3. 'years' - Optional, must be an integer between 1 and 5.
-- 4. 'type' - Optional, must be either 'lease' or 'permabuy'.
-- 5. 'auction' - Optional, must be a boolean value.
-- @param msg The message table containing the Tags field with all necessary data.
-- @return boolean, string First return value indicates whether the message is valid (true) or not (false),
-- and the second return value provides an error message in case of validation failure.
function utils.assertValidBuyRecord(name, years, purchaseType, auction, processId)
	-- Validate the presence and type of the 'name' field
	if type(name) ~= "string" then
		error("name is required and must be a string.")
	end

	-- Validate the character count 'name' field to ensure names 4 characters or below are excluded
	if string.len(name) <= 4 then
		error("1-4 character names are not allowed")
	end

	local startsWithAlphanumeric = name:match("^%w")
	local endsWithAlphanumeric = name:match("%w$")
	local middleValid = name:match("^[%w-]+$")
	local validLength = #name >= 5 and #name <= 51

	if not (startsWithAlphanumeric and endsWithAlphanumeric and middleValid and validLength) then
		error("name pattern is invalid.")
	end

	-- TODO: validate atomic tags

	if not utils.isValidBase64Url(processId) then
		error("processId pattern is invalid.")
	end

	-- If 'years' is present, validate it as an integer between 1 and 5
	if years then
		if type(years) ~= "number" or years % 1 ~= 0 or years < 1 or years > 5 then
			return error("years must be an integer between 1 and 5.")
		end
	end

	-- Validate 'PurchaseType' field if present, ensuring it is either 'lease' or 'permabuy'
	if purchaseType then
		if not (purchaseType == "lease" or purchaseType == "permabuy") then
			error("type pattern is invalid.")
		end

		-- Do not allow permabuying names 11 characters or below for this experimentation period
		if purchaseType == "permabuy" and string.len(name) <= 11 then
			error("cannot permabuy name 11 characters or below at this time")
		end
	end

	-- Validate the 'auction' field if present, ensuring it is a boolean value
	if auction then
		if type(auction) ~= "boolean" then
			error("auction must be a boolean.")
		end
	end
end

-- Then, check for a 43-character base64url pattern.
-- The pattern checks for a string of length 43 containing alphanumeric characters, hyphens, or underscores.
function utils.isValidBase64Url(url)
	local isValidBase64Url = #url == 43 and string.match(url, "^[%w-_]+$") ~= nil

	if not isValidBase64Url then
		error("processId pattern is invalid.")
	end
	return url
end

function utils.validateFQDN(fqdn)
	-- Check if the fqdn is not nil and not empty
	if not fqdn or fqdn == "" then
		error("FQDN is empty")
	end

	-- Split the fqdn into parts by dot and validate each part
	local parts = {}
	for part in fqdn:gmatch("[^%.]+") do
		table.insert(parts, part)
	end

	-- Validate each part of the domain
	for _, part in ipairs(parts) do
		-- Check that the part length is between 1 and 63 characters
		if #part < 1 or #part > 63 then
			error("Invalid fqdn format: each part must be between 1 and 63 characters")
		end
		-- Check that the part does not start or end with a hyphen
		if part:match("^-") or part:match("-$") then
			error("Invalid fqdn format: parts must not start or end with a hyphen")
		end
		-- Check that the part contains only alphanumeric characters and hyphen
		if not part:match("^[A-Za-z0-9-]+$") then
			error("Invalid fqdn format: parts must contain only alphanumeric characters or hyphen")
		end
	end

	-- Check if there is at least one top-level domain (TLD)
	if #parts < 2 then
		error("Invalid fqdn format: missing top-level domain")
	end

	return fqdn
end

function utils.validateUpdateGatewaySettings(settings, observerWallet)
	-- Validate 'fqdn' field
	if settings.fqdn and not utils.validateFQDN(settings.fqdn) then
		error("Invalid fqdn format")
	end

	-- Validate 'port' field
	if settings.port and (settings.port < 0 or settings.port > 65535) then
		error("Invalid port number")
	end

	-- Validate 'protocol' field
	if settings.protocol and not (settings.protocol == "https" or settings.protocol == "http") then
		error("Invalid protocol")
	end

	-- Validate 'properties' field
	if settings.properties and not utils.isValidBase64Url(settings.properties) then
		error("Invalid properties format")
	end

	-- Validate 'note' field
	if settings.note and #settings.note > 256 then
		error("Invalid note length")
	end

	-- Validate 'label' field
	if settings.label and #settings.label > 64 then
		error("Invalid label length")
	end

	-- Validate 'observerWallet' field
	if observerWallet and not utils.isValidBase64Url(observerWallet) then
		error("Invalid observerWallet format")
	end

	-- Validate 'autoStake' and 'allowDelegatedStaking' booleans
	if settings.autoStake ~= nil and type(settings.autoStake) ~= "boolean" then
		error("Invalid autoStake value")
	end
	if settings.allowDelegatedStaking ~= nil and type(settings.allowDelegatedStaking) ~= "boolean" then
		error("Invalid allowDelegatedStaking value")
	end

	-- Validate 'delegateRewardShareRatio' field
	if
		settings.delegateRewardShareRatio
		and (settings.delegateRewardShareRatio < 0 or settings.delegateRewardShareRatio > 100)
	then
		error("Invalid delegateRewardShareRatio value")
	end

	-- Validate 'minDelegatedStake' field
	if settings.minDelegatedStake and settings.minDelegatedStake < 100 then
		error("Invalid minDelegatedStake value")
	end

	return true
end

function utils.walletHasSufficientBalance(wallet, quantity)
	return Balances[wallet] ~= nil and Balances[wallet] >= quantity
end

function utils.calculateLeaseFee(baseFee, years, demandFactor)
	local annualRegistrionFee = utils.calculateAnnualRenewalFee(baseFee, years)
	local totalLeaseCost = baseFee + annualRegistrionFee
	return demandFactor * totalLeaseCost
end

function utils.calculateAnnualRenewalFee(baseFee, years)
	local nameAnnualRegistrationFee = baseFee * constants.ANNUAL_PERCENTAGE_FEE
	local totalAnnualRenewalCost = nameAnnualRegistrationFee * years
	return totalAnnualRenewalCost
end

function utils.calculatePermabuyFee(baseFee, demandFactor)
	local permabuyPrice = baseFee + utils.calculateAnnualRenewalFee(baseFee, constants.PERMABUY_LEASE_FEE_LENGTH)
	return demandFactor * permabuyPrice
end

function utils.calculateRegistrationFee(purchaseType, baseFee, years, demandFactor)
	if purchaseType == "lease" then
		return utils.calculateLeaseFee(baseFee, years, demandFactor)
	elseif purchaseType == "permabuy" then
		return utils.calculatePermabuyFee(baseFee, demandFactor)
	end
end

function utils.calculateUndernameCost(baseFee, increaseQty, registrationType, years, demandFactor)
	local undernamePercentageFee = 0
	if registrationType == "lease" then
		undernamePercentageFee = constants.UNDERNAME_LEASE_FEE_PERCENTAGE
	elseif registrationType == "permabuy" then
		undernamePercentageFee = constants.UNDERNAME_PERMABUY_FEE_PERCENTAGE
	end

	local totalFeeForQtyAndYears = baseFee * undernamePercentageFee * increaseQty * years
	return demandFactor * totalFeeForQtyAndYears
end

function utils.calculateExtensionFee(baseFee, years, demandFactor)
	local extensionFee = utils.calculateAnnualRenewalFee(baseFee, years)
	return demandFactor * extensionFee
end

function utils.isLeaseRecord(record)
	return record.type == "lease"
end

function utils.ensureMilliseconds(timestamp)
	-- Assuming any timestamp before 100000000000 is in seconds
	-- This is a heuristic approach since determining the exact unit of a timestamp can be ambiguous
	local threshold = 100000000000
	if timestamp < threshold then
		-- If the timestamp is below the threshold, it's likely in seconds, so convert to milliseconds
		return timestamp * 1000
	else
		-- If the timestamp is above the threshold, assume it's already in milliseconds
		return timestamp
	end
end

function utils.isNameInGracePeriod(record, currentTimestamp)
	if not record or not record.endTimestamp then
		return false
	end -- if it has no timestamp, it is a permabuy
	if (utils.ensureMilliseconds(record.endTimestamp) + constants.gracePeriodMs) < currentTimestamp then
		return false
	end
	return true
end

function utils.isActiveReservedName(caller, reservedName, currentTimestamp)
	if not reservedName then
		return false
	end

	local target = reservedName.target
	local endTimestamp = reservedName.endTimestamp
	local permanentlyReserved = not target and not endTimestamp

	if permanentlyReserved then
		return true
	end

	local isCallerTarget = caller ~= nil and target == caller
	local isActiveReservation = endTimestamp and endTimestamp > currentTimestamp

	-- If the caller is not the target, and it's still active - the name is considered reserved
	if not isCallerTarget and isActiveReservation then
		return true
	end
	return false
end

function utils.assertAllowedNameModification(record, currentTimestamp)
	if not record then
		error("Name is not registered")
	end

	if record.type == "permabuy" then
		return
	end
	-- TODO: all the other validations for one to be able to modify a record
end

function utils.isShortNameRestricted(name, currentTimestamp)
	return (
		#name < constants.MINIMUM_ALLOWED_NAME_LENGTH
		and currentTimestamp < constants.SHORT_NAME_RESERVATION_UNLOCK_TIMESTAMP
	)
end

function utils.isNameRequiredToBeAuction(name, type)
	return (type == "permabuy" and #name < 12)
end

function utils.assertAvailableRecord(caller, name, currentTimestamp, type, auction)
	local isActiveRecord = utils.isExistingActiveRecord(Records[name], currentTimestamp)
	local isReserved = utils.isActiveReservedName(caller, Reserved[name], currentTimestamp)
	local isShortName = utils.isShortNameRestricted(name, currentTimestamp)
	local isAuctionRequired = utils.isNameRequiredToBeAuction(name, type)
	if isActiveRecord then
		error(constants.ARNS_NON_EXPIRED_NAME_MESSAGE)
	end

	if Reserved[name] and Reserved[name].target == caller then
		-- if the caller is the target of the reserved name, they can buy it
		return true
	end

	if isReserved then
		error(constants.ARNS_NAME_RESERVED_MESSAGE)
	end

	if isShortName then
		error(constants.ARNS_INVALID_SHORT_NAME)
	end

	-- TODO: we may want to move this up if we want to force permabuys for short names on reserved names
	if isAuctionRequired and not auction then
		error(constants.ARNS_NAME_MUST_BE_AUCTIONED_MESSAGE)
	end

	return true
end

function utils.assertValidExtendLease(record, currentTimestamp, years)
	utils.assertAllowedNameModification(record, currentTimestamp)
	local maxAllowedYears = utils.getMaxAllowedYearsExtensionForRecord(record, currentTimestamp)
	if years > maxAllowedYears then
		error("Invalid number of years for record extension")
	end
end

function utils.getMaxAllowedYearsExtensionForRecord(record, currentTimestamp)
	if not record.endTimestamp then
		return 0
	end

	-- if expired return 0 because it cannot be extended and must be re-bought
	if currentTimestamp > (record.endTimestamp + constants.gracePeriodMs) then
		return 0
	end

	if utils.isNameInGracePeriod(record, currentTimestamp) then
		return constants.maxLeaseLengthYears
	end

	-- TODO: should we put this as the ceiling? or should we allow people to extend as soon as it is purchased
	local yearsRemainingOnLease = math.ceil(record.endTimestamp - currentTimestamp / constants.SECONDS_IN_A_YEAR)

	-- a number between 0 and 5 (MAX_YEARS)
	return constants.ARNS_LEASE_LENGTH_MAX_YEARS - yearsRemainingOnLease
end

-- This function is used to validate the increase of undernames for a record
-- It checks if the qty is within the allowed range and if the record exists
-- @param record The record to be validated
-- @param qty The quantity of undernames to be added
-- @param currentTimestamp The current timestamp
-- @return boolean, string The first return value indicates whether the increase is valid (true) or not (false),
function utils.assertValidIncreaseUndername(record, qty, currentTimestamp)
	utils.assertAllowedNameModification(record, currentTimestamp)

	if qty < 1 or qty > 9990 then
		error("Qty is invalid")
	end

	-- the new total qty
	if record.undernameCount + qty > constants.MAX_ALLOWED_UNDERNAMES then
		error(constants.ARNS_MAX_UNDERNAME_MESSAGE)
	end

	return true
end

function utils.calculateYearsBetweenTimestamps(startTimestamp, endTimestamp)
	local yearsRemainingFloat = math.floor((endTimestamp - startTimestamp) / constants.MS_IN_A_YEAR)
	return yearsRemainingFloat
end

function utils.isGatewayLeaving(gateway, currentTimestamp)
	return gateway.status == "leaving" and gateway.endTimestamp <= currentTimestamp
end

function utils.isGatewayEligibleToLeave(gateway, timestamp)
	if gateway == nil then
		return error("Gateway does not exist")
	end
	local isJoined = utils.isGatewayJoined(gateway, timestamp)
	return isJoined
end

function utils.isGatewayEligibleForDistribution(epochStartTimestamp, epochEndTimestamp, gateway)
	local didStartBeforeEpoch = gateway.startTimestamp <= epochStartTimestamp
	local didNotLeaveDuringEpoch = not utils.isGatewayLeaving(gateway, epochEndTimestamp)
	return didStartBeforeEpoch and didNotLeaveDuringEpoch
end

function utils.getEligibleGatewaysForEpoch(epochStartTimestamp, epochEndTimestamp)
	local eligibleGateways = {}
	for address, gateway in pairs(Gateways) do
		if utils.isGatewayEligibleForDistribution(epochStartTimestamp, epochEndTimestamp, gateway) then
			eligibleGateways[address] = gateway
		end
	end
	return eligibleGateways
end

function utils.getObserverWeightsForEpoch(epochStartTimestamp, eligbileGateways)
	local weightedObservers = {}
	local totalCompositeWeight = 0

	-- Iterate over gateways to calculate weights
	for address, gateway in pairs(eligbileGateways) do
		local totalStake = gateway.operatorStake + gateway.totalDelegatedStake -- 100 - no cap to this
		local stakeWeightRatio = totalStake / constants.MIN_OPERATOR_STAKE -- this is always greater than 1 as the minOperatorStake is always less than the stake
		-- the percentage of the epoch the gateway was joined for before this epoch, if the gateway starts in the future this will be 0
		local gatewayStartTimestamp = gateway.startTimestamp
		local totalTimeForGateway = epochStartTimestamp >= gatewayStartTimestamp
				and (epochStartTimestamp - gatewayStartTimestamp)
			or -1
		-- TODO: should we increment by one here or are observers that join at the epoch start not eligible to be selected as an observer

		local calculatedTenureWeightForGateway = totalTimeForGateway < 0 and 0
			or (
				totalTimeForGateway > 0 and totalTimeForGateway / constants.TENURE_WEIGHT_PERIOD
				or 1 / constants.TENURE_WEIGHT_PERIOD
			)
		local gatewayTenureWeight = math.min(calculatedTenureWeightForGateway, constants.MAX_TENURE_WEIGHT)

		local totalEpochsGatewayPassed = gateway.stats.passedEpochCount or 0
		local totalEpochsParticipatedIn = gateway.stats.totalEpochParticipationCount or 0
		local gatewayRewardRatioWeight = (1 + totalEpochsGatewayPassed) / (1 + totalEpochsParticipatedIn)

		local totalEpochsPrescribed = gateway.stats.totalEpochsPrescribedCount or 0
		local totalEpochsSubmitted = gateway.stats.submittedEpochCount or 0
		local observerRewardRatioWeight = (1 + totalEpochsSubmitted) / (1 + totalEpochsPrescribed)

		local compositeWeight = stakeWeightRatio
			* gatewayTenureWeight
			* gatewayRewardRatioWeight
			* observerRewardRatioWeight

		table.insert(weightedObservers, {
			gatewayAddress = address,
			observerAddress = gateway.observerWallet,
			stake = totalStake,
			startTimestamp = gateway.startTimestamp,
			stakeWeight = stakeWeightRatio,
			tenureWeight = gatewayTenureWeight,
			gatewayRewardRatioWeight = gatewayRewardRatioWeight,
			observerRewardRatioWeight = observerRewardRatioWeight,
			compositeWeight = compositeWeight,
			normalizedCompositeWeight = nil, -- set later once we have the total composite weight
		})

		totalCompositeWeight = totalCompositeWeight + compositeWeight
	end

	-- Calculate the normalized composite weight for each observer
	for _, weightedObserver in ipairs(weightedObservers) do
		if totalCompositeWeight > 0 then
			weightedObserver.normalizedCompositeWeight = weightedObserver.compositeWeight / totalCompositeWeight
		else
			weightedObserver.normalizedCompositeWeight = 0
		end
	end
	return weightedObservers
end

function utils.getEntropyHashForEpoch(hash)
	local decodedHash = base64.decode(hash)
	local hashStream = crypto.utils.stream.fromString(decodedHash)
	return crypto.digest.sha2_256(hashStream).asBytes()
end

function utils.isGatewayJoined(gateway, currentTimestamp)
	return gateway.status == "joined" and gateway.startTimestamp <= currentTimestamp
end

return utils
