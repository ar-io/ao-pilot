-- gar.lua
local crypto = require("crypto.init")
local utils = require("utils")
local base64 = require("base64")
local balances = require("balances")
local gar = {}

Epochs = Epochs
	or {
		[0] = {
			startTimestamp = 0,
			endTimestamp = 0,
			-- TODO: add settings here
			observations = {
				failureSummaries = {},
				reports = {},
			},
			prescribedObservers = {},
			distributions = {},
		},
	}
GatewayRegistry = GatewayRegistry
	or {
		gateways = {},
		settings = {
			observers = {
				maxObserversPerEpoch = 50,
				tenureWeightDays = 180,
				tenureWeightPeriod = 180 * 24 * 60 * 60 * 1000,
				maxTenureWeight = 4,
			},
			epochs = {
				durationMs = 24 * 60 * 60 * 1000, -- One day of miliseconds
				epochZeroStartTimestamp = 0,
				distributionDelayMs = 30 * 60 * 1000, -- 30 minutes of miliseconds
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

-- TODO: any necessary state modifcations as we iterate go here
-- e.g. gar.getSettings().gateways =

function gar.joinNetwork(from, stake, settings, observerWallet, timeStamp)
	gar.assertValidGatewayParameters(from, stake, settings, observerWallet, timeStamp)

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

	gar.addGateway(from, newGateway)
	balances.reduceBalance(from, stake)
	return gar.getGateway(from)
end

function gar.computePrescribedObserversForEpoch(epochIndex, hashchain)
	local eligibleGateways = gar.getEligibleGatewaysForEpoch(epochIndex)
	local weightedObservers = gar.getObserverWeightsForEpoch(epochIndex, eligibleGateways)
	-- Filter out any observers that could have a normalized composite weight of 0
	local filteredObservers = {}
	-- use ipairs as weightedObservers in array
	for _, observer in ipairs(weightedObservers) do
		if observer.normalizedCompositeWeight > 0 then
			table.insert(filteredObservers, observer)
		end
	end
	if #filteredObservers <= gar.getSettings().observers.maxObserversPerEpoch then
		return filteredObservers
	end

	-- the hash we will use to create entropy for prescribed observers
	local epochHash = gar.getHashFromBase64(hashchain)

	-- sort the observers using entropy from the hash chain, this will ensure that the same observers are selected for the same epoch
	table.sort(filteredObservers, function(observerA, observerB)
		local addressAHash = gar.getHashFromBase64(observerA.gatewayAddress .. hashchain)
		local addressBHash = gar.getHashFromBase64(observerB.gatewayAddress .. hashchain)
		local addressAString = crypto.utils.array.toString(addressAHash)
		local addressBString = crypto.utils.array.toString(addressBHash)
		return addressAString < addressBString
	end)

	-- get our prescribed observers, using the hashchain as entropy
	local hash = epochHash
	local prescribedObserversAddresses = {}
	while #prescribedObserversAddresses < gar.getSettings().observers.maxObserversPerEpoch do
		local hashString = crypto.utils.array.toString(hash)
		local random = crypto.random(nil, nil, hashString) / 0xffffffff
		local cumulativeNormalizedCompositeWeight = 0
		-- use ipairs as filtered observers is an array
		for i = 1, #filteredObservers do
			local observer = filteredObservers[i]
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
		-- hash the hash to get a new hash
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

	local gatewayEndHeight = currentTimestamp + gar.getSettings().gatewayLeaveLength
	local gatewayStakeWithdrawHeight = currentTimestamp + gar.getSettings().operatorStakeWithdrawLength
	local delegateEndHeight = currentTimestamp + gar.getSettings().delegatedStakeWithdrawLength

	-- Add minimum staked tokens to a vault that unlocks after the gateway completely leaves the network
	gateway.vaults[from] = {
		balance = gar.getSettings().minOperatorStake,
		startTimestamp = currentTimestamp,
		endTimestamp = gatewayEndHeight,
	}

	gateway.operatorStake = gateway.operatorStake - gar.getSettings().minOperatorStake

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
	GatewayRegistry.gateways[from] = gateway
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

	if balances.getBalance(from) < qty then
		error("Insufficient balance")
	end

	balances.reduceBalance(from, qty)
	GatewayRegistry.gateways[from].operatorStake = gar.getGateway(from).operatorStake + qty
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

	local maxWithdraw = gateway.operatorStake - gar.getSettings().minOperatorStake

	if qty > maxWithdraw then
		return error(
			"Resulting stake is not enough maintain the minimum operator stake of "
				.. gar.getSettings().minOperatorStake
				.. " IO"
		)
	end

	gateway.operatorStake = gar.getGateway(from).operatorStake - qty
	gateway.vaults[msgId] = {
		balance = qty,
		startTimestamp = currentTimestamp,
		endTimestamp = currentTimestamp + gar.getSettings().operatorStakeWithdrawLength,
	}
	return gar.getGateway(from)
end

function gar.updateGatewaySettings(from, updatedSettings, observerWallet, currentTimestamp, msgId)
	if not gar.getGateway(from) then
		error("Gateway does not exist")
	end

	local gateway = gar.getGateway(from)

	gar.assertValidGatewayParameters(from, gateway.operatorStake, updatedSettings, observerWallet, currentTimestamp)

	if
		updatedSettings.minDelegatedStake
		and updatedSettings.minDelegatedStake < gar.getSettings().minDelegatedStake
	then
		error("The minimum delegated stake must be at least " .. gar.getSettings().minDelegatedStake .. " IO")
	end

	for gatewayAddress, gateway in pairs(gar.getGateways()) do
		if gateway.observerWallet == observerWallet and gatewayAddress ~= from then
			error("Invalid observer wallet. The provided observer wallet is correlated with another gateway.")
		end
	end

	-- vault all delegated stakes if it is disabled, we'll return stake at the proper end heights of the vault
	if not updatedSettings.allowDelegatedStaking and next(gateway.delegates) ~= nil then
		-- Add tokens from each delegate to a vault that unlocks after the delegate withdrawal period ends
		local delegateEndHeight = currentTimestamp + gar.getSettings().delegatedStakeWithdrawLength

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
	return GatewayRegistry.gateways[target]
end

function gar.getGateways()
	return GatewayRegistry.gateways
end

function gar.delegateStake(from, target, qty, currentTimestamp)
	assert(type(qty) == "number", "Quantity is required and must be a number!")
	assert(qty > 0, "Quantity must be greater than 0")

	local gateway = gar.getGateway(target)
	if gateway == nil then
		error("Gateway does not exist")
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

	if count > gar.getSettings().maxDelegates then
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

	-- Decrement the user's balance
	balances.reduceBalance(from, qty)
	gateway.totalDelegatedStake = gateway.totalDelegatedStake + qty
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
		gateway.delegates[from].delegatedStake = gar.gateways[target].delegates[from].delegatedStake + qty
	end
	return gateway
end

function gar.getSettings()
	return GatewayRegistry.settings
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
		endTimestamp = currentTimestamp + gar.getSettings().delegatedStakeWithdrawLength,
	}

	-- Lock the qty in a vault to be unlocked after withdrawal period and decrease the gateway's total delegated stake
	gateway.delegates[delegator].vaults[messageId] = newDelegateVault
	gateway.delegates[delegator].delegatedStake = gateway.delegates[delegator].delegatedStake - qty
	gateway.totalDelegatedStake = gateway.totalDelegatedStake - qty
	return gar.getGateway(gatewayAddress)
end

function gar.saveObservations(from, reportTxId, failedGateways, timestamp)
	local epochIndex = gar.getEpochIndexForTimestamp(timestamp)
	local epochStartTimestamp, _, epochDistributionTimestamp, epochIndex = gar.getEpochTimestampsForIndex(epochIndex)

	-- avoid observations before the previous epoch distribution has occurred, as distributions affect weights of the current epoch
	if timestamp < epochStartTimestamp + gar.getSettings().epochs.distributionDelayMs then
		error("Observations for the current epoch cannot be submitted before: " .. epochDistributionTimestamp)
	end

	local prescribedObservers = gar.getPrescribedObserversForEpoch(epochIndex)
	-- print each prescribed observer
	if #prescribedObservers == 0 then
		error("No prescribed observers for the current epoch.")
	end

	local observerIndex = utils.findInArray(prescribedObservers, function(prescribedObserver)
		return prescribedObserver.observerAddress == from
	end)

	local observer = prescribedObservers[observerIndex]

	if observer == nil then
		error("Caller is not a prescribed observer for the current epoch.")
	end

	local observingGateway = gar.getGateway(observer.gatewayAddress)

	if observingGateway == nil then
		error("The associated gateway does not exist in the registry.")
	end

	-- check if this is the first report filed in this epoch (TODO: use start or end?)
	if Epochs[epochIndex].observations == nil then
		Epochs[epochIndex].observations = {
			failureSummaries = {},
			reports = {},
		}
	end

	for _, failedGatewayAddress in pairs(failedGateways) do
		local failedGateway = gar.getGateway(failedGatewayAddress)

		-- validate the gateway should be marked as failed for the epoch
		if
			failedGateway
			and failedGateway.startTimestamp <= epochStartTimestamp
			and failedGateway.status == "joined"
		then
			-- if there are none, create an array
			if Epochs[epochIndex].observations.failureSummaries == nil then
				Epochs[epochIndex].observations.failureSummaries = {}
			end
			-- Get the existing set of failed gateways for this observer
			local observersMarkedFailed = Epochs[epochIndex].observations.failureSummaries[failedGatewayAddress] or {}

			-- if list of observers who marked failed does not continue current observer than add it
			local alreadyObservedIndex = utils.findInArray(observersMarkedFailed, function(observer)
				return observer == observingGateway.observerWallet
			end)

			if not alreadyObservedIndex then
				table.insert(observersMarkedFailed, observingGateway.observerWallet)
			end

			Epochs[epochIndex].observations.failureSummaries[failedGatewayAddress] = observersMarkedFailed
		end
	end

	-- if reports are not already present, create an array
	if Epochs[epochIndex].observations.reports == nil then
		Epochs[epochIndex].observations.reports = {}
	end

	Epochs[epochIndex].observations.reports[observingGateway.observerWallet] = reportTxId
	return Epochs[epochIndex].observations
end

function gar.getEpochTimestampsForIndex(epochIndex)
	local epochSettings = gar.getSettings().epochs
	local epochStartTimestamp = epochSettings.epochZeroStartTimestamp + epochSettings.durationMs * epochIndex
	local epochEndTimestamp = epochStartTimestamp + epochSettings.durationMs
	local epochDistributionTimestamp = epochEndTimestamp + epochSettings.distributionDelayMs
	return epochStartTimestamp, epochEndTimestamp, epochDistributionTimestamp, epochIndex
end

function gar.getEpochIndexForTimestamp(timestamp)
	local epochZeroStartTimestamp = gar.getSettings().epochs.epochZeroStartTimestamp
	local epochLengthMs = gar.getSettings().epochs.durationMs
	local epochIndex = math.floor((timestamp - epochZeroStartTimestamp) / epochLengthMs)
	return epochIndex
end

function gar.getCurrentEpoch()
	return GatewayRegistry.epoch
end

function gar.getPrescribedObserversForEpoch(epochIndex)
	local prescribedObsevers = Epochs[epochIndex].prescribedObservers or {}
	return prescribedObsevers
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

function gar.isGatewayEligibleForDistribution(epochIndex, gateway)
	local epochStartTimestamp, epochEndTimestamp = gar.getEpochTimestampsForIndex(epochIndex)
	local didStartBeforeEpoch = gateway.startTimestamp <= epochStartTimestamp
	local didNotLeaveDuringEpoch = not gar.isGatewayLeaving(gateway, epochEndTimestamp)
	return didStartBeforeEpoch and didNotLeaveDuringEpoch
end

function gar.getEligibleGatewaysForEpoch(epochIndex)
	local gateways = gar.getGateways()
	local eligibleGateways = {}
	for address, gateway in pairs(gateways) do
		if gar.isGatewayEligibleForDistribution(epochIndex, gateway) then
			eligibleGateways[address] = gar.getGateway(address)
		end
	end
	return eligibleGateways
end

function gar.setPrescribedObserversForEpoch(epochIndex, prescribedObservers)
	Epochs[epochIndex].prescribedObservers = prescribedObservers
end

function gar.getObserverWeightsForEpoch(epochIndex, eligbileGateways)
	local epochStartTimestamp = gar.getEpochTimestampsForIndex(epochIndex)
	local weightedObservers = {}
	local totalCompositeWeight = 0

	-- Iterate over gateways to calculate weights
	for address, gateway in pairs(eligbileGateways) do
		local totalStake = gateway.operatorStake + gateway.totalDelegatedStake -- 100 - no cap to this
		local stakeWeightRatio = totalStake / gar.getSettings().minOperatorStake -- this is always greater than 1 as the minOperatorStake is always less than the stake
		-- the percentage of the epoch the gateway was joined for before this epoch, if the gateway starts in the future this will be 0
		local gatewayStartTimestamp = gateway.startTimestamp
		local totalTimeForGateway = epochStartTimestamp >= gatewayStartTimestamp
				and (epochStartTimestamp - gatewayStartTimestamp)
			or -1
		-- TODO: should we increment by one here or are observers that join at the epoch start not eligible to be selected as an observer

		local calculatedTenureWeightForGateway = totalTimeForGateway < 0 and 0
			or (
				totalTimeForGateway > 0 and totalTimeForGateway / gar.getSettings().observers.tenureWeightPeriod
				or 1 / gar.getSettings().observers.tenureWeightPeriod
			)
		local gatewayTenureWeight =
			math.min(calculatedTenureWeightForGateway, gar.getSettings().observers.maxTenureWeight)

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

function gar.getHashFromBase64(str)
	local decodedHash = base64.decode(str)
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

function gar.addGateway(address, gateway)
	GatewayRegistry.gateways[address] = gateway
end

return gar
