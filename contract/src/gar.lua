-- gar.lua
require("state")
local crypto = require('.crypto')
local utils = require("utils")
local constants = require("constants")
local gar = {}

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
		return false, "from, settings, stake and timestamp are required"
	end

	if Gateways[from] ~= nil then
		return false, "Gateway already exists in the network"
	end

	if stake < constants.MIN_OPERATOR_STAKE then
		return false, "Caller did not provide enough tokens to stake"
	end

	if Balances[from] < constants.MIN_OPERATOR_STAKE then
		return false, "Caller does not have enough tokens to stake"
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

	Gateways[from] = newGateway
	return newGateway
end

function gar.leaveNetwork(from, currentTimestamp, msgId)
	if from == nil then
		return false, "from is required"
	end

	if Gateways[from] == nil then
		return false, "Gateway does not exist in the network"
	end

	local gateway = Gateways[from]

	if not utils.isGatewayEligibleToLeave(gateway, currentTimestamp) then
		return false,
			"The gateway is not eligible to leave the network."
	end

	local gatewayEndHeight = currentTimestamp + constants.GATEWAY_REGISTRY_SETTINGS.gatewayLeaveLength
	local gatewayStakeWithdrawHeight = currentTimestamp + constants.GATEWAY_REGISTRY_SETTINGS
		.operatorStakeWithdrawLength
	local delegateEndHeight = currentTimestamp + constants.GATEWAY_REGISTRY_SETTINGS.delegatedStakeWithdrawLength

	-- Add minimum staked tokens to a vault that unlocks after the gateway completely leaves the network
	gateway.vaults[from] = {
		balance = constants.MIN_OPERATOR_STAKE,
		startTimestamp = currentTimestamp,
		endTimestamp = gatewayEndHeight
	};

	gateway.operatorStake = gateway.operatorStake - constants.MIN_OPERATOR_STAKE;

	-- Add remainder to another vault
	if gateway.operatorStake > 0 then
		gateway.vaults[msgId] = {
			balance = gateway.operatorStake,
			startTimestamp = currentTimestamp,
			endTimestamp = gatewayStakeWithdrawHeight
		};
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
			endTimestamp = delegateEndHeight
		}

		-- Reduce gateway stake and set this delegate stake to 0
		gateway.totalDelegatedStake = gateway.totalDelegatedStake - delegate.delegatedStake
		gateway.delegates[address].delegatedStake = 0
	end

	-- update global state
	Gateways[from] = gateway
	return gateway
end

function gar.increaseOperatorStake(from, qty)
	assert(type(qty) == 'number', 'Quantity is required and must be a number!')
	assert(qty > 0, 'Quantity must be greater than 0')

	if Gateways[from] == nil then
		return false, "Gateway does not exist"
	end

	if Gateways[from].status == 'leaving' then
		return false, 'Gateway is leaving the network and cannot accept additional stake.'
	end

	if not Balances[from] then Balances[from] = 0 end

	if Balances[from] < qty then
		return false, "Insufficient funds!"
	end

	Balances[from] = Balances[from] - qty
	Gateways[from].operatorStake = Gateways[from].operatorStake + qty
	return Gateways[from]
end

function gar.decreaseOperatorStake(from, qty, currentTimestamp, msgId)
	assert(type(qty) == 'number', 'Quantity is required and must be a number!')
	assert(qty > 0, 'Quantity must be greater than 0')

	if Gateways[from] == nil then
		return false, "Gateway does not exist"
	end

	if Gateways[from].status == 'leaving' then
		return false, 'Gateway is leaving the network and withdraw more stake.'
	end

	local maxWithdraw = Gateways[from].operatorStake - constants.MIN_OPERATOR_STAKE

	if qty > maxWithdraw then
		return false,
			"Resulting stake is not enough maintain the minimum operator stake of " ..
			constants.MIN_OPERATOR_STAKE .. " IO"
	end

	Gateways[from].operatorStake = Gateways[from].operatorStake - qty
	Gateways[from].vaults[msgId] = {
		balance = qty,
		startTimestamp = currentTimestamp,
		endTimestamp = currentTimestamp + constants.GATEWAY_REGISTRY_SETTINGS.operatorStakeWithdrawLength
	}
	return Gateways[from]
end

