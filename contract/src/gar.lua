-- gar.lua
local crypto = require("crypto.init")
local utils = require("utils")
local constants = require("constants")
local token = Token or require("token")
local base64 = require("base64")
local gar = {
	gateways = {},
	observations = {},
	epoch = {
		startTimestamp = 0,
		endTimestamp = 0,
		epochZeroStartTimestamp = 0,
		epochDistributionTimestamp = 0,
		epochPeriod = 0,
	},
	distributions = {},
	prescribedObservers = {},
	settings = {
		observers = {
			maxObserversPerEpoch = 50,
			epochTimeLength = 24 * 60 * 60 * 1000, -- One day of miliseconds
			epochZeroStartTimestamp = 0,
			epochDistributionDelay = 30 * 60 * 1000, -- 30 minutes of miliseconds
			tenureWeightDays = 180,
			tenureWeightPeriod = 180 * 24 * 60 * 60 * 1000,
			maxTenureWeight = 4,
		},
		-- TODO: move this to a nested object for gateways
		minDelegatedStake = 50 * 1000000, -- 50 IO
		minOperatorStake = 10000 * 1000000, -- 10,000 IO
		gatewayLeaveLength = 90 * 24 * 60 * 60 * 1000, -- 90 days
		maxLockLength = 3 * 365 * 24 * 60 * 60 * 1000, -- 3 years
		minLockLength = 24 * 60 * 60 * 1000, -- 1 day
		operatorStakeWithdrawLength = 30 * 24 * 60 * 60 * 1000, -- 30 days
		delegatedStakeWithdrawLength = 30 * 24 * 60 * 60 * 1000, -- 30 days
		maxDelegates = 10000,
	},
}

local initialStats = {
	prescribedEpochCount = 0,
	observeredEpochCount = 0,
	totalEpochParticipationCount = 0,
	passedEpochCount = 0,
	failedEpochCount = 0,
	failedConsecutiveEpochs = 0,
	passedConsecutiveEpochs = 0,
}

function gar.joinNetwork(from, stake, settings, observerWallet, timeStamp)
	gar.assertValidGatewayParameters(from, stake, settings, observerWallet, timeStamp)

	if gar.getGateway(from) then
		error("Gateway already exists")
	end

	if token.getBalance(from) < stake then
		error("Insufficient balance")
	end

	local newGateway = {
		operatorStake = stake,
		totalDelegatedStake = 0,
		vaults = {},
		delegates = {},
		startTimestamp = timeStamp,
		stats = initialStats,
		settings = {
			allowDelegatedStaking = settings.allowDelegatedStaking or false,
			delegateRewardShareRatio = settings.delegateRewardShareRatio or 0,
			autoStake = settings.autoStake or false,
			propteris = settings.propteries,
			minDelegatedStake = settings.minDelegatedStake,
			label = settings.label,
			fqdn = settings.fqdn,
			protocol = settings.protocol,
			port = settings.port,
		},
		status = "joined",
		observerWallet = observerWallet or from,
	}

	gar.gateways[from] = newGateway
	return gar.getGateway(from)
end

