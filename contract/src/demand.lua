local constants = require("constants")
local demand = Demand
	or {
		startTimestamp = 0, -- TODO: The timestamp at which the contract was initialized
		currentPeriod = 1, -- TODO: the # of days since the last demand factor adjustment
		trailingPeriodPurchases = { 0, 0, 0, 0, 0, 0, 0 }, -- Acts as a ring buffer of trailing period purchase counts
		trailingPeriodRevenues = { 0, 0, 0, 0, 0, 0 }, -- Acts as a ring buffer of trailing period revenues
		purchasesThisPeriod = 0,
		revenueThisPeriod = 0,
		currentDemandFactor = 1,
		consecutivePeriodsWithMinDemandFactor = 0,
		settings = constants.demandSettings,
		fees = constants.genesisFees,
	}

function demand.tallyNamePurchase(qty)
	demand.purchasesThisPeriod = demand.purchasesThisPeriod + 1
	demand.revenueThisPeriod = demand.revenueThisPeriod + qty
end

function demand.mvgAvgTrailingPurchaseCounts()
	local sum = 0
	for i = 1, #demand.trailingPeriodPurchases do
		sum = sum + demand.trailingPeriodPurchases[i]
	end
	return sum / #demand.trailingPeriodPurchases
end

function demand.mvgAvgTrailingRevenues()
	local sum = 0
	for i = 1, #demand.trailingPeriodRevenues do
		sum = sum + demand.trailingPeriodRevenues[i]
	end
	return sum / #demand.trailingPeriodRevenues
end

function demand.isDemandIncreasing()
	local purchasesLastPeriod = demand.trailingPeriodPurchases[demand.currentPeriod]
	local revenueInLastPeriod = demand.trailingPeriodRevenues[demand.currentPeriod]
	local mvgAvgOfTrailingNamePurchases = demand.mvgAvgTrailingPurchaseCounts()
	local mvgAvgOfTrailingRevenue = demand.mvgAvgTrailingRevenues()

	if demand.settings.criteria == "revenue" then
		return revenueInLastPeriod > 0 and revenueInLastPeriod > mvgAvgOfTrailingRevenue
	else
		return purchasesLastPeriod > 0 and purchasesLastPeriod > mvgAvgOfTrailingNamePurchases
	end
end

-- update at the end of the demand if the current timestamp results in a period greater than our current state
function demand.shouldUpdateDemandFactor(currentTimestamp)
	local calculatedPeriod = math.floor((currentTimestamp - demand.startTimestamp) / demand.settings.periodLengthMs) + 1
	return calculatedPeriod > demand.currentPeriod
end

function demand.updateDemandFactor(timestamp)
	if not demand.shouldUpdateDemandFactor(timestamp) then
		return
	end

	if demand.isDemandIncreasing() then
		demand.currentDemandFactor = demand.currentDemandFactor * (1 + demand.settings.demandFactorUpAdjustment)
	else
		if demand.currentDemandFactor > demand.settings.demandFactorMin then
			demand.currentDemandFactor = demand.currentDemandFactor * (1 - demand.settings.demandFactorDownAdjustment)
		end
	end

	if demand.currentDemandFactor == demand.settings.demandFactorMin then
		if demand.consecutivePeriodsWithMinDemandFactor >= demand.settings.stepDownThreshold then
			demand.consecutivePeriodsWithMinDemandFactor = 0
			demand.currentDemandFactor = demand.settings.demandFactorBaseValue
			demand.updateFees()
		end
	else
		demand.consecutivePeriodsWithMinDemandFactor = 0
	end

	demand.trailingPeriodPurchases[demand.currentPeriod] = demand.purchasesThisPeriod
	demand.trailingPeriodRevenues[demand.currentPeriod] = demand.revenueThisPeriod
	demand.currentPeriod = demand.currentPeriod + 1
	demand.purchasesThisPeriod = 0
	demand.revenueThisPeriod = 0
	return
end

function demand.updateFees()
	-- update all fees multiply them by the demand factor minimim
	for nameLength, fee in pairs(demand.fees) do
		local updatedFee = fee * demand.settings.demandFactorMin
		demand.fees[nameLength] = updatedFee
	end
end

function demand.getDemandFactor()
	return demand.currentDemandFactor
end

function demand.getCurrentPeriodRevenue()
	return demand.revenueThisPeriod
end

function demand.getCurrentPeriodPurchases()
	return demand.purchasesThisPeriod
end

return demand
