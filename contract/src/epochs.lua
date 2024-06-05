local gar = require("gar")
local crypto = require("crypto.init")
local utils = require("utils")
local balances = require("balances")
local epochs = {}

Epochs = Epochs
	or {
		[0] = {
			startTimestamp = 0,
			endTimestamp = 0,
			distributionTimestamp = 0,
			startBlockHeight = 0,
			observations = {
				failureSummaries = {},
				reports = {},
			},
			prescribedObservers = {},
			distributions = {},
		},
	}

local epochSettings = {
	-- TODO: make these configurable
	rewardPercentage = 0.0025, -- 0.25%
	maxObservers = 50,
	epochZeroStartTimestamp = 0,
	durationMs = 60 * 1000 * 60 * 24, -- 24 hours
	distributionDelayMs = 60 * 1000 * 2 * 15, -- 15 blocks / 30 minutes
}

function epochs.getEpochs()
	local epochs = utils.deepCopy(Epochs) or {}
	return epochs
end

function epochs.getEpoch(epochNumber)
	local epoch = utils.deepCopy(Epochs[epochNumber]) or {}
	return epoch
end

function epochs.getObservers()
	return epochs.getCurrentEpoch().prescribedObservers or {}
end

function epochs.getSettings()
	return epochSettings
end

function epochs.getObservations()
	return epochs.getCurrentEpoch().observations or {}
end

function epochs.getReports()
	return epochs.getObservations().reports or {}
end

function epochs.getDistribution()
	return epochs.getCurrentEpoch().distributions or {}
end

function epochs.getPrescribedObserversForEpoch(epochNumber)
	return epochs.getEpoch(epochNumber).prescribedObservers or {}
end

function epochs.getReportsForEpoch(epochNumber)
	return epochs.getEpoch(epochNumber).observations.reports or {}
end

function epochs.getDistributionForEpoch(epochNumber)
	return epochs.getEpoch(epochNumber).distributions or {}
end

function epochs.getEpochFromTimestamp(timestamp)
	local epochIndex = epochs.getEpochIndexForTimestamp(timestamp)
	return epochs.getEpoch(epochIndex)
end
function epochs.setPrescribedObserversForEpoch(epochNumber, hashchain)
	local prescribedObservers = epochs.computePrescribedObserversForEpoch(epochNumber, hashchain)
	local epoch = epochs.getEpoch(epochNumber)
	-- assign the prescribed observers and update the epoch
	epoch.prescribedObservers = prescribedObservers
	Epochs[epochNumber] = epoch
end

function epochs.computePrescribedObserversForEpoch(epochIndex, hashchain)
	assert(epochIndex >= 0, "Epoch index must be greater than or equal to 0")
	assert(type(hashchain) == "string", "Hashchain must be a string")

	local epochStartTimestamp, epochEndTimestamp = epochs.getEpochTimestampsForIndex(epochIndex)
	local activeGatewayAddresses = gar.getActiveGatewaysBetweenTimestamps(epochStartTimestamp, epochEndTimestamp)
	local weightedObservers = gar.getGatewayWeightsAtTimestamp(activeGatewayAddresses, epochStartTimestamp)

	-- Filter out any observers that could have a normalized composite weight of 0
	local filteredObservers = {}
	-- use ipairs as weightedObservers in array
	for _, observer in ipairs(weightedObservers) do
		if observer.normalizedCompositeWeight > 0 then
			table.insert(filteredObservers, observer)
		end
	end
	if #filteredObservers <= epochSettings.maxObservers then
		return filteredObservers
	end

	-- the hash we will use to create entropy for prescribed observers
	local epochHash = utils.getHashFromBase64(hashchain)

	-- sort the observers using entropy from the hash chain, this will ensure that the same observers are selected for the same epoch
	table.sort(filteredObservers, function(observerA, observerB)
		local addressAHash = utils.getHashFromBase64(observerA.gatewayAddress .. hashchain)
		local addressBHash = utils.getHashFromBase64(observerB.gatewayAddress .. hashchain)
		local addressAString = crypto.utils.array.toString(addressAHash)
		local addressBString = crypto.utils.array.toString(addressBHash)
		return addressAString < addressBString
	end)

	-- get our prescribed observers, using the hashchain as entropy
	local hash = epochHash
	local prescribedObserversAddresses = {}
	while #prescribedObserversAddresses < epochSettings.maxObservers do
		local hashString = crypto.utils.array.toString(hash)
		local random = crypto.random(nil, nil, hashString) / 0xffffffff
		local cumulativeNormalizedCompositeWeight = 0
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
	-- use ipairs as prescribedObserversAddresses is an array
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

function epochs.getEpochTimestampsForIndex(epochIndex)
	local epochStartTimestamp = epochSettings.epochZeroStartTimestamp + epochSettings.durationMs * epochIndex
	local epochEndTimestamp = epochStartTimestamp + epochSettings.durationMs
	local epochDistributionTimestamp = epochEndTimestamp + epochSettings.distributionDelayMs
	return epochStartTimestamp, epochEndTimestamp, epochDistributionTimestamp
end

