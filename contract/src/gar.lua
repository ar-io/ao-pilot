-- gar.lua
local balances = require("balances")
local utils = require("utils")
local gar = {}

GatewayRegistry = GatewayRegistry or {}
-- TODO: any necessary state modifcations as we iterate go here
local garSettings = {
	observers = {
		maxPerEpoch = 50,
		tenureWeightDays = 180,
		tenureWeightPeriod = 180 * 24 * 60 * 60 * 1000,
		maxTenureWeight = 4,
	},
	operators = {
		minStake = 10000 * 1000000, -- 10,000 IO
		withdrawLengthMs = 30 * 24 * 60 * 60 * 1000, -- 30 days to lower operator stake
		maxDelegates = 10000,
		leaveLengthMs = 90 * 24 * 60 * 60 * 1000, -- 90 days that balance will be vaulted
	},
	delegates = {
		minStake = 50 * 1000000, -- 50 IO
		withdrawLengthMs = 30 * 24 * 60 * 60 * 1000, -- 30 days
		minLockLengthMs = 24 * 60 * 60 * 1000, -- 1 day
		maxLockLengthMs = 3 * 365 * 24 * 60 * 60 * 1000, -- 3 years
	},
}

function gar.joinNetwork(from, stake, settings, observerAddress, timeStamp)
	gar.assertValidGatewayParameters(from, stake, settings, observerAddress)

	if gar.getGateway(from) then
		error("Gateway already exists")
	end

	if balances.getBalance(from) < stake then
		error("Insufficient balance")
	end

	local newGateway = {
		operatorStake = stake,
		totalDelegatedStake = 0,
		vaults = {},
		delegates = {},
		startTimestamp = timeStamp,
		stats = {
			prescribedEpochCount = 0,
			observedEpochCount = 0,
			totalEpochCount = 0,
			passedEpochCount = 0,
			failedEpochCount = 0,
			failedConsecutiveEpochs = 0,
			passedConsecutiveEpochs = 0,
		},
		settings = {
			allowDelegatedStaking = settings.allowDelegatedStaking or false,
			delegateRewardShareRatio = settings.delegateRewardShareRatio or 0,
			autoStake = settings.autoStake or false,
			minDelegatedStake = settings.minDelegatedStake,
			label = settings.label,
			fqdn = settings.fqdn,
			protocol = settings.protocol,
			port = settings.port,
			properties = settings.properties,
			note = settings.note,
		},
		status = "joined",
		observerAddress = observerAddress or from,
	}

	gar.addGateway(from, newGateway)
	balances.reduceBalance(from, stake)
	return gar.getGateway(from)
end

function gar.leaveNetwork(from, currentTimestamp, msgId)
	local gateway = gar.getGateway(from)

	if not gateway then
		error("Gateway does not exist in the network")
	end

	if not gar.isGatewayEligibleToLeave(gateway, currentTimestamp) then
		error("The gateway is not eligible to leave the network.")
	end

	local gatewayEndTimestamp = currentTimestamp + gar.getSettings().operators.leaveLengthMs
	local gatewayStakeWithdrawTimestamp = currentTimestamp + gar.getSettings().operators.withdrawLengthMs
	local delegateEndTimestamp = currentTimestamp + gar.getSettings().delegates.withdrawLengthMs

	-- Add minimum staked tokens to a vault that unlocks after the gateway completely leaves the network
	gateway.vaults[from] = {
		balance = gar.getSettings().operators.minStake,
		startTimestamp = currentTimestamp,
		endTimestamp = gatewayEndTimestamp,
	}

	gateway.operatorStake = gateway.operatorStake - gar.getSettings().operators.minStake

	-- Add remainder to another vault
	if gateway.operatorStake > 0 then
		gateway.vaults[msgId] = {
			balance = gateway.operatorStake,
			startTimestamp = currentTimestamp,
			endTimestamp = gatewayStakeWithdrawTimestamp,
		}
	end

	gateway.status = "leaving"
	gateway.endTimestamp = gatewayEndTimestamp
	gateway.operatorStake = 0

	-- Add tokens from each delegate to a vault that unlocks after the delegate withdrawal period ends
	for address, delegate in pairs(gateway.delegates) do
		-- Assuming SmartWeave and interactionHeight are previously defined in your Lua environment
		gateway.delegates[address].vaults[msgId] = {
			balance = delegate.delegatedStake,
			startTimestamp = currentTimestamp,
			endTimestamp = delegateEndTimestamp,
		}

		-- Reduce gateway stake and set this delegate stake to 0
		gateway.totalDelegatedStake = gateway.totalDelegatedStake - delegate.delegatedStake
		gateway.delegates[address].delegatedStake = 0
	end

	-- update global state
	GatewayRegistry[from] = gateway
	return gateway
