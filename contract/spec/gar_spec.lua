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

describe("Network Join, Leave, Increase Stake and Decrease Stake", function()
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

	it("should increase operator stake", function()
		Balances["Bob"] = 1000
		Gateways["Bob"] = {
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
		}
		local result, err = gar.increaseOperatorStake("Bob", 1000)
		assert.are.same(result, {
			operatorStake = constants.MIN_OPERATOR_STAKE + 1000,
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
			observerWallet = "observerWallet"
		})
	end)

	it("should decrease operator stake", function()
		Gateways["Bob"] = {
			operatorStake = constants.MIN_OPERATOR_STAKE + 1000,
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
		}
		local result, err = gar.decreaseOperatorStake("Bob", 1000, startTimestamp, "msgId")
		assert.are.same(result, {
			operatorStake = constants.MIN_OPERATOR_STAKE,
			totalDelegatedStake = 0,
			vaults = {
				msgId = {
					balance = 1000,
					startTimestamp = startTimestamp,
					endTimestamp = startTimestamp + constants.GATEWAY_REGISTRY_SETTINGS.operatorStakeWithdrawLength
				}
			},
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
			observerWallet = "observerWallet"
		})
	end)

	it("should update gateway settings", function()
		Gateways["Bob"] = {
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
		}
		local newObserverWallet = "QGWqtJdLLgm2ehFWiiPzMaoFLD50CnGuzZIPEdoDRGQ"
		local updatedSettings = {
			fqdn = "example.com",
			port = 80,
			protocol = "http",
			properties = "NdZ3YRwMB2AMwwFYjKn1g88Y9nRybTo0qhS1ORq_E7g",
			note = "This is a test update.",
			label = "Test Label Update",
			autoStake = true,
			allowDelegatedStaking = false,
			delegateRewardShareRatio = 15,
			minDelegatedStake = constants.MIN_DELEGATED_STAKE + 5
		}
		local result, err = gar.updateGatewaySettings("Bob", updatedSettings, newObserverWallet, startTimestamp, "msgId")
		updatedSettings.observerWallet = nil -- this is not an actual setting in a gateway
		assert.are.same(result, {
			operatorStake = constants.MIN_OPERATOR_STAKE,
			observerWallet = newObserverWallet,
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
			settings = updatedSettings,
			status = "joined"
		})
	end)

	it("should get single gateway", function()
		Gateways["Bob"] = testGateway
		local result = gar.getGateway("Bob")
		assert.are.same(result, testGateway)
	end)

	it("should get multiple gateways", function()
		Gateways["Bob"] = testGateway
		Gateways["Alice"] = testGateway
		local result = gar.getGateways()
		assert.are.same(result, {
			Bob = testGateway,
			Alice = testGateway
		})
	end)
end)