function epochs.getEpochIndexForTimestamp(timestamp)
	local epochZeroStartTimestamp = epochSettings.epochZeroStartTimestamp
	local epochLengthMs = epochSettings.durationMs
	local epochIndex = math.floor((timestamp - epochZeroStartTimestamp) / epochLengthMs)
	return epochIndex
end

function epochs.createEpoch(timestamp, blockHeight, hashchain)
	assert(type(timestamp) == "number", "Timestamp must be a number")
	assert(type(blockHeight) == "number", "Block height must be a number")
	assert(type(hashchain) == "string", "Hashchain must be a string")

	local epochIndex = epochs.getEpochIndexForTimestamp(timestamp)
	if next(epochs.getEpoch(epochIndex)) then
		-- silently return
		return
	end
	local epochStartTimestamp, epochEndTimestamp, epochDistributionTimestamp =
		epochs.getEpochTimestampsForIndex(epochIndex)
	local prescribedObservers = epochs.computePrescribedObserversForEpoch(epochIndex, hashchain)
	local epoch = {
		epochIndex = epochIndex,
		startTimestamp = epochStartTimestamp,
		endTimestamp = epochEndTimestamp,
		distributionTimestamp = epochDistributionTimestamp,
		prescribedObservers = prescribedObservers,
		observations = {
			failureSummaries = {},
			reports = {},
		},
		distributions = {},
	}
	Epochs[epochIndex] = epoch
end

function epochs.saveObservations(observerAddress, reportTxId, failedGatewayAddresses, timestamp)
	local epochIndex = epochs.getEpochIndexForTimestamp(timestamp)
	local epochStartTimestamp, epochEndTimestamp, epochDistributionTimestamp =
		epochs.getEpochTimestampsForIndex(epochIndex)

	-- avoid observations before the previous epoch distribution has occurred, as distributions affect weights of the current epoch
	if timestamp < epochStartTimestamp + epochSettings.distributionDelayMs then
		error("Observations for the current epoch cannot be submitted before: " .. epochDistributionTimestamp)
	end

	local prescribedObservers = epochs.getPrescribedObserversForEpoch(epochIndex)
	if #prescribedObservers == 0 then
		error("No prescribed observers for the current epoch.")
	end

	local observerIndex = utils.findInArray(prescribedObservers, function(prescribedObserver)
		return prescribedObserver.observerAddress == observerAddress
	end)

	local observer = prescribedObservers[observerIndex]

	if observer == nil then
		error("Caller is not a prescribed observer for the current epoch.")
	end

	local observingGateway = gar.getGateway(observer.gatewayAddress)
	if observingGateway == nil then
		error("The associated gateway does not exist in the registry.")
	end

	local epoch = epochs.getEpoch(epochIndex)

	-- check if this is the first report filed in this epoch (TODO: use start or end?)
	if epoch.observations == nil then
		epoch.observations = {
			failureSummaries = {},
			reports = {},
		}
	end

	-- use ipairs as failedGatewayAddresses is an array
	for _, failedGatewayAddress in ipairs(failedGatewayAddresses) do
		local gateway = gar.getGateway(failedGatewayAddress)
		local gatewayPresentDuringEpoch =
			gar.isGatewayActiveBetweenTimestamps(epochStartTimestamp, epochEndTimestamp, gateway)
		if gatewayPresentDuringEpoch then
			-- if there are none, create an array
			if epoch.observations.failureSummaries == nil then
				epoch.observations.failureSummaries = {}
			end
			-- Get the existing set of failed gateways for this observer
			local observersMarkedFailed = epoch.observations.failureSummaries[failedGatewayAddress] or {}

			-- if list of observers who marked failed does not continue current observer than add it
			local alreadyObservedIndex = utils.findInArray(observersMarkedFailed, function(address)
				return address == observingGateway.observerAddress
			end)

			if not alreadyObservedIndex then
				table.insert(observersMarkedFailed, observingGateway.observerAddress)
			end

			epoch.observations.failureSummaries[failedGatewayAddress] = observersMarkedFailed
		end
	end

	-- if reports are not already present, create an array
	if epoch.observations.reports == nil then
		epoch.observations.reports = {}
	end

	epoch.observations.reports[observingGateway.observerAddress] = reportTxId
	-- update the epoch
	Epochs[epochIndex] = epoch
	return epoch.observations
end

-- for testing purposes
function epochs.updateEpochSettings(newSettings)
	epochSettings = newSettings
end

