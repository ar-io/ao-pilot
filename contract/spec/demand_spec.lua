require("demand")
local constants = require("constants")

describe("demand", function()
	local fees = Fees:new(constants.genesisFees)
	local settings = constants.DEMAND_SETTINGS

	it("should tally name purchase", function()
		local df = DemandFactor:new(settings, fees)
		df:tallyNamePurchase(1)
		assert.are.equal(1, df.purchasesThisPeriod)
		assert.are.equal(1, df.revenueThisPeriod)
	end)

	it("should calculate moving average of trailing purchase counts", function()
		local df = DemandFactor:new(settings, fees)
		df.trailingPeriodPurchases = { 1, 2, 3, 4, 5, 6, 7 }
		assert.are.equal(4, df:mvgAvgTrailingPurchaseCounts())
	end)

	it("should calculate moving average of trailing revenues", function()
		local df = DemandFactor:new(settings, fees)
		df.trailingPeriodRevenues = { 1, 2, 3, 4, 5, 6 }
		assert.are.equal(3.5, df:mvgAvgTrailingRevenues())
	end)

	it("should return true when demand is increasing based on revenue", function()
		local df = DemandFactor:new(settings, fees)
		df.revenueThisPeriod = 10
		df.trailingPeriodRevenues = { 10, 0, 0, 0, 0, 0, 0 }
		assert.is_true(df:isDemandIncreasing())
	end)

	it("should return false when demand is is not increasing based on revenue", function()
		local df = DemandFactor:new(settings, fees)
		df.revenueThisPeriod = 0
		df.trailingPeriodRevenues = { 0, 10, 10, 10, 10, 10 }
		assert.is_false(df:isDemandIncreasing())
	end)

	it("should return true when demand is increasing for purchases based criteria", function()
		local df = DemandFactor:new({
			movingAvgPeriodCount = 7,
			periodLengthMs = 60 * 1000 * 24, -- one day
			demandFactorBaseValue = 1,
			demandFactorMin = 0.5,
			demandFactorUpAdjustment = 0.05,
			demandFactorDownAdjustment = 0.025,
			stepDownThreshold = 3,
			criteria = "purchases", -- only difference
		}, fees)
		df.purchasesThisPeriod = 10
		df.trailingPeriodPurchases = { 10, 0, 0, 0, 0, 0, 0 }
		assert.is_true(df:isDemandIncreasing())
	end)

	it("should return false when demand is not increasing for purchases based criteria", function()
		local df = DemandFactor:new({
			movingAvgPeriodCount = 7,
			periodLengthMs = 60 * 1000 * 24, -- one day
			demandFactorBaseValue = 1,
			demandFactorMin = 0.5,
			demandFactorUpAdjustment = 0.05,
			demandFactorDownAdjustment = 0.025,
			stepDownThreshold = 3,
			criteria = "purchases", -- only difference
		}, fees)
		df.purchasesThisPeriod = 0
		df.trailingPeriodPurchases = { 0, 10, 10, 10, 10, 10, 10 }
		assert.is_false(df:isDemandIncreasing())
	end)

	it("should update demand factor if timestamp is greater than period length", function()
		local df = DemandFactor:new(settings, fees)
		local currentTimestamp = settings.periodLengthMs + 1
		assert.is_true(df:shouldUpdateDemandFactor(currentTimestamp))
	end)

	it("should not update demand factor if timestamp is less than period length", function()
		local df = DemandFactor:new(settings, fees)
		local currentTimestamp = settings.periodLengthMs - 1
		local calculated = math.floor((currentTimestamp - df.startTimestamp) / df.settings.periodLengthMs) + 1
		assert.is_false(df:shouldUpdateDemandFactor(currentTimestamp))
	end)
end)
