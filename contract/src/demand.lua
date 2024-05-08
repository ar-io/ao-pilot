local demand = { _version = "0.0.1" }


Fees = {}
Fees.__index = Fees

function Fees:new(genesisFees)
	local fees = {} -- our new object
	setmetatable(fees, Fees) -- make Account handle lookup
	fees = genesisFees
	return fees
end

function Fees:updateFees(demandFactor)
	for i = 1, #self do
		self[i] = self[i] * demandFactor
	end
end

DemandFactor = {}
DemandFactor.__index = DemandFactor

function DemandFactor:new(settings, fees)
	local self = setmetatable({}, DemandFactor) -- make DemandFactor lookup table
	self.startTimestamp = os.clock() -- TODO: The timestamp at which the contract was initialized
	self.currentPeriod = 1 -- TODO: the # of days since the last demand factor adjustment
	self.trailingPeriodPurchases = { 0, 0, 0, 0, 0, 0, 0 } -- Acts as a ring buffer of trailing period purchase counts
	self.trailingPeriodRevenues = { 0, 0, 0, 0, 0, 0 } -- Acts as a ring buffer of trailing period revenues
	self.purchasesThisPeriod = 0
	self.revenueThisPeriod = 0
	self.currentDemandFactor = 1
	self.consecutivePeriodsWithMinDemandFactor = 0
	self.settings = settings
	self.fees = fees
	return self
end

function DemandFactor:tallyNamePurchase(qty)
	self.purchasesThisPeriod = self.purchasesThisPeriod + 1
	self.revenueThisPeriod = self.revenueThisPeriod + qty
end

function DemandFactor:mvgAvgTrailingPurchaseCounts()
	local sum = 0
	for i = 1, #self.trailingPeriodPurchases do
		sum = sum + self.trailingPeriodPurchases[i]
	end
	return sum / #self.trailingPeriodPurchases
end

function DemandFactor:mvgAvgTrailingRevenues()
	local sum = 0
	for i = 1, #self.trailingPeriodRevenues do
		sum = sum + self.trailingPeriodRevenues[i]
	end
	return sum / #self.trailingPeriodRevenues
end

function DemandFactor:isDemandIncreasing()
	local purchasesLastPeriod = self.trailingPeriodPurchases[self.currentPeriod]
	local revenueInLastPeriod = self.trailingPeriodRevenues[self.currentPeriod]
	local mvgAvgOfTrailingNamePurchases = self:mvgAvgTrailingPurchaseCounts()
	local mvgAvgOfTrailingRevenue = self:mvgAvgTrailingRevenues()

	if self.settings.criteria == "revenue" then
		return revenueInLastPeriod > 0 and revenueInLastPeriod > mvgAvgOfTrailingRevenue
	else
		return purchasesLastPeriod > 0 and purchasesLastPeriod > mvgAvgOfTrailingNamePurchases
	end
end

-- update at the end of the demand if the current timestamp results in a period greater than our current state
function DemandFactor:shouldUpdateDemandFactor(timestamp)
	local calculatedPeriod = math.floor((timestamp - self.startTimestamp) / self.settings.periodLengthMs) + 1
	return calculatedPeriod > self.currentPeriod
end

function DemandFactor:updateDemandFactor(timestamp)
	if not self:shouldUpdateDemandFactor(timestamp) then
		return
	end

	if self:isDemandIncreasing() then
		self.demandFactor = self.demandFactor * (1 + self.self.settings.demandFactorUpAdjustment)
	else
		if self.demandFactor > self.settings.demandFactorMin then
			self.demandFactor = self.currentDemandFactor * (1 - self.settings.demandFactorDownAdjustment)
		end
	end

	if self.demandFactor == self.settings.demandFactorMin then
		if self.consecutivePeriodsWithMinDemandFactor >= self.settings.stepDownThreshold then
			self.consecutivePeriodsWithMinDemandFactor = 0
			self.demandFactor = self.settings.demandFactorBaseValue
			self.fees.updateFees(self.settings.demandFactorMin)
		end
	else
		self.consecutivePeriodsWithMinDemandFactor = 0
	end

	self.trailingPeriodPurchases[self.currentPeriod] = self.purchasesThisPeriod
	self.trailingPeriodRevenues[self.currentPeriod] = self.revenueThisPeriod
	self.currentPeriod = self.currentPeriod + 1
	self.purchasesThisPeriod = 0
	self.revenueThisPeriod = 0
	return
end

function DemandFactor:getDemandFactor()
	return self.currentDemandFactor
end

return demand
