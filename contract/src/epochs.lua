local gar = require("gar")
local crypto = require("crypto.init")
local utils = require("utils")
local epochs = {}

Epochs = Epochs
	or {
		[0] = {
			startTimestamp = 0,
			endTimestamp = 0,
			distributionTimestamp = 0,
			-- TODO: add settings here
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
	maxObservers = 50,
	epochZeroStartTimestamp = 0,
	durationMs = 60 * 1000 * 60 * 24, -- 24 hours
	distributionDelayMs = 60 * 1000 * 2 * 15, -- 15 blocks
}

function epochs.getEpoch(epochNumber)
	return Epochs[epochNumber]
end

function epochs.getObservers()
	return epochs.getCurrentEpoch().prescribedObservers
end

function epochs.getObservations()
	return epochs.getCurrentEpoch().observations
end

function epochs.getReports()
	return epochs.getObservations().reports
end

function epochs.getDistribution()
	return epochs.getCurrentEpoch().distributions
end

function epochs.getPrescribedObserversForEpoch(epochNumber)
	return epochs.getEpoch(epochNumber).prescribedObservers
end

function epochs.getReportsForEpoch(epochNumber)
	return epochs.getEpoch(epochNumber).observations.reports
end

function epochs.getDistributionForEpoch(epochNumber)
	return epochs.getEpoch(epochNumber).distributions
end

function epochs.getEpochFromTimestamp(timestamp)
	local epochIndex = epochs.getEpochIndexForTimestamp(timestamp)
	return epochs.getEpoch(epochIndex)
end
function epochs.setPrescribedObserversForEpoch(epochNumber, hashchain)
	local prescribedObservers = epochs.computePrescribedObserversForEpoch(epochNumber, hashchain)
	epochs.getEpoch(epochNumber).prescribedObservers = prescribedObservers
end

function epochs.computePrescribedObserversForEpoch(epochIndex, hashchain)
	local epochStartTimestamp, epochEndTimestamp = epochs.getEpochTimestampsForIndex(epochIndex)
	local eligibleGateways = gar.getEligibleGatewaysForTimestamps(epochStartTimestamp, epochEndTimestamp)
	local weightedObservers = gar.getObserverWeightsAtTimestamp(eligibleGateways, epochStartTimestamp)
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

function epochs.getEpochTimestampsForIndex(epochIndex)
	local epochStartTimestamp = epochSettings.epochZeroStartTimestamp + epochSettings.durationMs * epochIndex
	local epochEndTimestamp = epochStartTimestamp + epochSettings.durationMs
	local epochDistributionTimestamp = epochEndTimestamp + epochSettings.distributionDelayMs
	return epochStartTimestamp, epochEndTimestamp, epochDistributionTimestamp, epochIndex
end

function epochs.getEpochIndexForTimestamp(timestamp)
	local epochZeroStartTimestamp = epochSettings.epochZeroStartTimestamp
	local epochLengthMs = epochSettings.durationMs
	local epochIndex = math.floor((timestamp - epochZeroStartTimestamp) / epochLengthMs)
	return epochIndex
end

function epochs.createEpochForTimestamp(timestamp)
	local epochIndex = epochs.getEpochIndexForTimestamp(timestamp)
	if Epochs[epochIndex] then
		error("Epoch already exists")
	end
	local epochStartTimestamp, epochEndTimestamp, epochDistributionTimestamp, epochIndex =
		epochs.getEpochTimestampsForIndex(epochIndex)
	local epoch = {
		startTimestamp = epochStartTimestamp,
		endTimestamp = epochEndTimestamp,
		distributionTimestamp = epochDistributionTimestamp,
		observations = {
			failureSummaries = {},
			reports = {},
		},
		prescribedObservers = {},
		distributions = {},
	}
	Epochs[epochIndex] = epoch
	GatewayRegistry.epoch = epochIndex
end

function epochs.saveObservations(from, reportTxId, failedGateways, timestamp)
	local epochIndex = epochs.getEpochIndexForTimestamp(timestamp)
	local epochStartTimestamp, epochEndTimestamp, epochDistributionTimestamp, epochIndex =
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
		local gatewayPresentDuringEpoch =
			gar.isGatewayActiveBetweenTimestamps(epochStartTimestamp, epochEndTimestamp, failedGateway)
		if gatewayPresentDuringEpoch then
			-- if there are none, create an array
			if Epochs[epochIndex].observations.failureSummaries == nil then
				Epochs[epochIndex].observations.failureSummaries = {}
			end
			-- Get the existing set of failed gateways for this observer
			local observersMarkedFailed = Epochs[epochIndex].observations.failureSummaries[failedGatewayAddress] or {}

			-- if list of observers who marked failed does not continue current observer than add it
			local alreadyObservedIndex = utils.findInArray(observersMarkedFailed, function(observer)
				return observer == observingGateway.observerAddress
			end)

			if not alreadyObservedIndex then
				table.insert(observersMarkedFailed, observingGateway.observerAddress)
			end

			Epochs[epochIndex].observations.failureSummaries[failedGatewayAddress] = observersMarkedFailed
		end
	end

	-- if reports are not already present, create an array
	if Epochs[epochIndex].observations.reports == nil then
		Epochs[epochIndex].observations.reports = {}
	end

	Epochs[epochIndex].observations.reports[observingGateway.observerAddress] = reportTxId
	return Epochs[epochIndex].observations
end

-- for testing purposes
function epochs.updateEpochSettings(newSettings)
	epochSettings = newSettings
end

return epochs