function gar.updateGatewaySettings(from, updatedSettings, observerWallet, currentTimestamp, msgId)
	if Gateways[from] == nil then
		return false, "Gateway does not exist"
	end

	local validSettings, err = utils.validateUpdateGatewaySettings(updatedSettings, observerWallet)
	if not validSettings then
		return false, err
	end

	if updatedSettings.minDelegatedStake and updatedSettings.minDelegatedStake < constants.MIN_DELEGATED_STAKE then
		return false, "The minimum delegated stake must be at least " .. constants.MIN_DELEGATED_STAKE .. " IO"
	end

	for gatewayAddress, gateway in pairs(Gateways) do
		if gateway.observerWallet == observerWallet and gatewayAddress ~= from then
			return false, "Invalid observer wallet. The provided observer wallet is correlated with another gateway."
		end
	end

	-- vault all delegated stakes if it is disabled, we'll return stake at the proper end heights of the vault
	if not updatedSettings.allowDelegatedStaking and next(Gateways[from].delegates) ~= nil then
		-- Add tokens from each delegate to a vault that unlocks after the delegate withdrawal period ends
		local delegateEndHeight = currentTimestamp + constants.GATEWAY_REGISTRY_SETTINGS.delegatedStakeWithdrawLength

		for address, delegate in pairs(Gateways[from].delegates) do
			if not Gateways[from].delegates[address].vaults then
				Gateways[from].delegates[address].vaults = {}
			end
			Gateways[from].delegates[address].vaults[msgId] = {
				balance = delegate.delegatedStake,
				startTimestamp = currentTimestamp,
				endTimestamp = delegateEndHeight
			}

			-- reduce gateway stake and set this delegate stake to 0
			Gateways[from].totalDelegatedStake = Gateways[from].totalDelegatedStake - delegate.delegatedStake
			Gateways[from].delegates[address].delegatedStake = 0
		end
	end

	-- if allowDelegateStaking is currently false, and you want to set it to true - you have to wait until all the vaults have been returned
	if updatedSettings.allowDelegatedStaking == true and
		Gateways[from].settings.allowDelegatedStaking == false and
		next(Gateways[from].delegates) ~= nil then -- checks if the delegates table is not empty
		return false, "You cannot enable delegated staking until all delegated stakes have been withdrawn."
	end

	Gateways[from].settings = updatedSettings
	if observerWallet then
		Gateways[from].observerWallet = observerWallet
	end
	return Gateways[from]
end

function gar.getGateway(target)
	if Gateways[target] == nil then
		return false, "Gateway does not exist"
	end
	return Gateways[target]
end

function gar.getGateways()
	return Gateways
end

function gar.delegateStake(from, target, qty, currentTimestamp)
	assert(type(qty) == 'number', 'Quantity is required and must be a number!')
	assert(qty > 0, 'Quantity must be greater than 0')
	if Gateways[target] == nil then
		return false, "Gateway does not exist"
	end

	if Balances[from] < qty then
		return false, "Insufficient funds!"
	end

	if Gateways[target].status == 'leaving' then
		return false, "This Gateway is in the process of leaving the network and cannot have more stake delegated to it."
	end

	-- TODO: when allowedDelegates is supported, check if it's in the array of allowed delegates
	if not Gateways[target].settings.allowDelegatedStaking then
		return false,
			"This Gateway does not allow delegated staking. Only allowed delegates can delegate stake to this Gateway."
	end

	local count = 0
	for _ in pairs(Gateways[target].delegates) do
		count = count + 1
	end

	if count > constants.MAX_DELEGATES then
		return false, "This Gateway has reached its maximum amount of delegated stakers."
	end

	-- Assuming `gateway` is a table and `fromAddress` is defined
	local existingDelegate = Gateways[target].delegates[from]
	local minimumStakeForGatewayAndDelegate
	if existingDelegate and existingDelegate.delegatedStake ~= 0 then
		-- It already has a stake that is not zero
		minimumStakeForGatewayAndDelegate = 1 -- Delegate must provide at least one additional IO
	else
		-- Consider if the operator increases the minimum amount after you've already staked
		minimumStakeForGatewayAndDelegate = Gateways[target].settings.minDelegatedStake
	end
	if qty < minimumStakeForGatewayAndDelegate then
		return false, "Quantity must be greater than the minimum delegated stake amount."
	end

	-- Decrement the user's balance
	Balances[from] = Balances[from] - qty
	Gateways[target].totalDelegatedStake = Gateways[target].totalDelegatedStake + qty
	-- If this delegate has staked before, update its amount, if not, create a new delegated staker
	if existingDelegate == nil then
		-- create the new delegate stake
		Gateways[target].delegates[from] = {
			delegatedStake = qty,
			startTimestamp = currentTimestamp,
			vaults = {},
		}
	else
		-- increment the existing delegate's stake
		Gateways[target].delegates[from].delegatedStake = Gateways[target].delegates[from].delegatedStake + qty;
	end
	return Gateways[target]