-- Steps
-- 1. Get gateways participated in full epoch based on start and end timestamp
-- 2. Get the prescribed observers for the relevant epoch
-- 3. Calcualte the rewards for the epoch based on protocol balance
-- 4. Allocate 95% of the rewards for passed gateways, 5% for observers - based on total gateways during the epoch and # of prescribed observers
-- 5. Distribute the rewards to the gateways and observers
-- 6. Increment the epoch stats for the gateways
function epochs.distributeRewardsForEpoch(currentTimestamp)
	local epochIndex = epochs.getEpochIndexForTimestamp(currentTimestamp - epochSettings.durationMs) -- go back to previous epoch
	local epoch = epochs.getEpoch(epochIndex)
	if not next(epoch) then
		-- silently return
		print("Not distributing rewards for last epoch.")
		return
	end

	if currentTimestamp < epoch.distributionTimestamp then
		-- silently ignore - Distribution can only occur after the epoch has ended
		print("Distribution can only occur after the epoch has ended")
		return
	end

	local activeGatewayAddresses = gar.getActiveGatewaysBetweenTimestamps(epoch.startTimestamp, epoch.endTimestamp)
	local prescribedObservers = epochs.getPrescribedObserversForEpoch(epochIndex)
	local totalEligibleRewards = math.floor(balances.getBalance(ao.id) * epochSettings.rewardPercentage)
	local gatewayReward = math.floor(totalEligibleRewards * 0.95 / #activeGatewayAddresses)
	local observerReward = math.floor(totalEligibleRewards * 0.05 / #prescribedObservers)

	-- check if already distributed rewards for epoch
	if epoch.distributions.distributionTimestamp then
		print("Rewards already distributed for epoch: " .. epochIndex)
		return -- silently return
	end

	local epochDistributions = {}
	local totalDistribution = 0
	-- use pairs as activeGateways is an array
	for _, gatewayAddress in ipairs(activeGatewayAddresses) do
		local gateway = gar.getGateway(gatewayAddress)

		-- only operate if the gateway is found (it should be )
		if gateway then
			-- check the observations to see if gateway passed, if 50% or more of the observers marked the gateway as failed, it is considered failed
			local observersMarkedFailed = epoch.observations.failureSummaries
					and epoch.observations.failureSummaries[gatewayAddress]
				or {}
			local failed = #observersMarkedFailed > (#prescribedObservers / 2)

			-- if prescribed, we'll update the prescribed stats as well - find if the observer address is in prescribed observers
			local observerIndex = utils.findInArray(prescribedObservers, function(prescribedObserver)
				return prescribedObserver.observerAddress == gateway.observerAddress
			end)

			local observationSubmitted = observerIndex and epoch.observations.reports[gateway.observerAddress] ~= nil
			local updatedStats = {
				totalEpochCount = gateway.stats.totalEpochCount + 1,
				failedEpochCount = failed and gateway.stats.failedEpochCount + 1 or gateway.stats.failedEpochCount,
				failedConsecutiveEpochs = failed and gateway.stats.failedConsecutiveEpochs + 1 or 0,
				passedConsecutiveEpochs = failed and 0 or gateway.stats.passedConsecutiveEpochs + 1,
				passedEpochCount = failed and gateway.stats.passedEpochCount or gateway.stats.passedEpochCount + 1,
				prescribedEpochCount = observerIndex and gateway.stats.prescribedEpochCount + 1 or 0,
				observedEpochCount = observationSubmitted and gateway.stats.observedEpochCount + 1
					or gateway.stats.observedEpochCount,
			}

			-- calcaulte the reward
			local reward = 0

			-- if the gateway passed, i.e. it was not marked as failed it gets the gateway reward
			if not failed then
				reward = gatewayReward
			end

			if observerIndex then
				-- if it submitted observation, it gets the observer reward
				if observationSubmitted then
					reward = reward + observerReward
				else -- if it did not submit observation gets 75% of the gateway reward
					reward = reward * 0.75
				end
			end

			if reward > 0 then
				-- if any delegates are present, distribute the rewards to the delegates
				local distributedToDelegates = 0
				local eligbibleDelegateRewards = math.floor(reward * (gateway.settings.delegateRewardShareRatio / 100))
				-- use pairs as gateway.delegates is map
				for delegateAddress, delegate in pairs(gateway.delegates) do
					if gateway.totalDelegatedStake > 0 then
						local delegateReward = math.floor(
							(delegate.delegatedStake / gateway.totalDelegatedStake) * eligbibleDelegateRewards
						)
						balances.transfer(delegateAddress, ao.id, delegateReward)
						distributedToDelegates = distributedToDelegates + delegateReward
						epochDistributions[delegateAddress] = (epochDistributions[delegateAddress] or 0)
							+ delegateReward
					end
				end
				local remaingOperatorReward = math.floor(reward - distributedToDelegates)
				if remaingOperatorReward > 0 then
					balances.transfer(gatewayAddress, ao.id, remaingOperatorReward)
					-- transfer the rewards to the operator
					if gateway.settings.autoStake then
						gar.increaseOperatorStake(gatewayAddress, remaingOperatorReward)
					end
					-- update the total distributions for the epoch
					epochDistributions[gatewayAddress] = remaingOperatorReward
				end
			end

			-- increment the total distributed
			totalDistribution = math.floor(totalDistribution + reward)
			-- update the gateway
			gar.updateGatewayStats(gatewayAddress, updatedStats)
		end
	end

	-- set the distributions for the epoch
	epoch.distributions = {
		totalEligibleRewards = totalEligibleRewards,
		totalDistributedRewards = totalDistribution,
		distributionTimestamp = currentTimestamp,
		rewards = epochDistributions,
	}

	-- update the epoch
	Epochs[epochIndex] = epoch
end

return epochs
