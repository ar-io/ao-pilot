local epochs = require("epochs")
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
describe("epochs", function()
	before_each(function()
		_G.Balances = {
			["test-wallet-address-1"] = 500000000,
		}
		_G.Epochs = {
			[0] = {
				startTimestamp = 0,
				endTimestamp = 100,
				distributionTimestamp = 115,
				prescribedObservers = {},
				observations = {},
			},
		}
		_G.GatewayRegistry = {}
	end)

	describe("computePrescribedObserversForEpoch", function()
		it("should return all eligible gateways if fewer than the maximum in network", function()
			GatewayRegistry["test-wallet-address-1"] = {
				operatorStake = gar.getSettings().operators.minStake,
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
				observerAddress = "observerAddress",
			}
			local expectation = {
				{
					gatewayAddress = "test-wallet-address-1",
					observerAddress = "observerAddress",
					stake = gar.getSettings().operators.minStake,
					startTimestamp = startTimestamp,
					stakeWeight = 1,
					tenureWeight = 1 / gar.getSettings().observers.tenureWeightPeriod,
					gatewayRewardRatioWeight = 1,
					observerRewardRatioWeight = 1,
					compositeWeight = 1 / gar.getSettings().observers.tenureWeightPeriod,
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
			epochs.updateEpochSettings({
				maxObservers = 2, -- limit to 2 observers
				epochZeroStartTimestamp = startTimestamp,
				durationMs = 60 * 1000 * 60 * 24, -- 24 hours
				distributionDelayMs = 60 * 1000 * 2 * 15, -- 15 blocks
			})
			for i = 1, 3 do
				local gateway = {
					operatorStake = gar.getSettings().operators.minStake,
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
					observerAddress = "observerAddress",
				}
				-- note - ordering of keys is not guaranteed when insert into maps
				GatewayRegistry["observer" .. i] = gateway
			end

			local expectation = {
				{
					gatewayAddress = "observer2",
					observerAddress = "observerAddress",
					stake = gar.getSettings().operators.minStake,
					startTimestamp = startTimestamp,
					stakeWeight = 1,
					tenureWeight = 1 / gar.getSettings().observers.tenureWeightPeriod,
					gatewayRewardRatioWeight = 1,
					observerRewardRatioWeight = 1,
					compositeWeight = 1 / gar.getSettings().observers.tenureWeightPeriod,
					normalizedCompositeWeight = 1 / 3,
				},
				{
					gatewayAddress = "observer1",
					observerAddress = "observerAddress",
					stake = gar.getSettings().operators.minStake,
					startTimestamp = startTimestamp,
					stakeWeight = 1,
					tenureWeight = 1 / gar.getSettings().observers.tenureWeightPeriod,
					gatewayRewardRatioWeight = 1,
					observerRewardRatioWeight = 1,
					compositeWeight = 1 / gar.getSettings().observers.tenureWeightPeriod,
					normalizedCompositeWeight = 1 / 3,
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
					stake = gar.getSettings().operators.minStake,
					startTimestamp = startTimestamp,
					stakeWeight = 1,
					tenureWeight = 1 / gar.getSettings().observers.tenureWeightPeriod,
					gatewayRewardRatioWeight = 1,
					observerRewardRatioWeight = 1,
					compositeWeight = 1 / gar.getSettings().observers.tenureWeightPeriod,
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
				_G.GatewayRegistry = {
					["test-wallet-address-1"] = {
						operatorStake = gar.getSettings().operators.minStake,
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
						observerAddress = "test-wallet-address-1",
					},
					["test-wallet-address-2"] = {
						operatorStake = gar.getSettings().operators.minStake,
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
						observerAddress = "test-wallet-address-2",
					},
					["test-wallet-address-3"] = {
						operatorStake = gar.getSettings().operators.minStake,
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
						observerAddress = "test-wallet-address-3",
					},
					["test-wallet-address-4"] = {
						operatorStake = gar.getSettings().operators.minStake,
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
						observerAddress = "test-wallet-address-4",
					},
				}
				Epochs[0].prescribedObservers = {
					{
						gatewayAddress = "test-wallet-address-2",
						observerAddress = "test-wallet-address-2",
						stake = gar.getSettings().operators.minStake,
						startTimestamp = startTimestamp,
						stakeWeight = 1,
						tenureWeight = 1 / gar.getSettings().observers.tenureWeightPeriod,
						gatewayRewardRatioWeight = 1,
						observerRewardRatioWeight = 1,
						compositeWeight = 1 / gar.getSettings().observers.tenureWeightPeriod,
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

	describe("getPrescribedObserversForEpoch", function()
		it("should return the prescribed observers for the epoch", function()
			local epochIndex = 0
			local expectation = {}
			local result = epochs.getPrescribedObserversForEpoch(epochIndex)
			assert.are.same(result, expectation)
		end)
	end)

	describe("getEpochIndexForTimestamp", function()
		it("should return the epoch index for the given timestamp", function()
			-- update settings
			epochs.updateEpochSettings({
				epochZeroStartTimestamp = 0,
				durationMs = 10,
				distributionDelayMs = 15,
			})
			local timestamp = 100
			local result = epochs.getEpochIndexForTimestamp(timestamp)
			assert.are.equal(result, 10)
		end)
	end)

	describe("getEpochTimestampsForIndex", function()
		it("should return the epoch timestamps for the given epoch index", function()
			local epochIndex = 0
			epochs.updateEpochSettings({
				epochZeroStartTimestamp = 0,
				durationMs = 100,
				distributionDelayMs = 15,
			})
			local expectation = { 0, 100, 115, 0 }
			local result = { epochs.getEpochTimestampsForIndex(epochIndex) }
			assert.are.same(result, expectation)
		end)
	end)

	describe("createNewEpoch", function()
		it("should create a new epoch for the given timestamp", function()
			local timestamp = 100
			local epochIndex = 1
			local epochStartTimestamp = 100
			local epochEndTimestamp = 200
			local epochDistributionTimestamp = 215
			local expectation = {
				startTimestamp = epochStartTimestamp,
				endTimestamp = epochEndTimestamp,
				distributionTimestamp = epochDistributionTimestamp,
				observations = {
					failureSummaries = {},
					reports = {},
				},
				prescribedObservers = {},
				distributions = {},
			}
			epochs.createEpochForTimestamp(timestamp)
			assert.are.same(Epochs[epochIndex], expectation)
		end)
	end)
end)