end

function gar.increaseOperatorStake(from, qty)
	assert(type(qty) == "number", "Quantity is required and must be a number!")
	assert(qty > 0, "Quantity must be greater than 0")

	local gateway = gar.getGateway(from)

	if gateway == nil then
		error("Gateway does not exist")
	end

	if gateway.status == "leaving" then
		error("Gateway is leaving the network and cannot accept additional stake.")
	end

	if balances.getBalance(from) < qty then
		error("Insufficient balance")
	end

	balances.reduceBalance(from, qty)
	gateway.operatorStake = gateway.operatorStake + qty
	-- update the gateway
	GatewayRegistry[from] = gateway
	return gar.getGateway(from)
end

function gar.decreaseOperatorStake(from, qty, currentTimestamp, msgId)
	assert(type(qty) == "number", "Quantity is required and must be a number!")
	assert(qty > 0, "Quantity must be greater than 0")

	local gateway = gar.getGateway(from)

	if gateway == nil then
		error("Gateway does not exist")
	end

	if gateway.status == "leaving" then
		error("Gateway is leaving the network and withdraw more stake.")
	end

	local maxWithdraw = gateway.operatorStake - gar.getSettings().operators.minStake

	if qty > maxWithdraw then
		return error(
			"Resulting stake is not enough maintain the minimum operator stake of "
				.. gar.getSettings().operators.minStake
				.. " IO"
		)
	end

	gateway.operatorStake = gar.getGateway(from).operatorStake - qty
	gateway.vaults[msgId] = {
		balance = qty,
		startTimestamp = currentTimestamp,
		endTimestamp = currentTimestamp + gar.getSettings().operators.withdrawLengthMs,
	}
	-- update the gateway
	GatewayRegistry[from] = gateway
	return gar.getGateway(from)
end

function gar.updateGatewaySettings(from, updatedSettings, observerAddress, currentTimestamp, msgId)
	local gateway = gar.getGateway(from)

	if not gateway then
		error("Gateway does not exist")
	end

	gar.assertValidGatewayParameters(from, gateway.operatorStake, updatedSettings, observerAddress)

	if
		updatedSettings.minDelegatedStake
		and updatedSettings.minDelegatedStake < gar.getSettings().delegates.minStake
	then
		error("The minimum delegated stake must be at least " .. gar.getSettings().operators.minStake .. " IO")
	end

	local gateways = gar.getGateways()

	for gatewayAddress, gateway in pairs(gateways) do
		if gateway.observerAddress == observerAddress and gatewayAddress ~= from then
			error("Invalid observer wallet. The provided observer wallet is correlated with another gateway.")
		end
	end

	-- vault all delegated stakes if it is disabled, we'll return stake at the proper end heights of the vault
	if not updatedSettings.allowDelegatedStaking and next(gateway.delegates) ~= nil then
		-- Add tokens from each delegate to a vault that unlocks after the delegate withdrawal period ends
		local delegateEndTimestamp = currentTimestamp + gar.getSettings().delegates.withdrawLengthMs

		for address, delegate in pairs(gateway.delegates) do
			if not gateway.delegates[address].vaults then
				gateway.delegates[address].vaults = {}
			end

			local newDelegateVault = {
				balance = delegate.delegatedStake,
				startTimestamp = currentTimestamp,
				endTimestamp = delegateEndTimestamp,
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
	if observerAddress then
		gateway.observerAddress = observerAddress
	end
	-- update the gateway
	GatewayRegistry[from] = gateway
	return gar.getGateway(from)
end

function gar.getGateway(address)
	local gateway = utils.deepCopy(GatewayRegistry[address])
	return gateway
end

function gar.getGateways()
	local gateways = utils.deepCopy(GatewayRegistry)
	return gateways or {}
end

function gar.delegateStake(from, target, qty, currentTimestamp)
	assert(type(qty) == "number", "Quantity is required and must be a number!")
	assert(qty > 0, "Quantity must be greater than 0")
	assert(type(target) == "string", "Target is required and must be a string!")
	assert(type(from) == "string", "From is required and must be a string!")

	local gateway = gar.getGateway(target)
	if gateway == nil then
		error("Gateway does not exist")
	end

	-- don't allow delegating to yourself
	if from == target then
		error("Cannot delegate to your own gateway, use increaseOperatorStake instead.")
	end

	if balances.getBalance(from) < qty then
		error("Insufficient balance")
	end

	if gateway.status == "leaving" then
		error("This Gateway is in the process of leaving the network and cannot have more stake delegated to it.")
	end

	-- TODO: when allowedDelegates is supported, check if it's in the array of allowed delegates
	if not gateway.settings.allowDelegatedStaking then
		error(
			"This Gateway does not allow delegated staking. Only allowed delegates can delegate stake to this Gateway."
		)
	end

	local count = 0
	for _ in pairs(gateway.delegates) do
		count = count + 1
	end

	if count > gar.getSettings().operators.maxDelegates then
		error("This Gateway has reached its maximum amount of delegated stakers.")
	end

	-- Assuming `gateway` is a table and `fromAddress` is defined
	local existingDelegate = gateway.delegates[from]
	local minimumStakeForGatewayAndDelegate
	if existingDelegate and existingDelegate.delegatedStake ~= 0 then
		-- It already has a stake that is not zero
		minimumStakeForGatewayAndDelegate = 1 -- Delegate must provide at least one additional IO
	else
		-- Consider if the operator increases the minimum amount after you've already staked
		minimumStakeForGatewayAndDelegate = gateway.settings.minDelegatedStake
	end
	if qty < minimumStakeForGatewayAndDelegate then
		error("Quantity must be greater than the minimum delegated stake amount.")
	end

	-- If this delegate has staked before, update its amount, if not, create a new delegated staker
	if existingDelegate == nil then
		-- create the new delegate stake
		gateway.delegates[from] = {
			delegatedStake = qty,
			startTimestamp = currentTimestamp,
			vaults = {},
		}
	else
		-- increment the existing delegate's stake
		gateway.delegates[from].delegatedStake = gateway.delegates[from].delegatedStake + qty
	end
	-- Decrement the user's balance
	balances.reduceBalance(from, qty)
	gateway.totalDelegatedStake = gateway.totalDelegatedStake + qty
	-- update the gateway
	GatewayRegistry[target] = gateway
	return gar.getGateway(target)
end

function gar.getSettings()
	return garSettings
end

function gar.decreaseDelegateStake(gatewayAddress, delegator, qty, currentTimestamp, messageId)
	assert(type(qty) == "number", "Quantity is required and must be a number!")
	assert(qty > 0, "Quantity must be greater than 0")

	local gateway = gar.getGateway(gatewayAddress)

	if not gateway then
		error("Gateway does not exist")
	end
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
		endTimestamp = currentTimestamp + gar.getSettings().delegates.withdrawLengthMs,
	}

	-- Lock the qty in a vault to be unlocked after withdrawal period and decrease the gateway's total delegated stake
	gateway.delegates[delegator].vaults[messageId] = newDelegateVault
	gateway.delegates[delegator].delegatedStake = gateway.delegates[delegator].delegatedStake - qty
	gateway.totalDelegatedStake = gateway.totalDelegatedStake - qty
	-- update the gateway
	GatewayRegistry[gatewayAddress] = gateway
	return gar.getGateway(gatewayAddress)