end

function gar.decreaseDelegateStake(from, target, qty, currentTimestamp, msgId)
	assert(type(qty) == 'number', 'Quantity is required and must be a number!')
	assert(qty > 0, 'Quantity must be greater than 0')

	if Gateways[from] == nil then
		return false, "Gateway does not exist"
	end

	if Gateways[from].status == 'leaving' then
		return false, 'Gateway is leaving the network and withdraw more stake.'
	end
	if Gateways[target].delegates[from] == nil then
		return false, "This delegate is not staked at this gateway."
	end

	local existingStake = Gateways[target].delegates[from].delegatedStake
	local requiredMinimumStake = Gateways[target].settings.minDelegatedStake
	local maxAllowedToWithdraw = existingStake - requiredMinimumStake
	if maxAllowedToWithdraw < qty and qty ~= existingStake then
		return false, "Remaining delegated stake must be greater than the minimum delegated stake amount."
	end

	-- Withdraw the delegate's stake
	Gateways[target].delegates[from].delegatedStake = Gateways[target].delegates[from].delegatedStake - qty

	-- Lock the qty in a vault to be unlocked after withdrawal period
	Gateways[target].delegates[from].vaults[msgId] = {
		balance = qty,
		startTimestamp = currentTimestamp,
		endTimestamp = currentTimestamp + constants.GATEWAY_REGISTRY_SETTINGS.delegatedStakeWithdrawLength
	}

	-- Decrease the gateway's total delegated stake.
	Gateways[target].totalDelegatedStake = Gateways[target].totalDelegatedStake - qty
	return Gateways[target]
end

function gar.saveObservations()
	-- TODO: implement
	utils.reply("saveObservations is not implemented yet")
end

function gar.getEpochDataForTimestamp(currentTimestamp)
	local epochIndexForCurrentTimestamp = math.floor(
		math.max(
			0,
			(currentTimestamp - constants.epochZeroStartTimestamp) / constants.epochTimeLength
		)
	)

	local epochStartTimestamp = constants.epochZeroStartTimestamp +
		constants.epochTimeLength * epochIndexForCurrentTimestamp
	local epochEndTimestamp = epochStartTimestamp + constants.epochTimeLength
	local epochDistributionTimestamp = epochEndTimestamp + constants.EPOCH_DISTRIBUTION_DELAY
	return epochStartTimestamp, epochEndTimestamp, epochDistributionTimestamp, epochIndexForCurrentTimestamp
end

function gar.getPrescribedObservers(currentTimestamp)
	local epochStartTimestamp, epochEndTimestamp, epochDistributionTimestamp, epochIndexForCurrentTimestamp = gar
		.getEpochDataForTimestamp(currentTimestamp)

	local existingOrComputedObservers = PrescribedObservers[epochIndexForCurrentTimestamp] or {}
	return existingOrComputedObservers
end

function gar.getPrescribedObserversForEpoch(epochStartTimestamp, epochEndTimestamp, hashchain)
	local eligibleGateways = utils.getEligibleGatewaysForEpoch(epochStartTimestamp, epochEndTimestamp)
	local weightedObservers = utils.getObserverWeightsForEpoch(epochStartTimestamp)
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
	while (utils.tableLength(prescribedObserversAddresses) < constants.MAXIMUM_OBSERVERS_PER_EPOCH) do
		--local random = readUInt32BE(hash) / 0xffffffff -- Convert hash to a value between 0 and 1
		local random = 1
		local cumulativeNormalizedCompositeWeight = 0

		for _, observer in ipairs(weightedObservers) do
			-- skip observers that have already been prescribed
			if prescribedObserversAddresses[observer.gatewayAddress] then
				goto continue
			end
			-- add the observers normalized composite weight to the cumulative weight
			cumulativeNormalizedCompositeWeight = cumulativeNormalizedCompositeWeight +
				observer.normalizedCompositeWeight
			-- if the random value is less than the cumulative weight, we have found our observer
			if random <= cumulativeNormalizedCompositeWeight then
				prescribedObserversAddresses[observer.gatewayAddress] = true
				break
			end
			::continue::
		end
		-- Compute the next hash for the next iteration
		-- hash = hashFunction(hash) -- Assuming hashFunction is synchronous and already defined
		hash = 1
	end
end

function gar.getEpoch()
	-- TODO: implement
	utils.reply("getEpoch is not implemented yet")
end

function gar.getObservations()
	-- TODO: implement
	utils.reply("getObservations is not implemented yet")
end

return gar
