local epochs = require("epochs")
local gar = require("gar")
local balances = require("balances")
local json = require("json")
local testSettings = {
	fqdn = "test.com",
	protocol = "https",
	port = 443,
	allowDelegatedStaking = true,
	minDelegatedStake = 100,
	autoStake = true,
	label = "test",
	delegateRewardShareRatio = 0,
}
local startTimestamp = 0
local protocolBalance = 500000000 * 1000000
local hashchain = "NGU1fq_ssL9m6kRbRU1bqiIDBht79ckvAwRMGElkSOg" -- base64 of "some sample hash"

describe("epochs", function()
	before_each(function()
		_G.Balances = {
			[ao.id] = protocolBalance,
			["test-this-is-valid-arweave-wallet-address-1"] = 500000000,
		}
		_G.Epochs = {
			[0] = {
				startTimestamp = 0,
				endTimestamp = 100,
				distributionTimestamp = 115,
				prescribedObservers = {},
				distributions = {},
				observations = {
					failureSummaries = {},
					reports = {},
				},
			},
		}
		_G.GatewayRegistry = {}
		_G.NameRegistry = {
			records = {},
			reserved = {},
		}
		epochs.updateEpochSettings({
			prescribedNameCount = 5,
			maxObservers = 3,
			epochZeroStartTimestamp = 0,
			durationMs = 100,
			distributionDelayMs = 15,
			rewardPercentage = 0.0025, -- 0.25%
		})
	end)

	describe("computePrescribedObserversForEpoch", function()
		it("should return all eligible gateways if fewer than the maximum in network", function()
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
			local expectation = {
				{
					gatewayAddress = "test-this-is-valid-arweave-wallet-address-1",
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
			local status, result = pcall(epochs.computePrescribedObserversForEpoch, 0, hashchain)
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

	describe("computePrescrbiedNamesForEpoch", function()
		it("should return all eligible names if fewer than the maximum in name registry", function()
			_G.NameRegistry.records = {
				["arns-name-1"] = {
					startTimestamp = startTimestamp,
					endTimestamp = startTimestamp + 60 * 1000 * 60 * 24 * 365, -- add a year
					type = "lease",
					purchasePrice = 0,
					undernameLimit = 10,
				},
				["arns-name-2"] = {
					startTimestamp = startTimestamp,
					type = "permabuy",
					purchasePrice = 0,
					undernameLimit = 10,
				},
			}
			local expectation = { "arns-name-1", "arns-name-2" }
			local status, result = pcall(epochs.computePrescribedNamesForEpoch, 0, hashchain)
			assert.is_true(status)
			assert.are.equal(2, #result)
			assert.are.same(expectation, result)
		end)

		it("should return a subset of eligible names if more than the maximum in the name registry", function()
			_G.NameRegistry.records = {
				["arns-name-1"] = {
					startTimestamp = startTimestamp,
					endTimestamp = startTimestamp + 60 * 1000 * 60 * 24 * 365, -- add a year
					type = "lease",
					purchasePrice = 0,
					undernameLimit = 10,
				},
				["arns-name-2"] = {
					startTimestamp = startTimestamp,
					type = "permabuy",
					purchasePrice = 0,
					undernameLimit = 10,
				},
				["arns-name-3"] = {
					startTimestamp = startTimestamp,
					endTimestamp = startTimestamp + 60 * 1000 * 60 * 24 * 365, -- add a year
					type = "lease",
					purchasePrice = 0,
					undernameLimit = 10,
				},
				["arns-name-4"] = {
					startTimestamp = startTimestamp,
					type = "permabuy",
					purchasePrice = 0,
					undernameLimit = 10,
				},
				["arns-name-5"] = {
					startTimestamp = startTimestamp,
					type = "permabuy",
					purchasePrice = 0,
					undernameLimit = 10,
				},
				["arns-name-6"] = {
					startTimestamp = startTimestamp,
					endTimestamp = startTimestamp + 60 * 1000 * 60 * 24 * 365, -- add a year
					type = "lease",
					purchasePrice = 0,
					undernameLimit = 10,
				},
			}
			local expectation = { "arns-name-1", "arns-name-2", "arns-name-4", "arns-name-5", "arns-name-6" }
			local status, result = pcall(epochs.computePrescribedNamesForEpoch, 0, hashchain)
			assert.is_true(status)
			assert.are.equal(5, #result)
			assert.are.same(expectation, result)
		end)
	end)

	describe("saveObservations", function()
		it("should throw an error when saving observation too early in the epoch", function()
			local observer = "test-this-is-valid-arweave-wallet-address-2"
			local reportTxId = "test-this-very-valid-observations-report-tx"
			local timestamp = 1
			local failedGateways = {
				"test-this-is-valid-arweave-wallet-address-1",
			}
			local status, error = pcall(epochs.saveObservations, observer, reportTxId, failedGateways, timestamp)
			assert.is_false(status)
			assert.match("Observations for the current epoch cannot be submitted before", error)
		end)
		it("should throw an error if the caller is not prescribed", function()
			local observer = "test-this-is-valid-arweave-wallet-address-2"
			local reportTxId = "test-this-very-valid-observations-report-tx"
			local timestamp = epochs.getSettings().distributionDelayMs + 1
			local failedGateways = {
				"test-this-is-valid-arweave-wallet-address-1",
			}
			Epochs[0].prescribedObservers = {
				{
					gatewayAddress = "test-this-is-valid-arweave-wallet-address-1",
					observerAddress = "test-this-is-valid-arweave-wallet-address-1",
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
				local observer = "test-this-is-valid-arweave-wallet-address-2"
				local reportTxId = "test-this-very-valid-observations-report-tx"
				local timestamp = epochs.getSettings().distributionDelayMs + 1
				_G.GatewayRegistry = {
					["test-this-is-valid-arweave-wallet-address-1"] = {
						operatorStake = gar.getSettings().operators.minStake,
						totalDelegatedStake = 0,
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
						observerAddress = "test-this-is-valid-arweave-wallet-address-1",
					},
					["test-this-is-valid-arweave-wallet-address-2"] = {
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
						observerAddress = "test-this-is-valid-arweave-wallet-address-2",
					},
					["test-this-is-valid-arweave-wallet-address-3"] = {
						operatorStake = gar.getSettings().operators.minStake,
						totalDelegatedStake = 0,
						vaults = {},
						delegates = {},
						startTimestamp = startTimestamp + 10, -- joined after the epoch started
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
						observerAddress = "test-this-is-valid-arweave-wallet-address-3",
					},
					["test-this-is-valid-arweave-wallet-address-4"] = {
						operatorStake = gar.getSettings().operators.minStake,
						totalDelegatedStake = 0,
						vaults = {},
						delegates = {},
						endTimestamp = startTimestamp + 10, -- left before the epoch ended
						startTimestamp = startTimestamp - 10,
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
						observerAddress = "test-this-is-valid-arweave-wallet-address-4",
					},
				}
				_G.Epochs[0].prescribedObservers = {
					{
						gatewayAddress = "test-this-is-valid-arweave-wallet-address-2",
						observerAddress = "test-this-is-valid-arweave-wallet-address-2",
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
					"test-this-is-valid-arweave-wallet-address-1",
					"test-this-is-valid-arweave-wallet-address-3",
				}
				local status, result = pcall(epochs.saveObservations, observer, reportTxId, failedGateways, timestamp)
				assert.is_true(status)
				assert.are.same(result, {
					reports = {
						[observer] = reportTxId,
					},
					failureSummaries = {
						["test-this-is-valid-arweave-wallet-address-1"] = { observer },
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
			local timestamp = epochs.getSettings().epochZeroStartTimestamp + epochs.getSettings().durationMs + 1
			local result = epochs.getEpochIndexForTimestamp(timestamp)
			assert.are.equal(result, 1)
		end)
	end)

	describe("getEpochTimestampsForIndex", function()
		it("should return the epoch timestamps for the given epoch index", function()
			local epochIndex = 0
			local expectation = { 0, 100, 115 }
			local result = { epochs.getEpochTimestampsForIndex(epochIndex) }
			assert.are.same(result, expectation)
		end)
	end)

	describe("createEpoch", function()
		it(
			"should create a new epoch for the given timestamp once distributions for the last epoch have occurred",
			function()
				local timestamp = 100
				local epochIndex = 1
				local epochStartTimestamp = 100
				local epochEndTimestamp = 200
				local epochDistributionTimestamp = 215
				local epochStartBlockHeight = 0
				local expectation = {
					startTimestamp = epochStartTimestamp,
					endTimestamp = epochEndTimestamp,
					epochIndex = epochIndex,
					startHeight = 0,
					distributionTimestamp = epochDistributionTimestamp,
					observations = {
						failureSummaries = {},
						reports = {},
					},
					prescribedObservers = {},
					prescribedNames = {},
					distributions = {},
				}
				_G.Epochs[0].distributions = {
					totalEligibleRewards = 0,
					totalDistributedRewards = 0,
					distributedTimestamp = 0,
					rewards = {},
				}
				local status = pcall(epochs.createEpoch, timestamp, epochStartBlockHeight, hashchain)
				assert.is_true(status)
				assert.are.same(epochs.getEpoch(epochIndex), expectation)
			end
		)
	end)

	describe("distributeRewardsForEpoch", function()
		it("should distribute rewards for the epoch", function()
			local epochIndex = 0
			local hashchain = "c29tZSBzYW1wbGUgaGFzaA==" -- base64 of "some sample hash"
			for i = 1, 3 do
				local gateway = {
					operatorStake = gar.getSettings().operators.minStake,
					totalDelegatedStake = 0,
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
					settings = {
						fqdn = "test.com",
						protocol = "https",
						port = 443,
						allowDelegatedStaking = true,
						minDelegatedStake = 100,
						autoStake = false, -- TODO: validate autostake behavior
						label = "test",
						properties = "",
						delegateRewardShareRatio = 20,
					},
					status = "joined",
					observerAddress = "test-this-very-valid-observer-wallet-addr-" .. i,
				}
				gar.addGateway("test-this-is-valid-arweave-wallet-address-" .. i, gateway)
			end
			epochs.setPrescribedObserversForEpoch(epochIndex, hashchain)
			-- save observations using saveObsevations function for each gateway, gateway1 failed, gateway2 and gateway3 passed
			local failedGateways = {
				"test-this-is-valid-arweave-wallet-address-1",
			}
			local epochStartTimetamp, epochEndTimestamp, epochDistributionTimestamp =
				epochs.getEpochTimestampsForIndex(epochIndex)
			local validObservationTimestamp = epochStartTimetamp + epochs.getSettings().distributionDelayMs + 1
			-- save observations for the epoch for last two gateways
			for i = 2, 3 do
				local status, result = pcall(
					epochs.saveObservations,
					"test-this-very-valid-observer-wallet-addr-" .. i,
					"test-this-very-valid-observations-report-0" .. i,
					failedGateways,
					validObservationTimestamp
				)
				assert.is_true(status)
			end
			-- set the protocol balance to 5 million IO
			local totalEligibleRewards = math.floor(protocolBalance * 0.0025)
			local expectedGatewaryReward = math.floor(totalEligibleRewards * 0.95 / 3)
			local expectedObserverReward = math.floor(totalEligibleRewards * 0.05 / 3)
			-- clear the balances for the gateways
			Balances["test-this-is-valid-arweave-wallet-address-1"] = 0

			-- distribute rewards for the epoch
			local status = pcall(epochs.distributeRewardsForEpoch, epochDistributionTimestamp)
			assert.is_true(status)
			-- gateway 1 should only get observer rewards
			-- gateway 2 should get obesrver and gateway rewards
			-- gateway 3 should get observer and gateway rewards
			local gateway1 = gar.getGateway("test-this-is-valid-arweave-wallet-address-1")
			local gateway2 = gar.getGateway("test-this-is-valid-arweave-wallet-address-2")
			local gateway3 = gar.getGateway("test-this-is-valid-arweave-wallet-address-3")
			assert.are.same({
				prescribedEpochCount = 1,
				observedEpochCount = 0,
				passedEpochCount = 0,
				failedEpochCount = 1,
				failedConsecutiveEpochs = 1,
				passedConsecutiveEpochs = 0,
				totalEpochCount = 1,
			}, gateway1.stats)
			assert.are.same({
				prescribedEpochCount = 1,
				observedEpochCount = 1,
				passedEpochCount = 1,
				failedEpochCount = 0,
				failedConsecutiveEpochs = 0,
				passedConsecutiveEpochs = 1,
				totalEpochCount = 1,
			}, gateway2.stats)

			assert.are.same({
				prescribedEpochCount = 1,
				observedEpochCount = 1,
				passedEpochCount = 1,
				failedEpochCount = 0,
				failedConsecutiveEpochs = 0,
				passedConsecutiveEpochs = 1,
				totalEpochCount = 1,
			}, gateway3.stats)
			-- check balances
			assert.are.equal(0, balances.getBalance("test-this-is-valid-arweave-wallet-address-1"))
			assert.are.equal(
				expectedGatewaryReward + expectedObserverReward,
				balances.getBalance("test-this-is-valid-arweave-wallet-address-2")
			)
			assert.are.equal(
				expectedGatewaryReward + expectedObserverReward,
				balances.getBalance("test-this-is-valid-arweave-wallet-address-3")
			)
			-- check the epoch was updated
			local distributions = epochs.getEpoch(epochIndex).distributions
			assert.are.same({
				totalEligibleRewards = totalEligibleRewards,
				totalDistributedRewards = (expectedGatewaryReward + expectedObserverReward) * 2,
				distributedTimestamp = epochDistributionTimestamp,
				rewards = {
					["test-this-is-valid-arweave-wallet-address-2"] = expectedGatewaryReward + expectedObserverReward,
					["test-this-is-valid-arweave-wallet-address-3"] = expectedGatewaryReward + expectedObserverReward,
				},
			}, distributions)
		end)
	end)
end)
