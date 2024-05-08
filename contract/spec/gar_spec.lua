require("token")
local gar = require("gar")
local constants = require("constants")
local testSettings = {
	fqdn = "test.com",
	protocol = "https",
	port = 443,
	allowDelegatedStaking = true,
	minDelegatedStake = 100,
	autoStake = true,
	label = "test",
}

local startTimestamp = os.clock()
local testGateway = {
	operatorStake = 100,
	vaults = {},
	delegates = {},
	startTimestamp = 100,
	stats = {
		prescribedEpochCount = 0,
		observeredEpochCount = 0,
		totalEpochParticipationCount = 0,
		passedEpochCount = 0,
		failedEpochCount = 0,
		failedConsecutiveEpochs = 0,
		passedConsecutiveEpochs = 0,
	},
	settings = testSettings,
	status = "joined",
	observerWallet = "observerWallet"
}

describe("gar", function()
	it("should join the network", function()
		Balances['Bob'] = constants.MIN_OPERATOR_STAKE
		local result, err = gar.joinNetwork("Bob", constants.MIN_OPERATOR_STAKE, testSettings, "observerWallet",
			startTimestamp)
		assert.are.same({
			operatorStake = constants.MIN_OPERATOR_STAKE,
			vaults = {},
			delegates = {},
			startTimestamp = startTimestamp,
			stats = {
				prescribedEpochCount = 0,
				observeredEpochCount = 0,
				totalEpochParticipationCount = 0,
				passedEpochCount = 0,
				failedEpochCount = 0,
				failedConsecutiveEpochs = 0,
				passedConsecutiveEpochs = 0,
			},
			settings = testSettings,
			status = "joined",
			observerWallet = "observerWallet",
		}, result)
	end)

	it("should leave the network", function()
		Gateways["Bob"] = {
			operatorStake = constants.MIN_OPERATOR_STAKE + 100,
			vaults = {},
			delegates = {},
			startTimestamp = 0,
			stats = {
				prescribedEpochCount = 0,
				observeredEpochCount = 0,
				totalEpochParticipationCount = 0,
				passedEpochCount = 0,
				failedEpochCount = 0,
				failedConsecutiveEpochs = 0,
				passedConsecutiveEpochs = 0,
			},
			settings = testSettings,
			status = "joined",
			observerWallet = "observerWallet",
		}

		local result, err = gar.leaveNetwork("Bob", 10000000000000, 1984)
		print(err)
		assert.are.same(result, {
			operatorStake = 0,
			vaults = {
				caller = {
					amount = 100,
					startTimestamp = 200,
					endTimestamp = 200 + constants.thirtyDaysSeconds * 1000,
				},
			},
			delegates = {},
			startTimestamp = 100,
			endTimestamp = 200 + constants.thirtyDaysSeconds * 1000,
			stats = {
				prescribedEpochCount = 0,
				observeredEpochCount = 0,
				totalEpochParticipationCount = 0,
				passedEpochCount = 0,
				failedEpochCount = 0,
				failedConsecutiveEpochs = 0,
				passedConsecutiveEpochs = 0,
			},
			settings = testSettings,
			status = "leaving",
			observerWallet = "observerWallet",
		})
	end)
end)
