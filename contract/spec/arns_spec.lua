local testProcessId = "NdZ3YRwMB2AMwwFYjKn1g88Y9nRybTo0qhS1ORq_E7g"
local constants = require("constants")
local arns = require("arns")
local balances = require("balances")
local demand = require("demand")

describe("arns", function()
	local timestamp = 0
	-- stub out the global state for these tests
	before_each(function()
		_G.NameRegistry = {
			records = {},
			reserved = {},
		}
		Balances = {
			Bob = 5000000,
		}
	end)

	describe("buyRecord", function()
		it("should add a valid lease buyRecord to records objec and transfer balance to the protocol", function()
			local demandBefore = demand.getCurrentPeriodRevenue()
			local purchasesBefore = demand.getCurrentPeriodPurchases()
			local status, result = pcall(arns.buyRecord, "test-name", "lease", 1, "Bob", timestamp, testProcessId)
			assert.is_true(status)
			assert.are.same({
				purchasePrice = 1500,
				type = "lease",
				undernameCount = 10,
				processId = testProcessId,
				startTimestamp = 0,
				endTimestamp = timestamp + constants.oneYearMs * 1,
			}, result)
			assert.are.same({
				["test-name"] = {
					purchasePrice = 1500,
					type = "lease",
					undernameCount = 10,
					processId = testProcessId,
					startTimestamp = 0,
					endTimestamp = timestamp + constants.oneYearMs * 1,
				},
			}, arns.records)
			assert.are.equal(balances.getBalance("Bob"), 4998500)
			assert.are.equal(balances.getBalance(_G.ao.id), 1500)
			assert.are.equal(demandBefore + 1500, demand.getCurrentPeriodRevenue())
			assert.are.equal(purchasesBefore + 1, demand.getCurrentPeriodPurchases())
		end)

		it("should default lease to 1 year and lease when not values are not provided", function()
			local demandBefore = demand.getCurrentPeriodRevenue()
			local purchasesBefore = demand.getCurrentPeriodPurchases()
			local status, result = pcall(arns.buyRecord, "test-name", nil, nil, "Bob", timestamp, testProcessId)
			assert.is_true(status)
			assert.are.same({
				purchasePrice = 1500,
				type = "lease",
				undernameCount = 10,
				processId = testProcessId,
				startTimestamp = 0,
				endTimestamp = timestamp + constants.oneYearMs,
			}, result)
			assert.are.same({
				purchasePrice = 1500,
				type = "lease",
				undernameCount = 10,
				processId = testProcessId,
				startTimestamp = 0,
				endTimestamp = timestamp + constants.oneYearMs,
			}, arns.getRecord("test-name"))
			assert.are.same({
				["Bob"] = 4998500,
				[_G.ao.id] = 1500,
			}, balances.getBalances())
			assert.are.equal(demandBefore + 1500, demand.getCurrentPeriodRevenue())
			assert.are.equal(purchasesBefore + 1, demand.getCurrentPeriodPurchases())
		end)

		it("should error when years is greater than max allowed", function()
			local status, result = pcall(
				arns.buyRecord,
				"test-name",
				"lease",
				constants.maxLeaseLengthYears + 1,
				"Bob",
				timestamp,
				testProcessId
			)
			assert.is_false(status)
			assert.match("Years is invalid. Must be an integer between 1 and 5", result)
		end)

		it(
			"should validate a permabuy request and add the record to global state and deduct balance from caller",
			function()
				local demandBefore = demand.getCurrentPeriodRevenue()
				local purchasesBefore = demand.getCurrentPeriodPurchases()
				local status, result =
					pcall(arns.buyRecord, "test-permabuy-name", "permabuy", 1, "Bob", timestamp, testProcessId)
				assert.is_true(status)
				assert.are.same({
					purchasePrice = 3000,
					type = "permabuy",
					undernameCount = 10,
					processId = testProcessId,
					startTimestamp = 0,
					endTimestamp = nil,
				}, result)
				assert.are.same({
					["test-permabuy-name"] = {
						purchasePrice = 3000,
						type = "permabuy",
						undernameCount = 10,
						processId = testProcessId,
						startTimestamp = 0,
						endTimestamp = nil,
					},
				}, arns.records)
				assert.are.same({
					["Bob"] = 4997000,
					[_G.ao.id] = 3000,
				}, balances.getBalances())
				assert.are.equal(demandBefore + 3000, demand.getCurrentPeriodRevenue())
				assert.are.equal(purchasesBefore + 1, demand.getCurrentPeriodPurchases())
			end
		)

		it(
			"should throw an error when trying to buy a permabuy a name greater than the minimum and shorter than the allowed permabuy threshold",
			function()
				-- give Bob a massive balance
				balances.getBalances()["Bob"] = 15000000
				local status, result =
					pcall(arns.buyRecord, "permabuy", "permabuy", nil, "Bob", timestamp, testProcessId)
				assert.is_false(status)
				-- TODO: this will change to `Name must be auctioned` when auctions are impelmented
				assert.match("Name not available for purchase", result)
			end
		)

		it("should throw an error if trying to buy a short name", function()
			-- give Bob a massive balance
			balances.getBalances()["Bob"] = 15000000
			local status, result = pcall(arns.buyRecord, "a", "permabuy", 1, "Bob", timestamp, testProcessId)
			assert.is_false(status)
			assert.match("Name not available for purchase", result)
		end)

		it("should throw an error if the record already exists", function()
			local existingRecord = {
				endTimestamp = timestamp + constants.oneYearMs,
				processId = testProcessId,
				purchasePrice = 1500,
				startTimestamp = 0,
				type = "lease",
				undernameCount = 10,
			}
			NameRegistry.records["test-name"] = existingRecord
			local status, result = pcall(arns.buyRecord, "test-name", "lease", 1, "Bob", timestamp, testProcessId)
			assert.is_false(status)
			assert.match("Name is already registered", result)
			assert.are.same(existingRecord, NameRegistry.records["test-name"])
		end)

		it("should throw an error if the record is reserved for someone else", function()
			local reservedName = {
				target = "test",
				endTimestamp = 1000,
			}
			arns.reserved["test-name"] = reservedName
			local status, result = pcall(arns.buyRecord, "test-name", "lease", 1, "Bob", timestamp, testProcessId)
			assert.is_false(status)
			assert.match("Name is reserved", result)
			assert.are.same({}, arns.records)
			assert.are.same(reservedName, arns.reserved["test-name"])
		end)

		it("should allow you to buy a reserved name if reserved for caller", function()
			local demandBefore = demand.getCurrentPeriodRevenue()
			local purchasesBefore = demand.getCurrentPeriodPurchases()
			arns.reserved["test-name"] = {
				target = "Bob",
				endTimestamp = 1000,
			}
			local status, result = pcall(arns.buyRecord, "test-name", "lease", 1, "Bob", timestamp, testProcessId)
			local expectation = {
				endTimestamp = timestamp + constants.oneYearMs,
				processId = testProcessId,
				purchasePrice = 1500,
				startTimestamp = 0,
				type = "lease",
				undernameCount = 10,
			}
			assert.is_true(status)
			assert.are.same(expectation, result)
			assert.are.same({ ["test-name"] = expectation }, arns.records)
			assert.are.same({
				["Bob"] = 4998500,
				[_G.ao.id] = 1500,
			}, balances.getBalances())
			assert.are.equal(demandBefore + 1500, demand.getCurrentPeriodRevenue())
			assert.are.equal(purchasesBefore + 1, demand.getCurrentPeriodPurchases())
		end)

		it("should throw an error if the record is in auction", function()
			arns.auctions["test-name"] = {}
			local status, result = pcall(arns.buyRecord, "test-name", "lease", 1, "Bob", timestamp, testProcessId)
			assert.is_false(status)
			assert.match("Name is in auction", result)
			assert.are.same({}, arns.records)
		end)

		it("should throw an error if the user does not have enough balance", function()
			balances.getBalances()["Bob"] = 0
			local status, result = pcall(arns.buyRecord, "test-name", "lease", 1, "Bob", timestamp, testProcessId)
			assert.is_false(status)
			assert.match("Insufficient balance", result)
			assert.are.same({}, arns.records)
		end)
	end)

	describe("increaseUndernameCount", function()
		it("should throw an error if name is not active", function()
			local status, error = pcall(arns.increaseUndernameCount, "Bob", "test-name", 50, timestamp)
			assert.is_false(status)
			assert.match("Name is not registered", error)
		end)

		--  throw an error on insufficient balance
		it("should throw an error on insufficient balance", function()
			NameRegistry.records["test-name"] = {
				endTimestamp = timestamp + constants.oneYearMs,
				processId = testProcessId,
				purchasePrice = 1500,
				startTimestamp = 0,
				type = "lease",
				undernameCount = 10,
			}
			balances.getBalances()["Bob"] = 0
			local status, error = pcall(arns.increaseUndernameCount, "Bob", "test-name", 50, timestamp)
			assert.is_false(status)
			assert.match("Insufficient balance", error)
		end)

		it("should throw an error if increasing more than the max allowed", function()
			NameRegistry.records["test-name"] = {
				endTimestamp = timestamp + constants.oneYearMs,
				processId = testProcessId,
				purchasePrice = 1500,
				startTimestamp = 0,
				type = "lease",
				undernameCount = constants.MAX_ALLOWED_UNDERNAMES,
			}
			local status, error = pcall(arns.increaseUndernameCount, "Bob", "test-name", 1, timestamp)
			assert.is_false(status)
			assert.match(constants.ARNS_MAX_UNDERNAME_MESSAGE, error)
		end)

		it("should throw an error if the name is in the grace period", function()
			NameRegistry.records["test-name"] = {
				endTimestamp = timestamp + constants.oneYearMs,
				processId = testProcessId,
				purchasePrice = 1500,
				startTimestamp = 0,
				type = "lease",
				undernameCount = 10,
			}
			local status, error =
				pcall(arns.increaseUndernameCount, "Bob", "test-name", 1, timestamp + constants.oneYearMs + 1)
			assert.is_false(status)
			assert.match("Name must be extended before additional unernames can be purchase", error)
		end)

		it("should increase the undername count and properly deduct balance", function()
			NameRegistry.records["test-name"] = {
				endTimestamp = timestamp + constants.oneYearMs,
				processId = testProcessId,
				purchasePrice = 1500,
				startTimestamp = 0,
				type = "lease",
				undernameCount = 10,
			}
			local demandBefore = demand.getCurrentPeriodRevenue()
			local purchasesBefore = demand.getCurrentPeriodPurchases()
			local status, result = pcall(arns.increaseUndernameCount, "Bob", "test-name", 50, timestamp)
			local expectation = {
				endTimestamp = timestamp + constants.oneYearMs,
				processId = testProcessId,
				purchasePrice = 1500,
				startTimestamp = 0,
				type = "lease",
				undernameCount = 60,
			}
			assert.is_true(status)
			assert.are.same(expectation, result)
			assert.are.same({ ["test-name"] = expectation }, arns.records)
			assert.are.same({
				["Bob"] = 4999937.5,
				[_G.ao.id] = 62.5,
			}, balances.getBalances())
			assert.are.equal(demandBefore + 62.5, demand.getCurrentPeriodRevenue())
			assert.are.equal(purchasesBefore + 1, demand.getCurrentPeriodPurchases())
		end)
	end)

	describe("extendLease", function()
		it("should throw an error if name is not active", function()
			local status, error = pcall(arns.extendLease, "Bob", "test-name", 1)
			assert.is_false(status)
			assert.match("Name is not registered", error)
		end)

		it("should throw an error if the lease is expired and beyond the grace period", function()
			NameRegistry.records["test-name"] = {
				endTimestamp = timestamp + constants.oneYearMs,
				processId = testProcessId,
				purchasePrice = 1500,
				startTimestamp = 0,
				type = "lease",
				undernameCount = 10,
			}
			local status, error = pcall(
				arns.extendLease,
				"Bob",
				"test-name",
				1,
				timestamp + constants.oneYearMs + constants.gracePeriodMs + 1
			)
			assert.is_false(status)
			assert.match("Name is expired", error)
		end)

		it("should throw an error if the lease is permabought", function()
			NameRegistry.records["test-name"] = {
				endTimestamp = nil,
				processId = testProcessId,
				purchasePrice = 1500,
				startTimestamp = 0,
				type = "permabuy",
				undernameCount = 10,
			}
			local status, error = pcall(arns.extendLease, "Bob", "test-name", 1, timestamp)
			assert.is_false(status)
			assert.match("Name is permabought and cannot be extended", error)
		end)

		-- throw an error of insufficient balance
		it("should throw an error on insufficient balance", function()
			NameRegistry.records["test-name"] = {
				endTimestamp = timestamp + constants.oneYearMs,
				processId = testProcessId,
				purchasePrice = 1500,
				startTimestamp = 0,
				type = "lease",
				undernameCount = 10,
			}
			balances.getBalances()["Bob"] = 0
			local status, error = pcall(arns.extendLease, "Bob", "test-name", 1, timestamp)
			assert.is_false(status)
			assert.match("Insufficient balance", error)
		end)

		it("should allow extension for existing lease up to 5 years", function()
			NameRegistry.records["test-name"] = {
				-- 1 year lease
				endTimestamp = timestamp + constants.oneYearMs,
				processId = testProcessId,
				purchasePrice = 1500,
				startTimestamp = 0,
				type = "lease",
				undernameCount = 10,
			}
			local demandBefore = demand.getCurrentPeriodRevenue()
			local purchasesBefore = demand.getCurrentPeriodPurchases()
			local status, result = pcall(arns.extendLease, "Bob", "test-name", 4, timestamp)
			assert.is_true(status)
			assert.are.same({
				endTimestamp = timestamp + constants.oneYearMs * 5,
				processId = testProcessId,
				purchasePrice = 1500,
				startTimestamp = 0,
				type = "lease",
				undernameCount = 10,
			}, result)
			assert.are.same({
				["test-name"] = {
					endTimestamp = timestamp + constants.oneYearMs * 5,
					processId = testProcessId,
					purchasePrice = 1500,
					startTimestamp = 0,
					type = "lease",
					undernameCount = 10,
				},
			}, arns.records)
			assert.are.same({
				["Bob"] = 4999000,
				[_G.ao.id] = 1000,
			}, balances.getBalances())
			assert.are.equal(demandBefore + 1000, demand.getCurrentPeriodRevenue())
			assert.are.equal(purchasesBefore + 1, demand.getCurrentPeriodPurchases())
		end)

		it("should throw an error when trying to extend beyond 5 years", function()
			NameRegistry.records["test-name"] = {
				-- 1 year lease
				endTimestamp = timestamp + constants.oneYearMs,
				processId = testProcessId,
				purchasePrice = 1500,
				startTimestamp = 0,
				type = "lease",
				undernameCount = 10,
			}
			local status, error = pcall(arns.extendLease, "Bob", "test-name", 6, timestamp)
			assert.is_false(status)
			assert.match("Cannot extend lease beyond 5 years", error)
		end)
	end)
end)
