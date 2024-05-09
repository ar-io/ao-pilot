local constants = require "constants"
local demand = { 
	_version = "0.0.1" ,
	startTimestamp = os.clock(), -- TODO: The timestamp at which the contract was initialized
	currentPeriod = 1, -- TODO: the # of days since the last demand factor adjustment
	trailingPeriodPurchases = { 0, 0, 0, 0, 0, 0, 0 }, -- Acts as a ring buffer of trailing period purchase counts
	trailingPeriodRevenues = { 0, 0, 0, 0, 0, 0 }, -- Acts as a ring buffer of trailing period revenues
	purchasesThisPeriod = 0,
	revenueThisPeriod = 0,
	currentDemandFactor = 1,
	consecutivePeriodsWithMinDemandFactor = 0,
	settings = constants.DEMAND_SETTINGS,
	fees = constants.genesisFees
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
function demand.shouldUpdateDemandFactor(timestamp)
	local calculatedPeriod = math.floor((timestamp - demand.startTimestamp) / demand.settings.periodLengthMs) + 1
	return calculatedPeriod > demand.currentPeriod
end

function demand.updateDemandFactor(timestamp)
	if not demand.shouldUpdateDemandFactor(timestamp) then
		return
	end

	if demand.isDemandIncreasing() then
		demand.demandFactor = demand.demandFactor * (1 + demand.demand.settings.demandFactorUpAdjustment)
	else
		if demand.demandFactor > demand.settings.demandFactorMin then
			demand.demandFactor = demand.currentDemandFactor * (1 - demand.settings.demandFactorDownAdjustment)
		end
	end

	if demand.demandFactor == demand.settings.demandFactorMin then
		if demand.consecutivePeriodsWithMinDemandFactor >= demand.settings.stepDownThreshold then
			demand.consecutivePeriodsWithMinDemandFactor = 0
			demand.demandFactor = demand.settings.demandFactorBaseValue
			demand.fees.updateFees(demand.settings.demandFactorMin)
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

function demand.getDemandFactor()
	return demand.currentDemandFactor
end

return demand
