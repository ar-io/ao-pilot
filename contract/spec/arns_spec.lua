local testProcessId = "NdZ3YRwMB2AMwwFYjKn1g88Y9nRybTo0qhS1ORq_E7g"
local arns = require("arns")
local constants = require("constants")

describe("arns", function()
	local original_clock = os.clock
	local timestamp = os.clock()

	setup(function() end)

	teardown(function() end)

	it("adds a record to the global balance object", function()
		Balances["Bob"] = 5000000
		local result = arns.buyRecord("test-name", "lease", 1, "Bob", false, timestamp, testProcessId)
		assert.are.same({
			purchasePrice = 1500,
			type = "lease",
			undernameCount = 10,
			processId = testProcessId,
			startTimestamp = 0,
			endTimestamp = timestamp + constants.MS_IN_A_YEAR * 1,
		}, result)
	end)

	it("should allow you to lease a record", function()
		local result = arns.buyRecord("test-name-2", "lease", 1, "Bob", false, timestamp, testProcessId)
		assert.are.same({
			purchasePrice = 1500,
			type = "lease",
			undernameCount = 10,
			processId = testProcessId,
			startTimestamp = 0,
			endTimestamp = timestamp + constants.MS_IN_A_YEAR * 1,
		}, result)
	end)

	it("should allow you to permabuy a record", function()
		Balances["Bob"] = 5000000
		local result, err = arns.buyRecord("test-permabuy-name", "permabuy", 1, "Bob", false, timestamp, testProcessId)
		assert.are.same({
			purchasePrice = 3000,
			type = "permabuy",
			undernameCount = 10,
			processId = testProcessId,
			startTimestamp = 0,
			endTimestamp = nil,
		}, result)
	end)

	it("should allow you to increase the undername count", function()
		Records["test-name-4"] = {
			endTimestamp = timestamp + constants.MS_IN_A_YEAR,
			processId = testProcessId,
			purchasePrice = 1500,
			startTimestamp = 0,
			type = "lease",
			undernameCount = 10,
		}
		local result, err = arns.increaseUndernameCount("test-name-4", "Bob", 50, timestamp)
		assert.are.same({
			endTimestamp = timestamp + constants.MS_IN_A_YEAR,
			processId = testProcessId,
			purchasePrice = 1500,
			startTimestamp = 0,
			type = "lease",
			undernameCount = 60,
		}, result)
	end)
end)
