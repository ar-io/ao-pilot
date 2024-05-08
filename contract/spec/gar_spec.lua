require("token")
local utils = require("utils")
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

local startTimestamp = 0
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
			totalDelegatedStake = 0,
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
			operatorStake = (constants.MIN_OPERATOR_STAKE + 1000),
			totalDelegatedStake = constants.MIN_DELEGATED_STAKE,
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
		}

		Gateways["Bob"].delegates['Alice'] = {
			delegatedStake = constants.MIN_DELEGATED_STAKE,
			startTimestamp = 0,
			vaults = {}
		}

		local result, err = gar.leaveNetwork("Bob", startTimestamp, "msgId")
		utils.printTable(result)
		assert.are.same(result, {
			operatorStake = 0,
			totalDelegatedStake = 0,
			vaults = {
				Bob = {
					balance = constants.MIN_OPERATOR_STAKE,
					startTimestamp = startTimestamp,
					endTimestamp = constants.GATEWAY_REGISTRY_SETTINGS.gatewayLeaveLength,
				},
				msgId = {
					balance = 1000,
					startTimestamp = startTimestamp,
					endTimestamp = constants.GATEWAY_REGISTRY_SETTINGS.operatorStakeWithdrawLength,
				},
			},
			delegates = {
				Alice = {
					delegatedStake = 0,
					startTimestamp = 0,
					vaults = {
						msgId = {
							balance = constants.MIN_DELEGATED_STAKE,
							startTimestamp = startTimestamp,
							endTimestamp = constants.GATEWAY_REGISTRY_SETTINGS.delegatedStakeWithdrawLength
						}
					}
				}
			},
			startTimestamp = startTimestamp,
			endTimestamp = constants.GATEWAY_REGISTRY_SETTINGS.gatewayLeaveLength,
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