end
function gar.isGatewayLeaving(gateway, currentTimestamp)
	return gateway.status == "leaving" and gateway.endTimestamp <= currentTimestamp
end

function gar.isGatewayEligibleToLeave(gateway, timestamp)
	if gateway == nil then
		error("Gateway does not exist")
	end
	local isJoined = gar.isGatewayJoined(gateway, timestamp)
	return isJoined
end

function gar.isGatewayActiveBetweenTimestamps(startTimestamp, endTimestamp, gateway)
	local didStartBeforeEpoch = gateway.startTimestamp <= startTimestamp
	local didNotLeaveDuringEpoch = not gar.isGatewayLeaving(gateway, endTimestamp)
	return didStartBeforeEpoch and didNotLeaveDuringEpoch
end

function gar.getActiveGatewaysBetweenTimestamps(startTimestamp, endtimestamp)
	local gateways = gar.getGateways()
	local activeGatewayAddresses = {}
	-- use pairs as gateways is a map
	for address, gateway in pairs(gateways) do
		if gar.isGatewayActiveBetweenTimestamps(startTimestamp, endtimestamp, gateway) then
			table.insert(activeGatewayAddresses, address)
		end
	end
	return activeGatewayAddresses
end

function gar.getGatewayWeightsAtTimestamp(gatewayAddresses, timestamp)
	local weightedObservers = {}
	local totalCompositeWeight = 0

	-- Iterate over gateways to calculate weights
	for _, address in pairs(gatewayAddresses) do
		local gateway = gar.getGateway(address)
		if gateway then
			local totalStake = gateway.operatorStake + gateway.totalDelegatedStake -- 100 - no cap to this
			local stakeWeightRatio = totalStake / gar.getSettings().operators.minStake -- this is always greater than 1 as the minOperatorStake is always less than the stake
			-- the percentage of the epoch the gateway was joined for before this epoch, if the gateway starts in the future this will be 0
			local gatewayStartTimestamp = gateway.startTimestamp
			local totalTimeForGateway = timestamp >= gatewayStartTimestamp and (timestamp - gatewayStartTimestamp) or -1
			-- TODO: should we increment by one here or are observers that join at the epoch start not eligible to be selected as an observer

			local calculatedTenureWeightForGateway = totalTimeForGateway < 0 and 0
				or (
					totalTimeForGateway > 0 and totalTimeForGateway / gar.getSettings().observers.tenureWeightPeriod
					or 1 / gar.getSettings().observers.tenureWeightPeriod
				)
			local gatewayTenureWeight =
				math.min(calculatedTenureWeightForGateway, gar.getSettings().observers.maxTenureWeight)

			local totalEpochsGatewayPassed = gateway.stats.passedEpochCount or 0
			local totalEpochsParticipatedIn = gateway.stats.totalEpochCount or 0
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
				observerAddress = gateway.observerAddress,
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

