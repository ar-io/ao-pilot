local testProcessId = "NdZ3YRwMB2AMwwFYjKn1g88Y9nRybTo0qhS1ORq_E7g"
local constants = require("constants")
local arns = require("arns")
local token = require("token")

describe("arns", function()
	local timestamp = os.clock()

	-- stub out the global state for these tests
	before_each(function()
		arns.records = {}
		arns.reserved = {}
		arns.fees = constants.genesisFees
		token.balances = {
			Bob = 5000000,
		}
	end)

	it("adds validate a lease request and add it to arns records object", function()
		local status, result = pcall(arns.buyRecord, "test-name", "lease", 1, "Bob", false, timestamp, testProcessId)
		assert.is_true(status)
		assert.are.same({
			purchasePrice = 1500,
			type = "lease",
			undernameCount = 10,
			processId = testProcessId,
			startTimestamp = 0,
			endTimestamp = timestamp + constants.MS_IN_A_YEAR * 1,
		}, result)
		assert.are.same({
			["test-name"] = {
				purchasePrice = 1500,
				type = "lease",
				undernameCount = 10,
				processId = testProcessId,
				startTimestamp = 0,
				endTimestamp = timestamp + constants.MS_IN_A_YEAR * 1,
			},
		}, arns.records)
		assert.are.same({
			["Bob"] = 4998500,
			[_G.ao.id] = 1500,
		}, token.balances)
	end)

	it('defaults to 1 year and lease when not provided', function ()
		local status, result = pcall(arns.buyRecord, "test-name", nil, nil, "Bob", false, timestamp, testProcessId)
		assert.is_true(status)
		assert.are.same({
			purchasePrice = 1500,
			type = "lease",
			undernameCount = 10,
			processId = testProcessId,
			startTimestamp = 0,
			endTimestamp = timestamp + constants.MS_IN_A_YEAR,
		}, result)
		assert.are.same({
			["test-name"] = {
				purchasePrice = 1500,
				type = "lease",
				undernameCount = 10,
				processId = testProcessId,
				startTimestamp = 0,
				endTimestamp = timestamp + constants.MS_IN_A_YEAR,
			},
		}, arns.records)
		assert.are.same({
			["Bob"] = 4998500,
			[_G.ao.id] = 1500,
		}, token.balances)
	end)

	it(
		"should validate a permabuy request and add the record to global state and deduct balance from caller",
		function()
			local status, result =
				pcall(arns.buyRecord, "test-permabuy", "permabuy", 1, "Bob", false, timestamp, testProcessId)
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
				["test-permabuy"] = {
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
			}, token.balances)
		end
	)

	it("should throw an error if the record already exists", function()
		local existingRecord = {
			endTimestamp = timestamp + constants.MS_IN_A_YEAR,
			processId = testProcessId,
			purchasePrice = 1500,
			startTimestamp = 0,
			type = "lease",
			undernameCount = 10,
		}
		arns.records["test-name"] = existingRecord
		local status, result = pcall(arns.buyRecord, "test-name", "lease", 1, "Bob", false, timestamp, testProcessId)
		assert.is_false(status)
		assert.match("Name is already registered", result)
		assert.are.same(existingRecord, arns.records["test-name"])
	end)

	it("should throw an error if the record is reserved for someone else", function()
		local reservedName = {
			target = "test",
			endTimestamp = 1000,
		}
		arns.reserved["test-name"] = reservedName
		local status, result = pcall(arns.buyRecord, "test-name", "lease", 1, "Bob", false, timestamp, testProcessId)
		assert.is_false(status)
		assert.match("Name is reserved", result)
		assert.are.same({}, arns.records)
		assert.are.same(reservedName, arns.reserved["test-name"])
	end)

	it("should allow you to buy a reserved name if reserved for you", function()
		arns.reserved["test-name"] = {
			target = "Bob",
			endTimestamp = 1000,
		}
		local status, result = pcall(arns.buyRecord, "test-name", "lease", 1, "Bob", false, timestamp, testProcessId)
		local expectation = {
			endTimestamp = timestamp + constants.MS_IN_A_YEAR,
			processId = testProcessId,
			purchasePrice = 1500,
			startTimestamp = 0,
			type = "lease",
			undernameCount = 10,
		}
		assert.is_true(status)
		assert.are.same(expectation, result)
		assert.are.same({ ["test-name"] = expectation }, arns.records)
	end)

	it("should throw an error if the record is in auction", function()
		arns.auctions["test-name"] = {}
		local status, result = pcall(arns.buyRecord, "test-name", "lease", 1, "Bob", false, timestamp, testProcessId)
		assert.is_false(status)
		assert.match("Name is in auction", result)
		assert.are.same({}, arns.records)
	end)

	it("should throw an error if the user does not have enough funds", function()
		token.balances["Bob"] = 0
		local status, result = pcall(arns.buyRecord, "test-name", "lease", 1, "Bob", false, timestamp, testProcessId)
		assert.is_false(status)
		assert.match("Insufficient funds", result)
		assert.are.same({}, arns.records)
	end)

	it("should increase the undername count and properly deduct balance", function()
		arns.records["test-name"] = {
			endTimestamp = timestamp + constants.MS_IN_A_YEAR,
			processId = testProcessId,
			purchasePrice = 1500,
			startTimestamp = 0,
			type = "lease",
			undernameCount = 10,
		}
		local status, result = pcall(arns.increaseUndernameCount, "Bob", "test-name", 50, timestamp)
		local expectation = {
			endTimestamp = timestamp + constants.MS_IN_A_YEAR,
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
		}, token.balances)
	end)

	describe("extendLease", function()
		it("should throw an error if name is not active", function()
			local status, error = pcall(arns.extendLease, "Bob", "test-name", 1)
			assert.is_false(status)
			assert.match("Name is not registered", error)
		end)

		it('should allow extension for existing lease up to 5 years', function()
			arns.records["test-name"] = {
				-- 1 year lease
				endTimestamp = timestamp + constants.MS_IN_A_YEAR,
				processId = testProcessId,
				purchasePrice = 1500,
				startTimestamp = 0,
				type = "lease",
				undernameCount = 10,
			}
			local status, result = pcall(arns.extendLease, "Bob", "test-name", 4, timestamp)
			assert.is_true(status)
			assert.are.same({
				endTimestamp = timestamp + constants.MS_IN_A_YEAR * 5,
				processId = testProcessId,
				purchasePrice = 1500,
				startTimestamp = 0,
				type = "lease",
				undernameCount = 10,
			}, result)
			assert.are.same({
				["test-name"] = {
					endTimestamp = timestamp + constants.MS_IN_A_YEAR * 5,
					processId = testProcessId,
					purchasePrice = 1500,
					startTimestamp = 0,
					type = "lease",
					undernameCount = 10,
				},
			}, arns.records)
		end)	
	end)
end)
