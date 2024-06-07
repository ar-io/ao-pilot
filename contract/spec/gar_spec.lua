local gar = require("gar")
local testSettings = {
	fqdn = "test.com",
	protocol = "https",
	port = 443,
	allowDelegatedStaking = true,
	minDelegatedStake = 100,
	autoStake = true,
	label = "test",
	delegateRewardShareRatio = 0,
	properties = "properties",
}

local startTimestamp = 0
local testGateway = {
	operatorStake = gar.getSettings().operators.minStake,
	vaults = {},
	delegates = {},
	startTimestamp = 0,
	stats = {
		prescribedEpochCount = 0,
		observedEpochCount = 0,
		totalEpochCount = 0,
		passedEpochCount = 0,
		failedEpochCount = 0,
		failedConsecutiveEpochs = 0,
		passedConsecutiveEpochs = 0,
	},
	settings = testSettings,
	status = "joined",
	observerAddress = "observerAddress",
}

describe("gar", function()
	before_each(function()
		_G.Balances = {
			["test-this-is-valid-arweave-wallet-address-1"] = gar.getSettings().operators.minStake,
		}
		_G.Epochs = {
			[0] = {
				startTimestamp = 0,
				endTimestamp = 100,
				prescribedObservers = {},
				observations = {},
			},
		}
		_G.GatewayRegistry = {}
	end)

	describe("joinNetwork", function()
		it("should fail if the gateway is already in the network", function()
			_G.GatewayRegistry["test-this-is-valid-arweave-wallet-address-1"] = {
				operatorStake = gar.getSettings().operators.minStake,
				totalDelegatedStake = 0,
				vaults = {},
				delegates = {},
				startTimestamp = startTimestamp,
				stats = {
					prescribedEpochCount = 0,
					observedEpochCount = 0,
					totalEpochCount = 0,
					passedEpochCount = 0,
					failedEpochCount = 0,
					failedConsecutiveEpochs = 0,
					passedConsecutiveEpochs = 0,
				},
				settings = testSettings,
				status = "joined",
				observerAddress = "observerAddress",
			}
			local status, error = pcall(
				gar.joinNetwork,
				"test-this-is-valid-arweave-wallet-address-1",
				gar.getSettings().operators.minStake,
				testSettings,
				"observerAddress",
				startTimestamp
			)
			assert.is_false(status)
			assert.match("Gateway already exists", error)
		end)
		it("should join the network", function()
			local expectation = {
				operatorStake = gar.getSettings().operators.minStake,
				totalDelegatedStake = 0,
				vaults = {},
				delegates = {},
				startTimestamp = startTimestamp,
				stats = {
					prescribedEpochCount = 0,
					observedEpochCount = 0,
					totalEpochCount = 0,
					passedEpochCount = 0,
					failedEpochCount = 0,
					failedConsecutiveEpochs = 0,
					passedConsecutiveEpochs = 0,
				},
				settings = {
					allowDelegatedStaking = testSettings.allowDelegatedStaking,
					delegateRewardShareRatio = 0,
					autoStake = testSettings.autoStake,
					propteris = testSettings.propteries,
					minDelegatedStake = testSettings.minDelegatedStake,
					label = testSettings.label,
					fqdn = testSettings.fqdn,
					protocol = testSettings.protocol,
					port = testSettings.port,
					properties = testSettings.properties,
				},
				status = "joined",
				observerAddress = "observerAddress",
			}
			local status, result = pcall(
				gar.joinNetwork,
				"test-this-is-valid-arweave-wallet-address-1",
				gar.getSettings().operators.minStake,
				testSettings,
				"observerAddress",
				startTimestamp
			)
			assert.is_true(status)
			assert.are.same(expectation, result)
			assert.are.same(expectation, gar.getGateway("test-this-is-valid-arweave-wallet-address-1"))
		end)
	end)

	describe("leaveNetwork", function()
		it("should leave the network", function()
			GatewayRegistry["test-this-is-valid-arweave-wallet-address-1"] = {
				operatorStake = (gar.getSettings().operators.minStake + 1000),
				totalDelegatedStake = gar.getSettings().delegates.minStake,
				vaults = {},
				startTimestamp = startTimestamp,
				stats = {
					prescribedEpochCount = 0,
					observedEpochCount = 0,
					totalEpochCount = 0,
					passedEpochCount = 0,
					failedEpochCount = 0,
					failedConsecutiveEpochs = 0,
					passedConsecutiveEpochs = 0,
				},
				settings = testSettings,
				status = "joined",
				observerAddress = "observerAddress",
				delegates = {
					["test-this-is-valid-arweave-wallet-address-2"] = {
						delegatedStake = gar.getSettings().delegates.minStake,
						startTimestamp = 0,
						vaults = {},
					},
				},
			}

			local status, result = pcall(gar.leaveNetwork, "test-this-is-valid-arweave-wallet-address-1", startTimestamp, "msgId")
			assert.is_true(status)
			assert.are.same(result, {
				operatorStake = 0,
				totalDelegatedStake = 0,
				vaults = {
					["test-this-is-valid-arweave-wallet-address-1"] = {
						balance = gar.getSettings().operators.minStake,
						startTimestamp = startTimestamp,
						endTimestamp = gar.getSettings().operators.leaveLengthMs,
					},
					msgId = {
						balance = 1000,
						startTimestamp = startTimestamp,
						endTimestamp = gar.getSettings().operators.withdrawLengthMs,
					},
				},
				delegates = {
					["test-this-is-valid-arweave-wallet-address-2"] = {
						delegatedStake = 0,
						startTimestamp = 0,
						vaults = {
							msgId = {
								balance = gar.getSettings().delegates.minStake,
								startTimestamp = startTimestamp,
								endTimestamp = gar.getSettings().delegates.withdrawLengthMs,
							},
						},
					},
				},
				startTimestamp = startTimestamp,
				endTimestamp = gar.getSettings().operators.leaveLengthMs,
				stats = {
					prescribedEpochCount = 0,
					observedEpochCount = 0,
					totalEpochCount = 0,
					passedEpochCount = 0,
					failedEpochCount = 0,
					failedConsecutiveEpochs = 0,
					passedConsecutiveEpochs = 0,
				},
				settings = testSettings,
				status = "leaving",
				observerAddress = "observerAddress",
			})
		end)
	end)

	describe("increaseOperatorStake", function()
		it("should increase operator stake", function()
			Balances["test-this-is-valid-arweave-wallet-address-1"] = 1000
			GatewayRegistry["test-this-is-valid-arweave-wallet-address-1"] = {
				operatorStake = gar.getSettings().operators.minStake,
				totalDelegatedStake = 0,
				vaults = {},
				delegates = {},
				startTimestamp = startTimestamp,
				stats = {
					prescribedEpochCount = 0,
					observedEpochCount = 0,
					totalEpochCount = 0,
					passedEpochCount = 0,
					failedEpochCount = 0,
					failedConsecutiveEpochs = 0,
					passedConsecutiveEpochs = 0,
				},
				settings = testSettings,
				status = "joined",
				observerAddress = "observerAddress",
			}
			local result, err = gar.increaseOperatorStake("test-this-is-valid-arweave-wallet-address-1", 1000)
			assert.are.same(result, {
				operatorStake = gar.getSettings().operators.minStake + 1000,
				totalDelegatedStake = 0,
				vaults = {},
				delegates = {},
				startTimestamp = startTimestamp,
				stats = {
					prescribedEpochCount = 0,
					observedEpochCount = 0,
					totalEpochCount = 0,
					passedEpochCount = 0,
					failedEpochCount = 0,
					failedConsecutiveEpochs = 0,
					passedConsecutiveEpochs = 0,
				},
				settings = testSettings,
				status = "joined",
				observerAddress = "observerAddress",
			})
		end)
	end)

	describe("decreaseOperatorStake", function()
		it("should decrease operator stake", function()
			_G.GatewayRegistry["test-this-is-valid-arweave-wallet-address-1"] = {
				operatorStake = gar.getSettings().operators.minStake + 1000,
				totalDelegatedStake = 0,
				vaults = {},
				delegates = {},
				startTimestamp = startTimestamp,
				stats = {
					prescribedEpochCount = 0,
					observedEpochCount = 0,
					totalEpochCount = 0,
					passedEpochCount = 0,
					failedEpochCount = 0,
					failedConsecutiveEpochs = 0,
					passedConsecutiveEpochs = 0,
				},
				settings = testSettings,
				status = "joined",
				observerAddress = "observerAddress",
			}
			local status, result =
				pcall(gar.decreaseOperatorStake, "test-this-is-valid-arweave-wallet-address-1", 1000, startTimestamp, "msgId")
			assert.is_true(status)
			assert.are.same(result, {
				operatorStake = gar.getSettings().operators.minStake,
				totalDelegatedStake = 0,
				vaults = {
					msgId = {
						balance = 1000,
						startTimestamp = startTimestamp,
						endTimestamp = startTimestamp + gar.getSettings().operators.withdrawLengthMs,
					},
				},
				delegates = {},
				startTimestamp = startTimestamp,
				stats = {
					prescribedEpochCount = 0,
					observedEpochCount = 0,
					totalEpochCount = 0,
					passedEpochCount = 0,
					failedEpochCount = 0,
					failedConsecutiveEpochs = 0,
					passedConsecutiveEpochs = 0,
				},
				settings = testSettings,
				status = "joined",
				observerAddress = "observerAddress",
			})
		end)
	end)

	describe("updateGatewaySettings", function()
		it("should update gateway settings", function()
			GatewayRegistry["test-this-is-valid-arweave-wallet-address-1"] = {
				operatorStake = gar.getSettings().operators.minStake,
				totalDelegatedStake = 0,
				vaults = {},
				delegates = {},
				startTimestamp = startTimestamp,
				stats = {
					prescribedEpochCount = 0,
					observedEpochCount = 0,
					totalEpochCount = 0,
					passedEpochCount = 0,
					failedEpochCount = 0,
					failedConsecutiveEpochs = 0,
					passedConsecutiveEpochs = 0,
				},
				settings = testSettings,
				status = "joined",
				observerAddress = "observerAddress",
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
				minDelegatedStake = gar.getSettings().delegates.minStake + 5,
			}
			local expectation = {
				operatorStake = gar.getSettings().operators.minStake,
				observerAddress = newObserverWallet,
				totalDelegatedStake = 0,
				vaults = {},
				delegates = {},
				startTimestamp = startTimestamp,
				stats = {
					prescribedEpochCount = 0,
					observedEpochCount = 0,
					totalEpochCount = 0,
					passedEpochCount = 0,
					failedEpochCount = 0,
					failedConsecutiveEpochs = 0,
					passedConsecutiveEpochs = 0,
				},
				settings = updatedSettings,
				status = "joined",
			}
			local status, result = pcall(
				gar.updateGatewaySettings,
				"test-this-is-valid-arweave-wallet-address-1",
				updatedSettings,
				newObserverWallet,
				startTimestamp,
				"msgId"
			)
			assert.is_true(status)
			assert.are.same(expectation, result)
			assert.are.same(expectation, gar.getGateway("test-this-is-valid-arweave-wallet-address-1"))
		end)
	end)

	describe("delegateStake", function()
		it("should delegate stake to a gateway", function()
			Balances["test-this-is-valid-arweave-wallet-address-2"] = gar.getSettings().delegates.minStake
			GatewayRegistry["test-this-is-valid-arweave-wallet-address-1"] = {
				operatorStake = gar.getSettings().operators.minStake,
				totalDelegatedStake = 0,
				vaults = {},
				delegates = {},
				startTimestamp = startTimestamp,
				stats = {
					prescribedEpochCount = 0,
					observedEpochCount = 0,
					totalEpochCount = 0,
					passedEpochCount = 0,
					failedEpochCount = 0,
					failedConsecutiveEpochs = 0,
					passedConsecutiveEpochs = 0,
				},
				settings = testSettings,
				status = "joined",
				observerAddress = "observerAddress",
			}
			local result, err = gar.delegateStake(
				"test-this-is-valid-arweave-wallet-address-2",
				"test-this-is-valid-arweave-wallet-address-1",
				gar.getSettings().delegates.minStake,
				startTimestamp
			)
			assert.are.same(result, {
				operatorStake = gar.getSettings().operators.minStake,
				totalDelegatedStake = gar.getSettings().delegates.minStake,
				vaults = {},
				delegates = {
					["test-this-is-valid-arweave-wallet-address-2"] = {
						delegatedStake = gar.getSettings().delegates.minStake,
						startTimestamp = startTimestamp,
						vaults = {},
					},
				},
				startTimestamp = startTimestamp,
				stats = {
					prescribedEpochCount = 0,
					observedEpochCount = 0,
					totalEpochCount = 0,
					passedEpochCount = 0,
					failedEpochCount = 0,
					failedConsecutiveEpochs = 0,
					passedConsecutiveEpochs = 0,
				},
				settings = testSettings,
				status = "joined",
				observerAddress = "observerAddress",
			})
		end)

		it("should decrease delegated stake", function()
			GatewayRegistry["test-this-is-valid-arweave-wallet-address-1"] = {
				operatorStake = gar.getSettings().operators.minStake,
				totalDelegatedStake = gar.getSettings().delegates.minStake + 1000,
				vaults = {},
				startTimestamp = startTimestamp,
				stats = {
					prescribedEpochCount = 0,
					observedEpochCount = 0,
					totalEpochCount = 0,
					passedEpochCount = 0,
					failedEpochCount = 0,
					failedConsecutiveEpochs = 0,
					passedConsecutiveEpochs = 0,
				},
				settings = testSettings,
				status = "joined",
				observerAddress = "observerAddress",
				delegates = {
					["test-this-is-valid-arweave-wallet-address-2"] = {
						delegatedStake = gar.getSettings().delegates.minStake + 1000,
						startTimestamp = 0,
						vaults = {},
					},
				},
			}

			local expectation = {
				operatorStake = gar.getSettings().operators.minStake,
				totalDelegatedStake = gar.getSettings().delegates.minStake,
				vaults = {},
				delegates = {
					["test-this-is-valid-arweave-wallet-address-2"] = {
						delegatedStake = gar.getSettings().delegates.minStake,
						startTimestamp = 0,
						vaults = {
							msgId = {
								balance = 1000,
								startTimestamp = startTimestamp,
								endTimestamp = gar.getSettings().delegates.withdrawLengthMs,
							},
						},
					},
				},
				startTimestamp = startTimestamp,
				stats = {
					prescribedEpochCount = 0,
					observedEpochCount = 0,
					totalEpochCount = 0,
					passedEpochCount = 0,
					failedEpochCount = 0,
					failedConsecutiveEpochs = 0,
					passedConsecutiveEpochs = 0,
				},
				settings = testSettings,
				status = "joined",
				observerAddress = "observerAddress",
			}
			local status, result = pcall(
				gar.decreaseDelegateStake,
				"test-this-is-valid-arweave-wallet-address-1",
				"test-this-is-valid-arweave-wallet-address-2",
				1000,
				startTimestamp,
				"msgId"
			)
			assert.is_true(status)
			assert.are.same(expectation, result)
			assert.are.same(expectation, gar.getGateway("test-this-is-valid-arweave-wallet-address-1"))
		end)
	end)

	describe("getters", function()
		-- TODO: other tests for error conditions when joining/leaving network
		it("should get single gateway", function()
			GatewayRegistry["test-this-is-valid-arweave-wallet-address-1"] = testGateway
			local result = gar.getGateway("test-this-is-valid-arweave-wallet-address-1")
			assert.are.same(result, testGateway)
		end)

		it("should get multiple gateways", function()
			GatewayRegistry["test-this-is-valid-arweave-wallet-address-1"] = testGateway
			GatewayRegistry["test-this-is-valid-arweave-wallet-address-2"] = testGateway
			local result = gar.getGateways()
			assert.are.same(result, {
				["test-this-is-valid-arweave-wallet-address-1"] = testGateway,
				["test-this-is-valid-arweave-wallet-address-2"] = testGateway,
			})
		end)
	end)
end)
