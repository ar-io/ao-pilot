package.path = package.path .. ";./contract/src/?.lua"

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

describe("gar", function()
	it("should join the network", function()
		os.clock = function()
			return 100
		end
		local reply = gar.joinNetwork("caller", 100, testSettings, "observerWallet")
		assert.are.same(reply, {
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
			observerWallet = "observerWallet",
		})
	end)

	it("should leave the network", function()
		os.clock = function()
			return 200
		end
		gar["caller"] = {
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
			observerWallet = "observerWallet",
		}

		local reply = gar.leaveNetwork("caller")
		assert.are.same(reply, {
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