function gar.getPrescribedObserversForEpoch(epochStartTimestamp, epochEndTimestamp, hashchain)
	local eligibleGateways = gar.getEligibleGatewaysForEpoch(epochStartTimestamp, epochEndTimestamp)
	local weightedObservers = gar.getObserverWeightsForEpoch(epochStartTimestamp, eligibleGateways)
	-- Filter out any observers that could have a normalized composite weight of 0
	local filteredObservers = {}
	-- use ipairs as weightedObservers in array
	for _, observer in ipairs(weightedObservers) do
		if observer.normalizedCompositeWeight > 0 then
			table.insert(filteredObservers, observer)
		end
	end
	if #filteredObservers <= gar.settings.observers.maxObserversPerEpoch then
		return filteredObservers
	end

	local timestampEntropyHash = gar.getEntropyHashForEpoch(hashchain)
	local prescribedObserversAddresses = {}
	local hash = timestampEntropyHash
	while #prescribedObserversAddresses < gar.settings.observers.maxObserversPerEpoch do
		local random = 0 -- TODO: use the hash as a seed to get a random number between 0 and 1
		local cumulativeNormalizedCompositeWeight = 0
		-- use ipairs as filtered observers is an array
		for _, observer in ipairs(filteredObservers) do
			local alreadyPrescribed = utils.findInArray(prescribedObserversAddresses, function(address)
				return address == observer.gatewayAddress
			end)

			-- add only if observer has not already been prescribed
			if not alreadyPrescribed then
				-- add the observers normalized composite weight to the cumulative weight
				cumulativeNormalizedCompositeWeight = cumulativeNormalizedCompositeWeight
					+ observer.normalizedCompositeWeight
				-- if the random value is less than the cumulative weight, we have found our observer
				if random <= cumulativeNormalizedCompositeWeight then
					table.insert(prescribedObserversAddresses, observer.gatewayAddress)
					break
				end
			end
		end
		-- Compute the next hash for the next iteration
		local newHash = crypto.utils.stream.fromArray(hash)
		hash = crypto.digest.sha2_256(newHash).asBytes()
	end
	local prescribedObservers = {}
	for _, address in ipairs(prescribedObserversAddresses) do
		local index = utils.findInArray(filteredObservers, function(observer)
			return observer.gatewayAddress == address
		end)
		table.insert(prescribedObservers, filteredObservers[index])
		table.sort(prescribedObservers, function(a, b)
			return a.normalizedCompositeWeight > b.normalizedCompositeWeight
		end)
	end

	-- sort them in place
	table.sort(prescribedObservers, function(a, b)
		return a.normalizedCompositeWeight > b.normalizedCompositeWeight -- sort by descending weight
	end)

	return prescribedObservers
end

function gar.leaveNetwork(from, currentTimestamp, msgId)
	if not gar.getGateway(from) then
		error("Gateway does not exist in the network")
	end

	local gateway = gar.getGateway(from)

	if not gar.isGatewayEligibleToLeave(gateway, currentTimestamp) then
		error("The gateway is not eligible to leave the network.")
	end

	local gatewayEndHeight = currentTimestamp + gar.settings.gatewayLeaveLength
	local gatewayStakeWithdrawHeight = currentTimestamp + gar.settings.operatorStakeWithdrawLength
	local delegateEndHeight = currentTimestamp + gar.settings.delegatedStakeWithdrawLength

	-- Add minimum staked tokens to a vault that unlocks after the gateway completely leaves the network
	gateway.vaults[from] = {
		balance = gar.settings.minOperatorStake,
		startTimestamp = currentTimestamp,
		endTimestamp = gatewayEndHeight,
	}

	gateway.operatorStake = gateway.operatorStake - gar.settings.minOperatorStake

	-- Add remainder to another vault
	if gateway.operatorStake > 0 then
		gateway.vaults[msgId] = {
			balance = gateway.operatorStake,
			startTimestamp = currentTimestamp,
			endTimestamp = gatewayStakeWithdrawHeight,
		}
	end

	gateway.status = "leaving"
	gateway.endTimestamp = gatewayEndHeight
	gateway.operatorStake = 0

	-- Add tokens from each delegate to a vault that unlocks after the delegate withdrawal period ends
	for address, delegate in pairs(gateway.delegates) do
		-- Assuming SmartWeave and interactionHeight are previously defined in your Lua environment
		gateway.delegates[address].vaults[msgId] = {
			balance = delegate.delegatedStake,
			startTimestamp = currentTimestamp,
			endTimestamp = delegateEndHeight,
		}

		-- Reduce gateway stake and set this delegate stake to 0
		gateway.totalDelegatedStake = gateway.totalDelegatedStake - delegate.delegatedStake
		gateway.delegates[address].delegatedStake = 0
	end

	-- update global state
	gar.gateways[from] = gateway
	return gateway
end

function gar.increaseOperatorStake(from, qty)
	assert(type(qty) == "number", "Quantity is required and must be a number!")
	assert(qty > 0, "Quantity must be greater than 0")

	if gar.getGateway(from) == nil then
		error("Gateway does not exist")
	end

	if gar.getGateway(from).status == "leaving" then
		error("Gateway is leaving the network and cannot accept additional stake.")
	end

	if token.getBalance(from) < qty then
		error("Insufficient balance")
	end

	token.reduceBalance(from, qty)
	gar.gateways[from].operatorStake = gar.getGateway(from).operatorStake + qty
	return gar.getGateway(from)
