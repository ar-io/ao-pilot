local gar = require("gar")
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
		_G.Balances = {
			Bob = GatewayRegistry.settings.minOperatorStake,
		}
		_G.Epochs = {
			[0] = {
				startTimestamp = 0,
				endTimestamp = 100,
				prescribedObservers = {},
				observations = {},
			},
		}
		_G.GatewayRegistry = {
			epochs = {},
			gateways = {},
			settings = {
				observers = {
					maxObserversPerEpoch = 2,
					tenureWeightDays = 180,
					tenureWeightPeriod = 180 * 24 * 60 * 60 * 1000,
					maxTenureWeight = 4,
				},
				epochs = {
					durationMs = 24 * 60 * 60 * 1000, -- One day of miliseconds
					epochZeroStartTimestamp = 0,
					distributionDelayMs = 30 * 60 * 1000, -- 30 minutes of miliseconds
				},
				-- TODO: move this to a nested object for gateways
				minDelegatedStake = 50 * 1000000, -- 50 IO
				minOperatorStake = 10000 * 1000000, -- 10,000 IO
				gatewayLeaveLength = 90 * 24 * 60 * 60 * 1000, -- 90 days
				maxLockLength = 3 * 365 * 24 * 60 * 60 * 1000, -- 3 years
				minLockLength = 24 * 60 * 60 * 1000, -- 1 day
				operatorStakeWithdrawLength = 30 * 24 * 60 * 60 * 1000, -- 30 days
				delegatedStakeWithdrawLength = 30 * 24 * 60 * 60 * 1000, -- 30 days
				maxDelegates = 10000,
			},
			epoch = {
				startTimestamp = 0,
				endTimestamp = 100,
			},
		}
	end)

	describe("joinNetwork", function()
		it("should fail if the gateway is already in the network", function()
			GatewayRegistry.gateways["Bob"] = {
				operatorStake = GatewayRegistry.settings.minOperatorStake,
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
				GatewayRegistry.settings.minOperatorStake,
				testSettings,
				"observerWallet",
				startTimestamp
			)
			assert.is_false(status)
			assert.match("Gateway already exists", error)
		end)
		it("should join the network", function()
			local expectation = {
				operatorStake = GatewayRegistry.settings.minOperatorStake,
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
				GatewayRegistry.settings.minOperatorStake,
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
			GatewayRegistry.gateways["Bob"] = {
				operatorStake = (GatewayRegistry.settings.minOperatorStake + 1000),
				totalDelegatedStake = GatewayRegistry.settings.minDelegatedStake,
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

			GatewayRegistry.gateways["Bob"].delegates["Alice"] = {
				delegatedStake = GatewayRegistry.settings.minDelegatedStake,
				startTimestamp = 0,
				vaults = {},
			}

			local result, err = gar.leaveNetwork("Bob", startTimestamp, "msgId")
			assert.are.same(result, {
				operatorStake = 0,
				totalDelegatedStake = 0,
				vaults = {
					Bob = {
						balance = GatewayRegistry.settings.minOperatorStake,
						startTimestamp = startTimestamp,
						endTimestamp = GatewayRegistry.settings.gatewayLeaveLength,
					},
					msgId = {
						balance = 1000,
						startTimestamp = startTimestamp,
						endTimestamp = GatewayRegistry.settings.operatorStakeWithdrawLength,
					},
				},
				delegates = {
					Alice = {
						delegatedStake = 0,
						startTimestamp = 0,
						vaults = {
							msgId = {
								balance = GatewayRegistry.settings.minDelegatedStake,
								startTimestamp = startTimestamp,
								endTimestamp = GatewayRegistry.settings.delegatedStakeWithdrawLength,
							},
						},
					},
				},
				startTimestamp = startTimestamp,
				endTimestamp = GatewayRegistry.settings.gatewayLeaveLength,
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
			Balances["Bob"] = 1000
			GatewayRegistry.gateways["Bob"] = {
				operatorStake = GatewayRegistry.settings.minOperatorStake,
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
				operatorStake = GatewayRegistry.settings.minOperatorStake + 1000,
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
			GatewayRegistry.gateways["Bob"] = {
				operatorStake = GatewayRegistry.settings.minOperatorStake + 1000,
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
				operatorStake = GatewayRegistry.settings.minOperatorStake,
				totalDelegatedStake = 0,
				vaults = {
					msgId = {
						balance = 1000,
						startTimestamp = startTimestamp,
						endTimestamp = startTimestamp + GatewayRegistry.settings.operatorStakeWithdrawLength,
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
			GatewayRegistry.gateways["Bob"] = {
				operatorStake = GatewayRegistry.settings.minOperatorStake,
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
				minDelegatedStake = GatewayRegistry.settings.minDelegatedStake + 5,
			}
			local expectation = {
				operatorStake = GatewayRegistry.settings.minOperatorStake,
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

	describe("delegateStake", function()
		it("should delegate stake to a gateway", function()
			Balances["Alice"] = GatewayRegistry.settings.minDelegatedStake
			GatewayRegistry.gateways["Bob"] = {
				operatorStake = GatewayRegistry.settings.minOperatorStake,
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
			local result, err =
				gar.delegateStake("Alice", "Bob", GatewayRegistry.settings.minDelegatedStake, startTimestamp)
			assert.are.same(result, {
				operatorStake = GatewayRegistry.settings.minOperatorStake,
				totalDelegatedStake = GatewayRegistry.settings.minDelegatedStake,
				vaults = {},
				delegates = {
					Alice = {
						delegatedStake = GatewayRegistry.settings.minDelegatedStake,
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
			GatewayRegistry.gateways["Bob"] = {
				operatorStake = GatewayRegistry.settings.minOperatorStake,
				totalDelegatedStake = GatewayRegistry.settings.minDelegatedStake + 1000,
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
						delegatedStake = GatewayRegistry.settings.minDelegatedStake + 1000,
						startTimestamp = 0,
						vaults = {},
					},
				},
			}

			local expectation = {
				operatorStake = GatewayRegistry.settings.minOperatorStake,
				totalDelegatedStake = GatewayRegistry.settings.minDelegatedStake,
				vaults = {},
				delegates = {
					Alice = {
						delegatedStake = GatewayRegistry.settings.minDelegatedStake,
						startTimestamp = 0,
						vaults = {
							msgId = {
								balance = 1000,
								startTimestamp = startTimestamp,
								endTimestamp = GatewayRegistry.settings.delegatedStakeWithdrawLength,
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

	describe("computePrescribedObserversForEpoch", function()
		it("should return all eligible gateways if fewer than the maximum in network", function()
			GatewayRegistry.gateways["Bob"] = {
				operatorStake = GatewayRegistry.settings.minOperatorStake,
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
					stake = GatewayRegistry.settings.minOperatorStake,
					startTimestamp = startTimestamp,
					stakeWeight = 1,
					tenureWeight = 1 / GatewayRegistry.settings.observers.tenureWeightPeriod,
					gatewayRewardRatioWeight = 1,
					observerRewardRatioWeight = 1,
					compositeWeight = 1 / GatewayRegistry.settings.observers.tenureWeightPeriod,
					normalizedCompositeWeight = 1,
				},
			}
			local status, result = pcall(gar.computePrescribedObserversForEpoch, 0, "stubbed-hash-chain")
			assert.is_true(status)
			assert.are.equal(1, #result)
			assert.are.same(expectation, result)
		end)

		it("should return the maximum number of gateways if more are enrolled in network", function()
			local hashchain = "c29tZSBzYW1wbGUgaGFzaA==" -- base64 of "some sample hash"

			local gateways = {}
			for i = 1, GatewayRegistry.settings.observers.maxObserversPerEpoch + 1 do
				local gateway = {
					operatorStake = GatewayRegistry.settings.minOperatorStake,
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
				-- note - ordering of keys is not guaranteed when insert into maps
				gateways["observer" .. i] = gateway
			end
			GatewayRegistry.gateways = gateways

			local expectation = {
				{
					gatewayAddress = "observer2",
					observerAddress = "observerWallet",
					stake = GatewayRegistry.settings.minOperatorStake,
					startTimestamp = startTimestamp,
					stakeWeight = 1,
					tenureWeight = 1 / GatewayRegistry.settings.observers.tenureWeightPeriod,
					gatewayRewardRatioWeight = 1,
					observerRewardRatioWeight = 1,
					compositeWeight = 1 / GatewayRegistry.settings.observers.tenureWeightPeriod,
					normalizedCompositeWeight = 1 / (GatewayRegistry.settings.observers.maxObserversPerEpoch + 1),
				},
				{
					gatewayAddress = "observer1",
					observerAddress = "observerWallet",
					stake = GatewayRegistry.settings.minOperatorStake,
					startTimestamp = startTimestamp,
					stakeWeight = 1,
					tenureWeight = 1 / GatewayRegistry.settings.observers.tenureWeightPeriod,
					gatewayRewardRatioWeight = 1,
					observerRewardRatioWeight = 1,
					compositeWeight = 1 / GatewayRegistry.settings.observers.tenureWeightPeriod,
					normalizedCompositeWeight = 1 / (GatewayRegistry.settings.observers.maxObserversPerEpoch + 1),
				},
			}
			local status, result = pcall(gar.computePrescribedObserversForEpoch, 0, hashchain)
			assert.is_true(status)
			assert.are.equal(GatewayRegistry.settings.observers.maxObserversPerEpoch, #result)
			assert.are.same(expectation, result)
		end)
	end)

	describe("getters", function()
		-- TODO: other tests for error conditions when joining/leaving network
		it("should get single gateway", function()
			GatewayRegistry.gateways["Bob"] = testGateway
			local result = gar.getGateway("Bob")
			assert.are.same(result, testGateway)
		end)

		it("should get multiple gateways", function()
			GatewayRegistry.gateways["Bob"] = testGateway
			GatewayRegistry.gateways["Alice"] = testGateway
			local result = gar.getGateways()
			assert.are.same(result, {
				Bob = testGateway,
				Alice = testGateway,
			})
		end)
	end)

	describe("saveObservations", function()
		it('should throw an error when saving observation too early in the epoch', function()
			local observer = "Alice"
			local reportTxId = "reportTxId"
			local timestamp = 1
			local failedGateways = {
				"Bob",
			}
			local status, error = pcall(gar.saveObservations, observer, reportTxId, failedGateways, timestamp)
			assert.is_false(status)
			assert.match("Observations for the current epoch cannot be submitted before", error)
		end)
		it("should save observation when the timestamp is after the distribution delay", function()
			local observer = "Alice"
			local reportTxId = "reportTxId"
			local timestamp = gar.getSettings().epochs.distributionDelayMs + 1
			GatewayRegistry.gateways = {
				Bob = {
					operatorStake = GatewayRegistry.settings.minOperatorStake,
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
					observerWallet = "Bob",
				},
				["Alice"] = {
					operatorStake = GatewayRegistry.settings.minOperatorStake,
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
					observerWallet = "Alice",
				},
			}
			Epochs[0].prescribedObservers = {
				{
					gatewayAddress = "Alice",
					observerAddress = "Alice",
					stake = GatewayRegistry.settings.minOperatorStake,
					startTimestamp = startTimestamp,
					stakeWeight = 1,
					tenureWeight = 1 / GatewayRegistry.settings.observers.tenureWeightPeriod,
					gatewayRewardRatioWeight = 1,
					observerRewardRatioWeight = 1,
					compositeWeight = 1 / GatewayRegistry.settings.observers.tenureWeightPeriod,
					normalizedCompositeWeight = 1,
				},
			}
			local failedGateways = {
				"Bob",
			}
			local status, result = pcall(gar.saveObservations, observer, reportTxId, failedGateways, timestamp)
			assert.is_true(status)
			assert.are.same(result, {
				reports = {
					[observer] = reportTxId,
				},
				failureSummaries = {
					["Bob"] = { observer },
				},
			})
		end)
	end)
end)
