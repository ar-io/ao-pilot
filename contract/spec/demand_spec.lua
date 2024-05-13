local constants = require("constants")
local demand = require("demand")

describe("demand", function()
	before_each(function()
		demand.startTimestamp = 0
		demand.currentPeriod = 1
		demand.trailingPeriodPurchases = { 0, 0, 0, 0, 0, 0, 0 }
		demand.trailingPeriodRevenues = { 0, 0, 0, 0, 0, 0 }
		demand.purchasesThisPeriod = 0
		demand.revenueThisPeriod = 0
		demand.currentDemandFactor = 1
		demand.consecutivePeriodsWithMinDemandFactor = 0
		demand.settings = constants.demandSettings
		demand.fees = constants.genesisFees
	end)

	it("should tally name purchase", function()
		demand.tallyNamePurchase(1)
		assert.are.equal(1, demand.purchasesThisPeriod)
		assert.are.equal(1, demand.revenueThisPeriod)
	end)

	describe("revenue based criteria", function()
		it("mvgAvgTrailingPurchaseCounts() should calculate moving average of trailing purchase counts", function()
			demand.trailingPeriodPurchases = { 1, 2, 3, 4, 5, 6, 7 }
			assert.are.equal(4, demand.mvgAvgTrailingPurchaseCounts())
		end)

		it("mvgAvgTrailingRevenues() should calculate moving average of trailing revenues", function()
			demand.trailingPeriodRevenues = { 1, 2, 3, 4, 5, 6 }
			assert.are.equal(3.5, demand.mvgAvgTrailingRevenues())
		end)

		it("isDemandIncreasing() should return false when demand is is not increasing based on revenue", function()
			demand.revenueThisPeriod = 0
			demand.trailingPeriodRevenues = { 0, 10, 10, 10, 10, 10 }
			assert.is_false(demand.isDemandIncreasing())
		end)

		it("isDemandIncreasing() should return true when demand is increasing based on revenue", function()
			demand.revenueThisPeriod = 10
			demand.trailingPeriodRevenues = { 10, 0, 0, 0, 0, 0, 0 }
			assert.is_true(demand.isDemandIncreasing())
		end)

		it(
			"updateDemandFactor() should update demand factor if demand is increasing and a new period has started",
			function()
				demand.revenueThisPeriod = 10
				demand.trailingPeriodRevenues = { 10, 0, 0, 0, 0, 0, 0 }
				demand.updateDemandFactor(demand.settings.periodLengthMs + 1)
				assert.are.equal(1.05, demand.getDemandFactor())
			end
		)

		it(
			"updateDemandFactor() should update demand factor if demand is decreasing and a new period has started",
			function()
				demand.revenueThisPeriod = 0
				demand.trailingPeriodRevenues = { 0, 10, 0, 0, 0, 0, 0 }
				demand.updateDemandFactor(demand.settings.periodLengthMs + 1)
				assert.are.equal(0.9749999999999999778, demand.getDemandFactor())
			end
		)

		it(
			"updateDemandFactor() should increment consecutive periods at minimum and not lower demand factor if demand factor is already at minimum",
			function()
				demand.currentDemandFactor = 0.5
				demand.revenueThisPeriod = 0
				demand.trailingPeriodRevenues = { 0, 10, 10, 10, 10, 10 }
				demand.updateDemandFactor(demand.settings.periodLengthMs + 1)
				assert.are.equal(0.5, demand.currentDemandFactor)
			end
		)

		it(
			"updateDemandFactor() adjust fees and reset demend factor parameters when consecutive periods at minimum threshold is hit",
			function()
				demand.currentDemandFactor = 0.5
				demand.consecutivePeriodsWithMinDemandFactor = 5
				demand.revenueThisPeriod = 0
				demand.trailingPeriodRevenues = { 0, 10, 10, 10, 10, 10 }
				local expectedFees = {}
				for nameLength, fee in pairs(constants.genesisFees) do
					expectedFees[nameLength] = fee * demand.settings.demandFactorMin
				end
				demand.updateDemandFactor(demand.settings.periodLengthMs + 1)
				assert.are.equal(1, demand.currentDemandFactor)
				assert.are.equal(0, demand.consecutivePeriodsWithMinDemandFactor)
				assert.are.same(expectedFees, demand.fees)
			end
		)
	end)

	describe("purchase count criteria", function()
		before_each(function()
			demand.settings.criteria = "purchases"
		end)

		it("isDemandIncreasing() should return true when demand is increasing for purchases based criteria", function()
			demand.settings.criteria = "purchases"
			demand.purchasesThisPeriod = 10
			demand.trailingPeriodPurchases = { 10, 0, 0, 0, 0, 0, 0 }
			assert.is_true(demand.isDemandIncreasing())
		end)

		it(
			"isDemandIncreasing() should return false when demand is not increasing for purchases based criteria",
			function()
				demand.settings.criteria = "purchases"
				demand.purchasesThisPeriod = 0
				demand.trailingPeriodPurchases = { 0, 10, 10, 10, 10, 10, 10 }
				assert.is_false(demand.isDemandIncreasing())
			end
		)

		it(
			"updateDemandFactor() should update demand factor if demand is increasing and a new period has started",
			function()
				demand.purchasesThisPeriod = 10
				demand.trailingPeriodPurchases = { 10, 0, 0, 0, 0, 0, 0 }
				demand.updateDemandFactor(demand.settings.periodLengthMs + 1)
				assert.are.equal(1.05, demand.getDemandFactor())
			end
		)

		it(
			"updateDemandFactor() should update demand factor if demand is decreasing and a new period has started",
			function()
				demand.purchasesThisPeriod = 0
				demand.trailingPeriodPurchases = { 0, 10, 0, 0, 0, 0, 0 }
				demand.updateDemandFactor(demand.settings.periodLengthMs + 1)
				assert.are.equal(0.9749999999999999778, demand.getDemandFactor())
			end
		)
	end)
end)