end

function gar.decreaseOperatorStake(from, qty, currentTimestamp, msgId)
	assert(type(qty) == "number", "Quantity is required and must be a number!")
	assert(qty > 0, "Quantity must be greater than 0")

	if gar.getGateway(from) == nil then
		error("Gateway does not exist")
	end

	if gar.getGateway(from).status == "leaving" then
		error("Gateway is leaving the network and withdraw more stake.")
	end

	local maxWithdraw = gar.getGateway(from).operatorStake - gar.settings.minOperatorStake

	if qty > maxWithdraw then
		return error(
			"Resulting stake is not enough maintain the minimum operator stake of "
				.. gar.settings.minOperatorStake
				.. " IO"
		)
	end

	gar.gateways[from].operatorStake = gar.getGateway(from).operatorStake - qty
	gar.gateways[from].vaults[msgId] = {
		balance = qty,
		startTimestamp = currentTimestamp,
		endTimestamp = currentTimestamp + gar.settings.operatorStakeWithdrawLength,
	}
	return gar.getGateway(from)
end

function gar.updateGatewaySettings(from, updatedSettings, observerWallet, currentTimestamp, msgId)
	if not gar.getGateway(from) then
		error("Gateway does not exist")
	end

	local gateway = gar.getGateway(from)

	gar.assertValidGatewayParameters(from, gateway.operatorStake, updatedSettings, observerWallet, currentTimestamp)

	if updatedSettings.minDelegatedStake and updatedSettings.minDelegatedStake < gar.settings.minDelegatedStake then
		error("The minimum delegated stake must be at least " .. gar.settings.minDelegatedStake .. " IO")
	end

	for gatewayAddress, gateway in pairs(gar.gateways) do
		if gateway.observerWallet == observerWallet and gatewayAddress ~= from then
			error("Invalid observer wallet. The provided observer wallet is correlated with another gateway.")
		end
	end

	-- vault all delegated stakes if it is disabled, we'll return stake at the proper end heights of the vault
	if not updatedSettings.allowDelegatedStaking and next(gateway.delegates) ~= nil then
		-- Add tokens from each delegate to a vault that unlocks after the delegate withdrawal period ends
		local delegateEndHeight = currentTimestamp + gar.settings.delegatedStakeWithdrawLength

		for address, delegate in pairs(gateway.delegates) do
			if not gateway.delegates[address].vaults then
				gateway.delegates[address].vaults = {}
			end

			local newDelegateVault = {
				balance = delegate.delegatedStake,
				startTimestamp = currentTimestamp,
				endTimestamp = delegateEndHeight,
			}
			gateway.delegates[address].vaults[msgId] = newDelegateVault
			-- reduce gateway stake and set this delegate stake to 0
			gateway.totalDelegatedStake = gateway.totalDelegatedStake - delegate.delegatedStake
			gateway.delegates[address].delegatedStake = 0
		end
	end

	-- if allowDelegateStaking is currently false, and you want to set it to true - you have to wait until all the vaults have been returned
	if
		updatedSettings.allowDelegatedStaking == true
		and gateway.settings.allowDelegatedStaking == false
		and next(gateway.delegates) ~= nil
	then -- checks if the delegates table is not empty
		error("You cannot enable delegated staking until all delegated stakes have been withdrawn.")
	end

	gateway.settings = updatedSettings
	if observerWallet then
		gateway.observerWallet = observerWallet
	end
	return gar.getGateway(from)
end

function gar.getGateway(target)
	return gar.gateways[target]
end

function gar.getGateways()
	return gar.gateways
end