function gar.isGatewayJoined(gateway, currentTimestamp)
	return gateway.status == "joined" and gateway.startTimestamp <= currentTimestamp
end

function gar.assertValidGatewayParameters(from, stake, settings, observerAddress)
	assert(type(from) == "string", "from is required and must be a string!")
	assert(type(stake) == "number", "stake is required and must be a number!")
	assert(type(settings) == "table", "settings is required and must be a table!")
	assert(type(observerAddress) == "string", "observerAddress is required and must be a string!")
	assert(type(settings.allowDelegatedStaking) == "boolean", "allowDelegatedStaking must be a boolean")
	assert(type(settings.minDelegatedStake) == "number", "minDelegatedStake must be a number")
	assert(type(settings.label) == "string", "label is required and must be a string")
	assert(type(settings.fqdn) == "string", "fqdn is required and must be a string")
	assert(type(settings.protocol) == "string", "protocol is required and must be a string")
	assert(type(settings.port) == "number", "port is required and must be a number")
	assert(type(settings.properties) == "string", "properties is required and must be a string")
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

function gar.updateGatewayStats(address, stats)
	local gateway = gar.getGateway(address)
	if gateway == nil then
		error("Gateway does not exist")
	end

	assert(stats.prescribedEpochCount, "prescribedEpochCount is required")
	assert(stats.observedEpochCount, "observedEpochCount is required")
	assert(stats.totalEpochCount, "totalEpochCount is required")
	assert(stats.passedEpochCount, "passedEpochCount is required")
	assert(stats.failedEpochCount, "failedEpochCount is required")
	assert(stats.failedConsecutiveEpochs, "failedConsecutiveEpochs is required")
	assert(stats.passedConsecutiveEpochs, "passedConsecutiveEpochs is required")

	gateway.stats = stats
	GatewayRegistry[address] = gateway
end

function gar.addGateway(address, gateway)
	GatewayRegistry[address] = gateway
end

-- for test purposes
function gar.updateSettings(newSettings)
	garSettings = newSettings
end

function gar.pruneGateways(currentTimestamp)
	local gateways = gar.getGateways()
	-- we take a deep copy so we can operate directly on the gateway object
	for address, gateway in pairs(gateways) do
		if gateway then
			-- first, return any expired vaults regardless of the gateway status
			for vaultId, vault in pairs(gateway.vaults) do
				if vault.endTimestamp <= currentTimestamp then
					balances.increaseBalance(address, vault.balance)
					gateway.vaults[vaultId] = nil
				end
			end
			-- return any delegated vaults and return the stake to the delegate
			for delegateAddress, delegate in pairs(gateway.delegates) do
				for vaultId, vault in pairs(delegate.vaults) do
					if vault.endTimestamp <= currentTimestamp then
						balances.increaseBalance(delegateAddress, vault.balance)
						delegate.vaults[vaultId] = nil
					end
				end
			end
			-- remove the delegate if all vaults are empty and the delegated stake is 0
			for delegateAddress, delegate in pairs(gateway.delegates) do
				if delegate.delegatedStake == 0 and next(delegate.vaults) == nil then
					gateway.delegates[delegateAddress] = nil
				end
			end
			-- update the gateway before we do anything else
			GatewayRegistry[address] = gateway

			-- if gateway is joined but failed more than 3 consecutive epochs, mark it as leaving and put operator stake and delegate stakes in vaults
			if gateway.status == "joined" and gateway.stats.failedConsecutiveEpochs >= 3 then
				gar.leaveNetwork(address, currentTimestamp, address)
			else
				if gateway.status == "leaving" and gateway.endTimestamp <= currentTimestamp then
					-- if the timestamp is after gateway end timestamp, mark the gateway as nil
					GatewayRegistry[address] = nil
				end
			end
		end
	end
end

return gar
