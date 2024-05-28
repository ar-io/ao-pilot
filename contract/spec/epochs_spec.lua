local epochs = require("epochs")

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
describe("epochs", function()
	before_each(function()
		_G.Balances = {
			["test-wallet-address-1"] = 500000000,
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
			gateways = {},
			settings = {
				observers = {
					maxObserversPerEpoch = 2,
					tenureWeightDays = 180,
					tenureWeightPeriod = 180 * 24 * 60 * 60 * 1000,
					maxTenureWeight = 4,
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
		}
	end)

	describe("computePrescribedObserversForEpoch", function()
		it("should return all eligible gateways if fewer than the maximum in network", function()
			GatewayRegistry.gateways["test-wallet-address-1"] = {
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
					gatewayAddress = "test-wallet-address-1",
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
			local status, result = pcall(epochs.computePrescribedObserversForEpoch, 0, "stubbed-hash-chain")
			assert.is_true(status)
			assert.are.equal(1, #result)
			assert.are.same(expectation, result)
		end)

		it("should return the maximum number of gateways if more are enrolled in network", function()
			local hashchain = "c29tZSBzYW1wbGUgaGFzaA==" -- base64 of "some sample hash"
			local gateways = {}
			epochs.updateEpochSettings({
				maxObservers = 2, -- limit to 2 observers
				epochZeroStartTimestamp = 0,
				durationMs = 60 * 1000 * 60 * 24, -- 24 hours
				distributionDelayMs = 60 * 1000 * 2 * 15, -- 15 blocks
			})
			for i = 1, 3 do
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
			local status, result = pcall(epochs.computePrescribedObserversForEpoch, 0, hashchain)
			assert.is_true(status)
			assert.are.equal(2, #result)
			assert.are.same(expectation, result)
		end)
	end)

	describe("saveObservations", function()
		it("should throw an error when saving observation too early in the epoch", function()
			local observer = "test-wallet-address-2"
			local reportTxId = "reportTxId"
			local timestamp = 1
			local failedGateways = {
				"test-wallet-address-1",
			}
			local status, error = pcall(epochs.saveObservations, observer, reportTxId, failedGateways, timestamp)
			assert.is_false(status)
			assert.match("Observations for the current epoch cannot be submitted before", error)
		end)
		it("should throw an error if the caller is not prescribed", function()
			local observer = "test-wallet-address-2"
			local reportTxId = "reportTxId"
			local timestamp = 60 * 1000 * 2 * 15 + 1 -- distribution delay + 1
			local failedGateways = {
				"test-wallet-address-1",
			}
			Epochs[0].prescribedObservers = {
				{
					gatewayAddress = "test-wallet-address-1",
					observerAddress = "test-wallet-address-1",
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
			local status, error = pcall(epochs.saveObservations, observer, reportTxId, failedGateways, timestamp)
			assert.is_false(status)
			assert.match("Caller is not a prescribed observer for the current epoch.", error)
		end)
		it(
			"should save observation when the timestamp is after the distribution delay and only mark gateways around during the full epoch as failed",
			function()
				local observer = "test-wallet-address-2"
				local reportTxId = "reportTxId"
				local timestamp = 60 * 1000 * 2 * 15 + 1 -- distribution delay + 1
				GatewayRegistry.gateways = {
					["test-wallet-address-1"] = {
						operatorStake = GatewayRegistry.settings.minOperatorStake,
						totalDelegatedStake = 0,
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
						observerWallet = "test-wallet-address-1",
					},
					["test-wallet-address-2"] = {
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
						observerWallet = "test-wallet-address-2",
					},
					["test-wallet-address-3"] = {
						operatorStake = GatewayRegistry.settings.minOperatorStake,
						totalDelegatedStake = 0,
						vaults = {},
						delegates = {},
						startTimestamp = startTimestamp + 10, -- joined after the epoch started
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
						observerWallet = "test-wallet-address-3",
					},
					["test-wallet-address-4"] = {
						operatorStake = GatewayRegistry.settings.minOperatorStake,
						totalDelegatedStake = 0,
						vaults = {},
						delegates = {},
						endTimestamp = startTimestamp + 10, -- left before the epoch ended
						startTimestamp = startTimestamp - 10,
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
						observerWallet = "test-wallet-address-4",
					},
				}
				Epochs[0].prescribedObservers = {
					{
						gatewayAddress = "test-wallet-address-2",
						observerAddress = "test-wallet-address-2",
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
					"test-wallet-address-1",
					"test-wallet-address-3",
				}
				local status, result = pcall(epochs.saveObservations, observer, reportTxId, failedGateways, timestamp)
				assert.is_true(status)
				assert.are.same(result, {
					reports = {
						[observer] = reportTxId,
					},
					failureSummaries = {
						["test-wallet-address-1"] = { observer },
					},
				})
			end
		)
	end)
end)