function gar.delegateStake(from, target, qty, currentTimestamp)
	assert(type(qty) == "number", "Quantity is required and must be a number!")
	assert(qty > 0, "Quantity must be greater than 0")
	if gar.gateways[target] == nil then
		error("Gateway does not exist")
	end

	if token.getBalance(from) < qty then
		error("Insufficient balance")
	end

	if gar.gateways[target].status == "leaving" then
		error("This Gateway is in the process of leaving the network and cannot have more stake delegated to it.")
	end

	-- TODO: when allowedDelegates is supported, check if it's in the array of allowed delegates
	if not gar.gateways[target].settings.allowDelegatedStaking then
		error(
			"This Gateway does not allow delegated staking. Only allowed delegates can delegate stake to this Gateway."
		)
	end

	local count = 0
	for _ in pairs(gar.gateways[target].delegates) do
		count = count + 1
	end

	if count > gar.settings.maxDelegates then
		error("This Gateway has reached its maximum amount of delegated stakers.")
	end

	-- Assuming `gateway` is a table and `fromAddress` is defined
	local existingDelegate = gar.gateways[target].delegates[from]
	local minimumStakeForGatewayAndDelegate
	if existingDelegate and existingDelegate.delegatedStake ~= 0 then
		-- It already has a stake that is not zero
		minimumStakeForGatewayAndDelegate = 1 -- Delegate must provide at least one additional IO
	else
		-- Consider if the operator increases the minimum amount after you've already staked
		minimumStakeForGatewayAndDelegate = gar.gateways[target].settings.minDelegatedStake
	end
	if qty < minimumStakeForGatewayAndDelegate then
		error("Quantity must be greater than the minimum delegated stake amount.")
	end

	-- Decrement the user's balance
	token.reduceBalance(from, qty)
	gar.gateways[target].totalDelegatedStake = gar.gateways[target].totalDelegatedStake + qty
	-- If this delegate has staked before, update its amount, if not, create a new delegated staker
	if existingDelegate == nil then
		-- create the new delegate stake
		gar.gateways[target].delegates[from] = {
			delegatedStake = qty,
			startTimestamp = currentTimestamp,
			vaults = {},
		}
	else
		-- increment the existing delegate's stake
		gar.gateways[target].delegates[from].delegatedStake = gar.gateways[target].delegates[from].delegatedStake + qty
	end
	return gar.gateways[target]
end

function gar.decreaseDelegateStake(gatewayAddress, delegator, qty, currentTimestamp, messageId)
	assert(type(qty) == "number", "Quantity is required and must be a number!")
	assert(qty > 0, "Quantity must be greater than 0")

	if not gar.getGateway(gatewayAddress) then
		error("Gateway does not exist")
	end
	local gateway = gar.getGateway(gatewayAddress)
	if gateway.status == "leaving" then
		error("Gateway is leaving the network and withdraw more stake.")
	end

	if gateway.delegates[delegator] == nil then
		error("This delegate is not staked at this gateway.")
	end

	local existingStake = gateway.delegates[delegator].delegatedStake
	local requiredMinimumStake = gateway.settings.minDelegatedStake
	local maxAllowedToWithdraw = existingStake - requiredMinimumStake
	if maxAllowedToWithdraw < qty and qty ~= existingStake then
		error("Remaining delegated stake must be greater than the minimum delegated stake amount.")
	end

	-- Withdraw the delegate's stake

	local newDelegateVault = {
		balance = qty,
		startTimestamp = currentTimestamp,
		endTimestamp = currentTimestamp + gar.settings.delegatedStakeWithdrawLength,
	}

	-- Lock the qty in a vault to be unlocked after withdrawal period and decrease the gateway's total delegated stake
	gar.gateways[gatewayAddress].delegates[delegator].vaults[messageId] = newDelegateVault
	gar.gateways[gatewayAddress].delegates[delegator].delegatedStake = gar.gateways[gatewayAddress].delegates[delegator].delegatedStake
		- qty
	gar.gateways[gatewayAddress].totalDelegatedStake = gar.gateways[gatewayAddress].totalDelegatedStake - qty
	return gar.getGateway(gatewayAddress)
end

