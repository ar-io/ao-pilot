-- gar.lua
local crypto = require("crypto.init")
local utils = require("utils")
local constants = require("constants")
local token = Token or require("token")
local base64 = require("base64")
local gar = {
	gateways = {},
	observations = {},
	epochs = {},
	distributions = {},
	prescribedObservers = {},
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
	if from == nil or settings == nil or stake == nil or timeStamp == nil then
		error("from, settings, stake and timestamp are required")
	end

	if gar.getGateway(from) then
		return error("Gateway already exists in the network")
	end

	if stake < constants.MIN_OPERATOR_STAKE then
		error("Caller did not provide enough tokens to stake")
	end

	if token.getBalance(from) < constants.MIN_OPERATOR_STAKE then
		error("Caller does not have enough tokens to stake")
	end

	-- TODO: check the params meet the requirements

	local newGateway = {
		operatorStake = stake,
		totalDelegatedStake = 0,
		vaults = {},
		delegates = {},
		startTimestamp = timeStamp,
		stats = initialStats,
		settings = settings,
		status = "joined",
		observerWallet = observerWallet,
	}

	gar.gateways[from] = newGateway
	return newGateway
end

function gar.leaveNetwork(from, currentTimestamp, msgId)
	if not gar.getGateway(from) then
		error("Gateway does not exist in the network")
	end

	local gateway = gar.getGateway(from)

	if not gar.isGatewayEligibleToLeave(gateway, currentTimestamp) then
		error("The gateway is not eligible to leave the network.")
	end

	local gatewayEndHeight = currentTimestamp + constants.GATEWAY_REGISTRY_SETTINGS.gatewayLeaveLength
	local gatewayStakeWithdrawHeight = currentTimestamp
		+ constants.GATEWAY_REGISTRY_SETTINGS.operatorStakeWithdrawLength
	local delegateEndHeight = currentTimestamp + constants.GATEWAY_REGISTRY_SETTINGS.delegatedStakeWithdrawLength

	-- Add minimum staked tokens to a vault that unlocks after the gateway completely leaves the network
	gateway.vaults[from] = {
		balance = constants.MIN_OPERATOR_STAKE,
		startTimestamp = currentTimestamp,
		endTimestamp = gatewayEndHeight,
	}

	gateway.operatorStake = gateway.operatorStake - constants.MIN_OPERATOR_STAKE

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
		error("Insufficient funds!")
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

	local maxWithdraw = gar.getGateway(from).operatorStake - constants.MIN_OPERATOR_STAKE

	if qty > maxWithdraw then
		return error(
			"Resulting stake is not enough maintain the minimum operator stake of "
				.. constants.MIN_OPERATOR_STAKE
				.. " IO"
		)
	end

	gar.gateways[from].operatorStake = gar.getGateway(from).operatorStake - qty
	gar.gateways[from].vaults[msgId] = {
		balance = qty,
		startTimestamp = currentTimestamp,
		endTimestamp = currentTimestamp + constants.GATEWAY_REGISTRY_SETTINGS.operatorStakeWithdrawLength,
	}
	return gar.getGateway(from)
end

function gar.updateGatewaySettings(from, updatedSettings, observerWallet, currentTimestamp, msgId)
	if gar.getGateway(from) == nil then
		error("Gateway does not exist")
	end

	local validSettings, err = utils.validateUpdateGatewaySettings(updatedSettings, observerWallet)
	if not validSettings then
		error(err)
	end

	if updatedSettings.minDelegatedStake and updatedSettings.minDelegatedStake < constants.MIN_DELEGATED_STAKE then
		error("The minimum delegated stake must be at least " .. constants.MIN_DELEGATED_STAKE .. " IO")
	end

	for gatewayAddress, gateway in pairs(gar.gateways) do
		if gateway.observerWallet == observerWallet and gatewayAddress ~= from then
			error("Invalid observer wallet. The provided observer wallet is correlated with another gateway.")
		end
	end

	-- vault all delegated stakes if it is disabled, we'll return stake at the proper end heights of the vault
	if not updatedSettings.allowDelegatedStaking and next(gar.getGateway(from).delegates) ~= nil then
		-- Add tokens from each delegate to a vault that unlocks after the delegate withdrawal period ends
		local delegateEndHeight = currentTimestamp + constants.GATEWAY_REGISTRY_SETTINGS.delegatedStakeWithdrawLength

		for address, delegate in pairs(gar.getGateway(from).delegates) do
			if not gar.getGateway(from).delegates[address].vaults then
				gar.getGateway(from).delegates[address].vaults = {}
			end
			gar.getGateway(from).delegates[address].vaults[msgId] = {
				balance = delegate.delegatedStake,
				startTimestamp = currentTimestamp,
				endTimestamp = delegateEndHeight,
			}

			-- reduce gateway stake and set this delegate stake to 0
			gar.getGateway(from).totalDelegatedStake = gar.getGateway(from).totalDelegatedStake
				- delegate.delegatedStake
			gar.getGateway(from).delegates[address].delegatedStake = 0
		end
	end

	-- if allowDelegateStaking is currently false, and you want to set it to true - you have to wait until all the vaults have been returned
	if
		updatedSettings.allowDelegatedStaking == true
		and gar.getGateway(from).settings.allowDelegatedStaking == false
		and next(gar.getGateway(from).delegates) ~= nil
	then -- checks if the delegates table is not empty
		error("You cannot enable delegated staking until all delegated stakes have been withdrawn.")
	end

	gar.getGateway(from).settings = updatedSettings
	if observerWallet then
		gar.getGateway(from).observerWallet = observerWallet
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
		error("Insufficient funds!")
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

	if count > constants.MAX_DELEGATES then
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

function gar.decreaseDelegateStake(from, target, qty, currentTimestamp, msgId)
	assert(type(qty) == "number", "Quantity is required and must be a number!")
	assert(qty > 0, "Quantity must be greater than 0")

	if gar.getGateway(from) == nil then
		error("Gateway does not exist")
	end

	if gar.getGateway(from).status == "leaving" then
		error("Gateway is leaving the network and withdraw more stake.")
	end
	if gar.gateways[target].delegates[from] == nil then
		error("This delegate is not staked at this gateway.")
	end

	local existingStake = gar.gateways[target].delegates[from].delegatedStake
	local requiredMinimumStake = gar.gateways[target].settings.minDelegatedStake
	local maxAllowedToWithdraw = existingStake - requiredMinimumStake
	if maxAllowedToWithdraw < qty and qty ~= existingStake then
		error("Remaining delegated stake must be greater than the minimum delegated stake amount.")
	end

	-- Withdraw the delegate's stake
	gar.gateways[target].delegates[from].delegatedStake = gar.gateways[target].delegates[from].delegatedStake - qty

	-- Lock the qty in a vault to be unlocked after withdrawal period
	gar.gateways[target].delegates[from].vaults[msgId] = {
		balance = qty,
		startTimestamp = currentTimestamp,
		endTimestamp = currentTimestamp + constants.GATEWAY_REGISTRY_SETTINGS.delegatedStakeWithdrawLength,
	}

	-- Decrease the gateway's total delegated stake.
	gar.gateways[target].totalDelegatedStake = gar.gateways[target].totalDelegatedStake - qty
	return gar.gateways[target]
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
	for _, prescribedObserver in ipairs(prescribedObservers) do
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

	for _, address in ipairs(failedGateways) do
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
			for _, observer in ipairs(existingObservers) do
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

function gar.getPrescribedObserversForEpoch(epochStartTimestamp, epochEndTimestamp, hashchain)
	local eligibleGateways = gar.getEligibleGatewaysForEpoch(epochStartTimestamp, epochEndTimestamp)
	local weightedObservers = gar.getObserverWeightsForEpoch(epochStartTimestamp, eligibleGateways)
	-- Filter out any observers that could have a normalized composite weight of 0
	local filteredObservers = {}
	for _, observer in ipairs(weightedObservers) do
		if observer.normalizedCompositeWeight > 0 then
			table.insert(filteredObservers, observer)
		end
	end

	weightedObservers = filteredObservers
	if constants.MAXIMUM_OBSERVERS_PER_EPOCH >= weightedObservers then
		return weightedObservers
	end

	local timestampEntropyHash = utils.getEntropyHashForEpoch(hashchain)
	local prescribedObserversAddresses = {}
	local hash = timestampEntropyHash
	while #prescribedObserversAddresses < constants.MAXIMUM_OBSERVERS_PER_EPOCH do
		--local random = readUInt32BE(hash) / 0xffffffff -- Convert hash to a value between 0 and 1
		local random = 1 -- TODO: this should be a random value bewteen 0 and 1
		local cumulativeNormalizedCompositeWeight = 0

		for _, observer in ipairs(weightedObservers) do
			-- add only if observer has not already been prescribed
			if not prescribedObserversAddresses[observer.gatewayAddress] then
				-- add the observers normalized composite weight to the cumulative weight
				cumulativeNormalizedCompositeWeight = cumulativeNormalizedCompositeWeight
					+ observer.normalizedCompositeWeight
				-- if the random value is less than the cumulative weight, we have found our observer
				if random <= cumulativeNormalizedCompositeWeight then
					prescribedObserversAddresses[observer.gatewayAddress] = true
					break
				end
			end
		end
		-- Compute the next hash for the next iteration
		local newHash = crypto.utils.stream.fromString(hash)
		hash = crypto.digest.sha2_256(newHash).asBytes()
	end
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

function gar.getObserverWeightsForEpoch(epochStartTimestamp, eligbileGateways)
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

return gar
