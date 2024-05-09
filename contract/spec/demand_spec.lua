local constants = require("constants")
local demand = require("demand")

describe("demand", function()

	it("should tally name purchase", function()
		demand.tallyNamePurchase(1)
		assert.are.equal(1, demand.purchasesThisPeriod)
		assert.are.equal(1, demand.revenueThisPeriod)
	end)

	it("should calculate moving average of trailing purchase counts", function()
		demand.trailingPeriodPurchases = { 1, 2, 3, 4, 5, 6, 7 }
		assert.are.equal(4, demand.mvgAvgTrailingPurchaseCounts())
	end)

	it("should calculate moving average of trailing revenues", function()
		demand.trailingPeriodRevenues = { 1, 2, 3, 4, 5, 6 }
		assert.are.equal(3.5, demand.mvgAvgTrailingRevenues())
	end)

	it("should return true when demand is increasing based on revenue", function()
		demand.revenueThisPeriod = 10
		demand.trailingPeriodRevenues = { 10, 0, 0, 0, 0, 0, 0 }
		assert.is_true(demand.isDemandIncreasing())
	end)

	it("should return false when demand is is not increasing based on revenue", function()
		demand.revenueThisPeriod = 0
		demand.trailingPeriodRevenues = { 0, 10, 10, 10, 10, 10 }
		assert.is_false(demand.isDemandIncreasing())
	end)

	it("should return true when demand is increasing for purchases based criteria", function()
		demand.settings.criteria = 'purchases'
		demand.purchasesThisPeriod = 10
		demand.trailingPeriodPurchases = { 10, 0, 0, 0, 0, 0, 0 }
		assert.is_true(demand.isDemandIncreasing())
	end)

	it("should return false when demand is not increasing for purchases based criteria", function()
		demand.criteria = 'purchases'
		demand.purchasesThisPeriod = 0
		demand.trailingPeriodPurchases = { 0, 10, 10, 10, 10, 10, 10 }
		assert.is_false(demand.isDemandIncreasing())
	end)

	it("should update demand factor if timestamp is greater than period length", function()
		local currentTimestamp = constants.DEMAND_SETTINGS.periodLengthMs + 1
		assert.is_true(demand.shouldUpdateDemandFactor(currentTimestamp))
	end)

	it("should not update demand factor if timestamp is less than period length", function()
		local currentTimestamp = constants.DEMAND_SETTINGS.periodLengthMs - 1
		assert.is_false(demand.shouldUpdateDemandFactor(currentTimestamp))
	end)
end)