function gar.saveObservations(from, observerReportTxId, failedGateways, currentTimestamp)
	local epochStartTimestamp, epochEndTimestamp, epochDistributionTimestamp, epochIndexForCurrentTimestamp =
		gar.getEpochDataForTimestamp(currentTimestamp)

	-- avoid observations before the previous epoch distribution has occurred, as distributions affect weights of the current epoch
	if currentTimestamp < epochStartTimestamp + constants.EPOCH_DISTRIBUTION_DELAY then
		error(
			"Observations for the current epoch cannot be submitted before block height: "
				.. epochStartTimestamp + constants.EPOCH_DISTRIBUTION_DELAY
		)
	end

	local prescribedObservers = gar.prescribedObservers[epochIndexForCurrentTimestamp] or {}
	local observer -- This will hold the matching observer or remain nil if no match is found
	for _, prescribedObserver in pairs(prescribedObservers) do
		if prescribedObserver.observerAddress == from then
			observer = prescribedObserver
			break -- Stop the loop once a matching observer is found
		end
	end

	if observer == nil then
		error("Invalid caller. Caller is not eligible to submit observation reports for this epoch.")
	end

	local observingGateway = gar.gateways[observer.gatewayAddress]

	if observingGateway == nil then
		error("The associated gateway does not exist in the registry.")
	end

	-- check if this is the first report filed in this epoch (TODO: use start or end?)
	if gar.observations[epochIndexForCurrentTimestamp] == nil then
		gar.observations[epochIndexForCurrentTimestamp] = {
			failureSummaries = {},
			reports = {},
		}
	end

	for _, address in pairs(failedGateways) do
		local failedGateway = gar.gateways[address]

		-- Validate the gateway is in the gar or is leaving
		if
			failedGateway and failedGateway.start > epochStartTimestamp
			or failedGateway.status == constants.NETWORK_JOIN_STATUS
		then
			-- Get the existing set of failed gateways for this observer
			local existingObservers = gar.observations[epochIndexForCurrentTimestamp].failureSummaries[address] or {}

			-- Simulate Set behavior using tables
			local updatedObserversForFailedGateway = {}
			for _, observer in pairs(existingObservers) do
				updatedObserversForFailedGateway[observer] = true
			end

			-- Add new observation
			updatedObserversForFailedGateway[observingGateway.observerWallet] = true

			-- Update the list of observers that mark the gateway as failed
			-- Convert set back to list
			local observersList = {}
			for observer, _ in pairs(updatedObserversForFailedGateway) do
				table.insert(observersList, observer)
			end
			gar.observations[epochIndexForCurrentTimestamp].failureSummaries[address] = observersList
		end
	end

	gar.observations[epochIndexForCurrentTimestamp].reports[observingGateway.observerWallet] = observerReportTxId
	return true
end

function gar.getEpochDataForTimestamp(currentTimestamp)
	local epochIndexForCurrentTimestamp =
		math.floor(math.max(0, (currentTimestamp - constants.epochZeroStartTimestamp) / constants.epochTimeLength))

	local epochStartTimestamp = constants.epochZeroStartTimestamp
		+ constants.epochTimeLength * epochIndexForCurrentTimestamp
	local epochEndTimestamp = epochStartTimestamp + constants.epochTimeLength
	local epochDistributionTimestamp = epochEndTimestamp + constants.EPOCH_DISTRIBUTION_DELAY
	return epochStartTimestamp, epochEndTimestamp, epochDistributionTimestamp, epochIndexForCurrentTimestamp
end

function gar.getPrescribedObservers(currentTimestamp)
	local epochStartTimestamp, epochEndTimestamp, epochDistributionTimestamp, epochIndexForCurrentTimestamp =
		gar.getEpochDataForTimestamp(currentTimestamp)

	local existingOrComputedObservers = gar.prescribedObservers[epochIndexForCurrentTimestamp] or {}
	return existingOrComputedObservers
end
function gar.getEpoch(timeStamp, currentTimestamp)
	local requestedTimestamp = timeStamp or currentTimestamp
	if requestedTimestamp == nil or requestedTimestamp <= 0 then
		return error("Invalid timestamp")
	end

	local epochStartTimestamp, epochEndTimestamp, epochDistributionTimestamp, epochIndexForCurrentTimestamp =
		gar.getEpochDataForTimestamp(currentTimestamp)

	local result = {
		epochStartTimestamp,
		epochEndTimestamp,
		Distributions.epochZeroStartTimestamp,
		epochDistributionTimestamp,
		epochIndexForCurrentTimestamp,
		constants.epochTimeLength,
	}
	return result
