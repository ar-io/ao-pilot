local testProcessId = "NdZ3YRwMB2AMwwFYjKn1g88Y9nRybTo0qhS1ORq_E7g"
local arns = require("arns")
local constants = require("constants")
require("state")

describe("arns", function()
	local timestamp = os.clock()

	-- stub out the global state for these tests
	before_each(function()
		_G.Records = {}
		_G.Balances = {
			["Bob"] = 5000000,
		}
	end)

	it("adds validate a lease request and add it to global records object", function()
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
		}, Records)
		assert.are.same({
			["Bob"] = 4998500,
			[_G.ao.id] = 1500,
		}, Balances)
	end)

	it("should validate a permabuy request and add the record to global state and deduct balance from caller", function()
		local status, result = pcall(arns.buyRecord, "test-permabuy", "permabuy", 1, "Bob", false, timestamp,
			testProcessId)
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
		}, Records)
		assert.are.same({
			["Bob"] = 4997000,
			[_G.ao.id] = 3000,
		}, Balances)
	end)

	it('should throw an error if the record already exists', function()
		Records["test-name"] = {
			endTimestamp = timestamp + constants.MS_IN_A_YEAR,
			processId = testProcessId,
			purchasePrice = 1500,
			startTimestamp = 0,
			type = "lease",
			undernameCount = 10,
		}
		local status, result = pcall(arns.buyRecord, "test-name", "lease", 1, "Bob", false, timestamp, testProcessId)
		assert.is_false(status)
		assert.match("Name is already registered", result)
	end)

	it('should throw an error if the user does not have enough funds', function()
		Balances["Bob"] = 0
		local status, result = pcall(arns.buyRecord, "test-name", "lease", 1, "Bob", false, timestamp, testProcessId)
		assert.is_false(status)
		assert.match("Insufficient funds", result)
	end)

	it("should increase the undername count and properly deduct balance", function()
		Records["test-name"] = {
			endTimestamp = timestamp + constants.MS_IN_A_YEAR,
			processId = testProcessId,
			purchasePrice = 1500,
			startTimestamp = 0,
			type = "lease",
			undernameCount = 10,
		}
		local status, result = pcall(arns.increaseUndernameCount, "Bob", "test-name", 50, timestamp)
		assert.is_true(status)
		assert.are.same({
			endTimestamp = timestamp + constants.MS_IN_A_YEAR,
			processId = testProcessId,
			purchasePrice = 1500,
			startTimestamp = 0,
			type = "lease",
			undernameCount = 60,
		}, result)
		assert.are.same({
			["test-name"] = {
				endTimestamp = timestamp + constants.MS_IN_A_YEAR,
				processId = testProcessId,
				purchasePrice = 1500,
				startTimestamp = 0,
				type = "lease",
				undernameCount = 60,
			},
		}, Records)
		assert.are.same({
			["Bob"] = 4999937.5,
			[_G.ao.id] = 62.5,
		}, Balances)
	end)
end)
