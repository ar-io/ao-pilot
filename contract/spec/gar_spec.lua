local gar = require("gar")
local token = require("token")
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
	observerWallet = "observerWallet",
}

describe("gar", function()
	before_each(function()
		token.balances = {
			Bob = gar.settings.minOperatorStake,
		}
		gar.gateways = {}
	end)

	describe("joinNetwork", function()
		it("should fail if the gateway is already in the network", function()
			gar.gateways["Bob"] = {
				operatorStake = gar.settings.minOperatorStake,
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
			local status, error = pcall(
				gar.joinNetwork,
				"Bob",
				gar.settings.minOperatorStake,
				testSettings,
				"observerWallet",
				startTimestamp
			)
			assert.is_false(status)
			assert.match("Gateway already exists", error)
		end)
		it("should join the network", function()
			local expectation = {
				operatorStake = gar.settings.minOperatorStake,
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
				},
				status = "joined",
				observerWallet = "observerWallet",
			}
			local status, result = pcall(
				gar.joinNetwork,
				"Bob",
				gar.settings.minOperatorStake,
				testSettings,
				"observerWallet",
				startTimestamp
			)
			assert.is_true(status)
			assert.are.same(expectation, result)
			assert.are.same(expectation, gar.getGateway("Bob"))
		end)
	end)

	describe("leaveNetwork", function()
		it("should leave the network", function()
			gar.gateways["Bob"] = {
				operatorStake = (gar.settings.minOperatorStake + 1000),
				totalDelegatedStake = gar.settings.minDelegatedStake,
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

			gar.gateways["Bob"].delegates["Alice"] = {
				delegatedStake = gar.settings.minDelegatedStake,
				startTimestamp = 0,
				vaults = {},
			}

			local result, err = gar.leaveNetwork("Bob", startTimestamp, "msgId")
			assert.are.same(result, {
				operatorStake = 0,
				totalDelegatedStake = 0,
				vaults = {
					Bob = {
						balance = gar.settings.minOperatorStake,
						startTimestamp = startTimestamp,
						endTimestamp = gar.settings.gatewayLeaveLength,
					},
					msgId = {
						balance = 1000,
						startTimestamp = startTimestamp,
						endTimestamp = gar.settings.operatorStakeWithdrawLength,
					},
				},
				delegates = {
					Alice = {
						delegatedStake = 0,
						startTimestamp = 0,
						vaults = {
							msgId = {
								balance = gar.settings.minDelegatedStake,
								startTimestamp = startTimestamp,
								endTimestamp = gar.settings.delegatedStakeWithdrawLength,
							},
						},
					},
				},
				startTimestamp = startTimestamp,
				endTimestamp = gar.settings.gatewayLeaveLength,
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

	describe("increaseOperatorStake", function()
		it("should increase operator stake", function()
			token.balances["Bob"] = 1000
			gar.gateways["Bob"] = {
				operatorStake = gar.settings.minOperatorStake,
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
				operatorStake = gar.settings.minOperatorStake + 1000,
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
			})
		end)
	end)

	describe("decreaseOperatorStake", function()
		it("should decrease operator stake", function()
			gar.gateways["Bob"] = {
				operatorStake = gar.settings.minOperatorStake + 1000,
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
				operatorStake = gar.settings.minOperatorStake,
				totalDelegatedStake = 0,
				vaults = {
					msgId = {
						balance = 1000,
						startTimestamp = startTimestamp,
						endTimestamp = startTimestamp + gar.settings.operatorStakeWithdrawLength,
					},
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
				observerWallet = "observerWallet",
			})
		end)
	end)

	describe("updateGatewaySettings", function()
		it("should update gateway settings", function()
			gar.gateways["Bob"] = {
				operatorStake = gar.settings.minOperatorStake,
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
				minDelegatedStake = gar.settings.minDelegatedStake + 5,
			}
			local expectation = {
				operatorStake = gar.settings.minOperatorStake,
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
				status = "joined",
			}
			local status, result =
				pcall(gar.updateGatewaySettings, "Bob", updatedSettings, newObserverWallet, startTimestamp, "msgId")
			assert.is_true(status)
			assert.are.same(expectation, result)
			assert.are.same(expectation, gar.getGateway("Bob"))
		end)
	end)

	-- TODO: other tests for error conditions when joining/leaving network
	it("should get single gateway", function()
		gar.gateways["Bob"] = testGateway
		local result = gar.getGateway("Bob")
		assert.are.same(result, testGateway)
	end)

	it("should get multiple gateways", function()
		gar.gateways["Bob"] = testGateway
		gar.gateways["Alice"] = testGateway
		local result = gar.getGateways()
		assert.are.same(result, {
			Bob = testGateway,
			Alice = testGateway,
		})
	end)

	describe("delegateStake", function()
		it("should delegate stake to a gateway", function()
			token.balances["Alice"] = gar.settings.minDelegatedStake
			gar.gateways["Bob"] = {
				operatorStake = gar.settings.minOperatorStake,
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
			local result, err = gar.delegateStake("Alice", "Bob", gar.settings.minDelegatedStake, startTimestamp)
			assert.are.same(result, {
				operatorStake = gar.settings.minOperatorStake,
				totalDelegatedStake = gar.settings.minDelegatedStake,
				vaults = {},
				delegates = {
					Alice = {
						delegatedStake = gar.settings.minDelegatedStake,
						startTimestamp = startTimestamp,
						vaults = {},
					},
				},
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
			})
		end)

		it("should decrease delegated stake", function()
			gar.gateways["Bob"] = {
				operatorStake = gar.settings.minOperatorStake,
				totalDelegatedStake = gar.settings.minDelegatedStake + 1000,
				vaults = {},
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
				delegates = {
					Alice = {
						delegatedStake = gar.settings.minDelegatedStake + 1000,
						startTimestamp = 0,
						vaults = {},
					},
				},
			}

			local expectation = {
				operatorStake = gar.settings.minOperatorStake,
				totalDelegatedStake = gar.settings.minDelegatedStake,
				vaults = {},
				delegates = {
					Alice = {
						delegatedStake = gar.settings.minDelegatedStake,
						startTimestamp = 0,
						vaults = {
							msgId = {
								balance = 1000,
								startTimestamp = startTimestamp,
								endTimestamp = gar.settings.delegatedStakeWithdrawLength,
							},
						},
					},
				},
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
			local status, result = pcall(gar.decreaseDelegateStake, "Bob", "Alice", 1000, startTimestamp, "msgId")
			assert.is_true(status)
			assert.are.same(expectation, result)
			assert.are.same(expectation, gar.getGateway("Bob"))
		end)
	end)

	describe("getPrescribedObserversForEpoch", function()
		it("should return all eligible gateways if fewer than the maximum in network", function()
			gar.gateways["Bob"] = {
				operatorStake = gar.settings.minOperatorStake,
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
			local expectation = {
				{
					gatewayAddress = "Bob",
					observerAddress = "observerWallet",
					stake = gar.settings.minOperatorStake,
					startTimestamp = startTimestamp,
					stakeWeight = 1,
					tenureWeight = 1 / gar.settings.observers.tenureWeightPeriod,
					gatewayRewardRatioWeight = 1,
					observerRewardRatioWeight = 1,
					compositeWeight = 1 / gar.settings.observers.tenureWeightPeriod,
					normalizedCompositeWeight = 1,
				},
			}
			local status, result = pcall(
				gar.getPrescribedObserversForEpoch,
				gar.epoch.startTimestamp,
				gar.epoch.endTimestamp,
				"stubbed-hash-chain"
			)
			assert.is_true(status)
			assert.are.equal(1, #result)
			assert.are.same(expectation, result)
		end)

		it("should return the maximum number of gateways if more are enrolled in network", function()
			local gateways = {}
			for i = 1, gar.settings.observers.maxObserversPerEpoch + 1 do
				local gateway = {
					operatorStake = gar.settings.minOperatorStake + 1,
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
				gateways["Bob" .. i] = gateway
			end
			gar.gateways = gateways

			local expectation = {}
			for i = 1, gar.settings.observers.maxObserversPerEpoch do
				table.insert(expectation, {
					gatewayAddress = "Bob" .. i,
					observerAddress = "observerWallet",
					stake = gar.settings.minOperatorStake,
					startTimestamp = startTimestamp,
					stakeWeight = 1,
					tenureWeight = 1 / gar.settings.observers.tenureWeightPeriod,
					gatewayRewardRatioWeight = 1,
					observerRewardRatioWeight = 1,
					compositeWeight = 1 / gar.settings.observers.tenureWeightPeriod,
					normalizedCompositeWeight = 1,
				})
			end
			-- sort our expectations table
			table.sort(expectation, function(a, b)
				return a.normalizedCompositeWeight > b.normalizedCompositeWeight
			end)
			local status, result = pcall(
				gar.getPrescribedObserversForEpoch,
				gar.epoch.startTimestamp,
				gar.epoch.endTimestamp,
				"stubbedhashchain"
			)
			assert.is_true(status)
			assert.are.equal(gar.settings.observers.maxObserversPerEpoch, #result)
			-- TODO: assert.are.same(expectation, result)
			-- assert.are.same(expectation, result)
		end)
	end)
end)
