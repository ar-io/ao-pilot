local constants = require("constants")
local demand = {}

DemandFactor = DemandFactor
	or {
		startTimestamp = 0, -- TODO: The timestamp at which the contract was initialized
		currentPeriod = 0, -- TODO: the # of days since the last demand factor adjustment
		trailingPeriodPurchases = { 0, 0, 0, 0, 0, 0, 0 }, -- Acts as a ring buffer of trailing period purchase counts
		trailingPeriodRevenues = { 0, 0, 0, 0, 0, 0 }, -- Acts as a ring buffer of trailing period revenues
		purchasesThisPeriod = 0,
		revenueThisPeriod = 0,
		currentDemandFactor = 1,
		consecutivePeriodsWithMinDemandFactor = 0,
		fees = constants.genesisFees,
	}

local demandFactorSettings = {
	movingAvgPeriodCount = 7,
	periodLengthMs = 60 * 1000 * 24, -- one day
	demandFactorBaseValue = 1,
	demandFactorMin = 0.5,
	demandFactorUpAdjustment = 0.05,
	demandFactorDownAdjustment = 0.025,
	stepDownThreshold = 3,
	criteria = "revenue",
}

function demand.tallyNamePurchase(qty)
	demand.incrementPurchasesThisPeriodRevenue(1)
	demand.incrementRevenueThisPeriod(qty)
end

function demand.mvgAvgTrailingPurchaseCounts()
	local sum = 0
	local trailingPeriodPurchases = demand.getTrailingPeriodPurchases()
	for i = 1, #trailingPeriodPurchases do
		sum = sum + trailingPeriodPurchases[i]
	end
	return sum / #trailingPeriodPurchases
end

function demand.mvgAvgTrailingRevenues()
	local sum = 0
	local trailingPeriodRevenues = demand.getTrailingPeriodRevenues()
	for i = 1, #trailingPeriodRevenues do
		sum = sum + trailingPeriodRevenues[i]
	end
	return sum / #trailingPeriodRevenues
end

function demand.isDemandIncreasing()
	local currentPeriod = demand.getCurrentPeriod()
	local settings = demand.getSettings()
	local purchasesLastPeriod = demand.getTrailingPeriodPurchases()[currentPeriod]
	local revenueInLastPeriod = demand.getTrailingPeriodRevenues()[currentPeriod]
	local mvgAvgOfTrailingNamePurchases = demand.mvgAvgTrailingPurchaseCounts()
	local mvgAvgOfTrailingRevenue = demand.mvgAvgTrailingRevenues()

	if settings.criteria == "revenue" then
		return revenueInLastPeriod > 0 and revenueInLastPeriod > mvgAvgOfTrailingRevenue
	else
		return purchasesLastPeriod > 0 and purchasesLastPeriod > mvgAvgOfTrailingNamePurchases
	end
end

-- update at the end of the demand if the current timestamp results in a period greater than our current state
function demand.shouldUpdateDemandFactor(currentTimestamp)
	local settings = demand.getSettings()
	local calculatedPeriod = math.floor((currentTimestamp - DemandFactor.startTimestamp) / settings.periodLengthMs) + 1
	return calculatedPeriod > demand.getCurrentPeriod()
end

function demand.updateDemandFactor(timestamp)
	if not demand.shouldUpdateDemandFactor(timestamp) then
		return
	end

	local settings = demand.getSettings()

	if demand.isDemandIncreasing() then
		local upAdjustment = settings.demandFactorUpAdjustment
		demand.setDemandFactor(demand.getDemandFactor() * (1 + upAdjustment))
	else
		if demand.getDemandFactor() > settings.demandFactorMin then
			local downAdjustment = settings.demandFactorDownAdjustment
			local updatedDemandFactor = demand.getDemandFactor() * (1 - downAdjustment)
			demand.setDemandFactor(updatedDemandFactor)
		end
	end

	if demand.getDemandFactor() == settings.demandFactorMin then
		if demand.getConsecutivePeriodsWithMinDemandFactor() >= settings.stepDownThreshold then
			demand.resetConsecutivePeriodsWithMinimumDemandFactor()
			demand.updateFees(settings.demandFactorMin)
			demand.setDemandFactor(settings.demandFactorBaseValue)
		else
			demand.incrementConsecutivePeriodsWithMinDemandFactor(1)
		end
	end

	demand.incrementPeriodAndResetValues()
