local constants = require("constants")
local demand = require("demand")

describe("demand", function()
	before_each(function()
		_G.DemandFactor = {
			startTimestamp = 0,
			currentPeriod = 1,
			trailingPeriodPurchases = { 0, 0, 0, 0, 0, 0, 0 },
			trailingPeriodRevenues = { 0, 0, 0, 0, 0, 0 },
			purchasesThisPeriod = 0,
			revenueThisPeriod = 0,
			currentDemandFactor = 1,
			consecutivePeriodsWithMinDemandFactor = 0,
			fees = constants.genesisFees,
		}
		demand.updateSettings({
			movingAvgPeriodCount = 7,
			periodLengthMs = 60 * 1000 * 24, -- one day
			demandFactorBaseValue = 1,
			demandFactorMin = 0.5,
			demandFactorUpAdjustment = 0.05,
			demandFactorDownAdjustment = 0.025,
			stepDownThreshold = 3,
			criteria = "revenue",
		})
	end)

	it("should tally name purchase", function()
		demand.tallyNamePurchase(100)
		assert.are.equal(1, demand.getCurrentPeriodPurchases())
		assert.are.equal(100, demand.getCurrentPeriodRevenue())
	end)

	describe("revenue based criteria", function()
		it("mvgAvgTrailingPurchaseCounts() should calculate moving average of trailing purchase counts", function()
			DemandFactor.trailingPeriodPurchases = { 1, 2, 3, 4, 5, 6, 7 }
			assert.are.equal(4, demand.mvgAvgTrailingPurchaseCounts())
		end)

		it("mvgAvgTrailingRevenues() should calculate moving average of trailing revenues", function()
			DemandFactor.trailingPeriodRevenues = { 1, 2, 3, 4, 5, 6 }
			assert.are.equal(3.5, demand.mvgAvgTrailingRevenues())
		end)

		it("isDemandIncreasing() should return false when demand is is not increasing based on revenue", function()
			DemandFactor.revenueThisPeriod = 0
			DemandFactor.trailingPeriodRevenues = { 0, 10, 10, 10, 10, 10 }
			assert.is_false(demand.isDemandIncreasing())
		end)

		it("isDemandIncreasing() should return true when demand is increasing based on revenue", function()
			DemandFactor.revenueThisPeriod = 10
			DemandFactor.trailingPeriodRevenues = { 10, 0, 0, 0, 0, 0, 0 }
			assert.is_true(demand.isDemandIncreasing())
		end)

		it(
			"updateDemandFactor() should update demand factor if demand is increasing and a new period has started",
			function()
				DemandFactor.revenueThisPeriod = 10
				DemandFactor.trailingPeriodRevenues = { 10, 0, 0, 0, 0, 0, 0 }
				local startNextPeriodTimestamp = demand.getSettings().periodLengthMs + 1
				demand.updateDemandFactor(startNextPeriodTimestamp)
				assert.are.equal(1.05, demand.getDemandFactor())
			end
		)

		it(
			"updateDemandFactor() should update demand factor if demand is decreasing and a new period has started",
			function()
				DemandFactor.revenueThisPeriod = 0
				DemandFactor.trailingPeriodRevenues = { 0, 10, 0, 0, 0, 0, 0 }
				local startNextPeriodTimestamp = demand.getSettings().periodLengthMs + 1
				demand.updateDemandFactor(startNextPeriodTimestamp)
				assert.are.equal(0.9749999999999999778, demand.getDemandFactor())
			end
		)

		it(
			"updateDemandFactor() should increment consecutive periods at minimum and not lower demand factor if demand factor is already at minimum",
			function()
				DemandFactor.currentDemandFactor = 0.5
				DemandFactor.revenueThisPeriod = 0
				DemandFactor.trailingPeriodRevenues = { 0, 10, 10, 10, 10, 10 }
				demand.updateDemandFactor(demand.getSettings().periodLengthMs + 1)
				assert.are.equal(0.5, demand.getDemandFactor())
			end
		)

		it(
			"updateDemandFactor() adjust fees and reset demend factor parameters when consecutive periods at minimum threshold is hit",
			function()
				DemandFactor.currentDemandFactor = demand.getSettings().demandFactorMin
				DemandFactor.consecutivePeriodsWithMinDemandFactor = demand.getSettings().stepDownThreshold
				DemandFactor.revenueThisPeriod = 0
				DemandFactor.trailingPeriodRevenues = { 0, 10, 10, 10, 10, 10 }
				local expectedFees = {}
				local startNextPeriodTimestamp = demand.getSettings().periodLengthMs + 1
				-- use pairs as fees is a map
				for nameLength, fee in pairs(constants.genesisFees) do
					expectedFees[nameLength] = fee * demand.getSettings().demandFactorMin
				end
				demand.updateDemandFactor(startNextPeriodTimestamp)
				assert.are.equal(1, demand.getDemandFactor())
				assert.are.equal(0, demand.getConsecutivePeriodsWithMinDemandFactor())
				assert.are.same(expectedFees, demand.getFees())
			end
		)
	end)

	describe("purchase count criteria", function()
		before_each(function()
			demand.updateSettings({
				movingAvgPeriodCount = 7,
				periodLengthMs = 60 * 1000 * 24, -- one day
				demandFactorBaseValue = 1,
				demandFactorMin = 0.5,
				demandFactorUpAdjustment = 0.05,
				demandFactorDownAdjustment = 0.025,
				stepDownThreshold = 3,
				criteria = "purchases",
			})
		end)

		it("isDemandIncreasing() should return true when demand is increasing for purchases based criteria", function()
			DemandFactor.purchasesThisPeriod = 10
			DemandFactor.trailingPeriodPurchases = { 10, 0, 0, 0, 0, 0, 0 }
			assert.is_true(demand.isDemandIncreasing())
		end)

		it(
			"isDemandIncreasing() should return false when demand is not increasing for purchases based criteria",
			function()
				DemandFactor.purchasesThisPeriod = 0
				DemandFactor.trailingPeriodPurchases = { 0, 10, 10, 10, 10, 10, 10 }
				assert.is_false(demand.isDemandIncreasing())
			end
		)

		it(
			"updateDemandFactor() should update demand factor if demand is increasing and a new period has started",
			function()
				DemandFactor.purchasesThisPeriod = 10
				DemandFactor.trailingPeriodPurchases = { 10, 0, 0, 0, 0, 0, 0 }
				local startNextPeriodTimestamp = demand.getSettings().periodLengthMs + 1
				demand.updateDemandFactor(startNextPeriodTimestamp)
				assert.are.equal(1.05, demand.getDemandFactor())
			end
		)

		it(
			"updateDemandFactor() should update demand factor if demand is decreasing and a new period has started",
			function()
				DemandFactor.purchasesThisPeriod = 0
				DemandFactor.trailingPeriodPurchases = { 0, 10, 0, 0, 0, 0, 0 }
				local startNextPeriodTimestamp = demand.getSettings().periodLengthMs + 1
				demand.updateDemandFactor(startNextPeriodTimestamp)
				assert.are.equal(0.9749999999999999778, demand.getDemandFactor())
			end
		)
	end)
end)