end

function gar.isGatewayLeaving(gateway, currentTimestamp)
	return gateway.status == "leaving" and gateway.endTimestamp <= currentTimestamp
end

function gar.isGatewayEligibleToLeave(gateway, timestamp)
	if gateway == nil then
		return error("Gateway does not exist")
	end
	local isJoined = gar.isGatewayJoined(gateway, timestamp)
	return isJoined
end

function gar.isGatewayEligibleForDistribution(epochStartTimestamp, epochEndTimestamp, gateway)
	local didStartBeforeEpoch = gateway.startTimestamp <= epochStartTimestamp
	local didNotLeaveDuringEpoch = not gar.isGatewayLeaving(gateway, epochEndTimestamp)
	return didStartBeforeEpoch and didNotLeaveDuringEpoch
end

function gar.getEligibleGatewaysForEpoch(epochStartTimestamp, epochEndTimestamp)
	local eligibleGateways = {}
	for address, gateway in pairs(gar.gateways) do
		if gar.isGatewayEligibleForDistribution(epochStartTimestamp, epochEndTimestamp, gateway) then
			eligibleGateways[address] = gar.getGateway(address)
		end
	end
	return eligibleGateways
end

function gar.getObserverWeightsForEpoch(epochStartTimestamp, eligbileGateways)
	local weightedObservers = {}
	local totalCompositeWeight = 0

	-- Iterate over gateways to calculate weights
	for address, gateway in pairs(eligbileGateways) do
		local totalStake = gateway.operatorStake + gateway.totalDelegatedStake -- 100 - no cap to this
		local stakeWeightRatio = totalStake / gar.settings.minOperatorStake -- this is always greater than 1 as the minOperatorStake is always less than the stake
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
	for _, weightedObserver in pairs(weightedObservers) do
		if totalCompositeWeight > 0 then
			weightedObserver.normalizedCompositeWeight = weightedObserver.compositeWeight / totalCompositeWeight
		else
			weightedObserver.normalizedCompositeWeight = 0
		end
	end
	return weightedObservers
end

function gar.getEntropyHashForEpoch(hash)
	local decodedHash = base64.decode(hash)
	local hashStream = crypto.utils.stream.fromString(decodedHash)
	return crypto.digest.sha2_256(hashStream).asBytes()
end

function gar.isGatewayJoined(gateway, currentTimestamp)
	return gateway.status == "joined" and gateway.startTimestamp <= currentTimestamp
end

function gar.getObservations()
	return gar.observations
end

function gar.getDistributions()
	return gar.distributions
end

function gar.assertValidGatewayParameters(from, stake, settings, observerWallet, timeStamp)
	assert(type(from) == "string", "from is required and must be a string!")
	assert(type(stake) == "number", "stake is required and must be a number!")
	assert(type(settings) == "table", "settings is required and must be a table!")
	assert(type(observerWallet) == "string", "observerWallet is required and must be a string!")
	assert(type(timeStamp) == "number", "timeStamp is required and must be a number!")
	assert(type(settings.allowDelegatedStaking) == "boolean", "allowDelegatedStaking must be a boolean")
	assert(type(settings.minDelegatedStake) == "number", "minDelegatedStake must be a number")
	assert(type(settings.label) == "string", "label is required and must be a string")
	assert(type(settings.fqdn) == "string", "fqdn is required and must be a string")
	assert(type(settings.protocol) == "string", "protocol is required and must be a string")
	assert(type(settings.port) == "number", "port is required and must be a number")
	if settings.delegateRewardShareRatio ~= nil then
		assert(type(settings.delegateRewardShareRatio) == "number", "delegateRewardShareRatio must be a number")
	end
	if settings.autoStake ~= nil then
		assert(type(settings.autoStake) == "boolean", "autoStake must be a boolean")
	end
	if settings.properties ~= nil then
		assert(type(settings.properties) == "string", "properties must be a table")
	end
	if settings.minDelegatedStake ~= nil then
		assert(type(settings.minDelegatedStake) == "number", "minDelegatedStake must be a number")
	end
end

return gar