end

function demand.updateFees(multiplier)
	local currentFees = demand.getFees()
	-- update all fees multiply them by the demand factor minimim
	for nameLength, fee in pairs(currentFees) do
		local updatedFee = fee * multiplier
		DemandFactor.fees[nameLength] = updatedFee
	end
end

function demand.getDemandFactor()
	return DemandFactor.currentDemandFactor
end

function demand.getCurrentPeriodRevenue()
	return DemandFactor.revenueThisPeriod
end

function demand.getCurrentPeriodPurchases()
	return DemandFactor.purchasesThisPeriod
end

function demand.getTrailingPeriodPurchases()
	return DemandFactor.trailingPeriodPurchases
end

function demand.getTrailingPeriodRevenues()
	return DemandFactor.trailingPeriodRevenues
end

function demand.getFees()
	return DemandFactor.fees
end

function demand.getSettings()
	return demandFactorSettings
end

function demand.getConsecutivePeriodsWithMinDemandFactor()
	return DemandFactor.consecutivePeriodsWithMinDemandFactor
end

function demand.getCurrentPeriod()
	return DemandFactor.currentPeriod
end

function demand.updateSettings(settings)
	demandFactorSettings = settings
end

function demand.updateStartTimestamp(timestamp)
	DemandFactor.startTimestamp = timestamp
end

function demand.updateCurrentPeriod(period)
	DemandFactor.currentPeriod = period
end

function demand.setDemandFactor(demandFactor)
	DemandFactor.currentDemandFactor = demandFactor
end
function demand.updateTrailingPeriodPurchases()
	local currentPeriod = demand.getCurrentPeriod()
	DemandFactor.trailingPeriodPurchases[currentPeriod] = demand.getCurrentPeriodPurchases()
end

function demand.updateTrailingPeriodRevenues()
	local currentPeriod = demand.getCurrentPeriod()
	DemandFactor.trailingPeriodRevenues[currentPeriod] = demand.getCurrentPeriodRevenue()
end

function demand.resetPurchasesThisPeriod()
	DemandFactor.purchasesThisPeriod = 0
end

function demand.resetRevenueThisPeriod()
	DemandFactor.revenueThisPeriod = 0
end

function demand.incrementPurchasesThisPeriodRevenue(count)
	DemandFactor.purchasesThisPeriod = DemandFactor.purchasesThisPeriod + count
end

function demand.incrementRevenueThisPeriod(revenue)
	DemandFactor.revenueThisPeriod = DemandFactor.revenueThisPeriod + revenue
end

function demand.updateRevenueThisPeriod(revenue)
	DemandFactor.revenueThisPeriod = revenue
end

function demand.incrementCurrentPeriod(count)
	DemandFactor.currentPeriod = DemandFactor.currentPeriod + count
end

function demand.resetConsecutivePeriodsWithMinimumDemandFactor()
	DemandFactor.consecutivePeriodsWithMinDemandFactor = 0
end

function demand.incrementConsecutivePeriodsWithMinDemandFactor(count)
	DemandFactor.consecutivePeriodsWithMinDemandFactor = DemandFactor.consecutivePeriodsWithMinDemandFactor + count
end

function demand.incrementPeriodAndResetValues()
	demand.resetConsecutivePeriodsWithMinimumDemandFactor()
	demand.resetPurchasesThisPeriod()
	demand.resetRevenueThisPeriod()
	demand.incrementCurrentPeriod(1)
end

return demand
