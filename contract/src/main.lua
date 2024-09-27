-- Adjust package.path to include the current directory
local process = { _version = "0.0.1" }

Name = "Devnet IO"
Ticker = "dIO"
Logo = "Sie_26dvgyok0PZD_-iQAFOhOd5YxDTkczOLoqTTL_A"
Denomination = 6
DemandFactor = DemandFactor or {}
Balances = Balances or {
	[ao.id] = 1000000000 * 1000000,
}
Vaults = Vaults or {}
GatewayRegistry = GatewayRegistry or {}
NameRegistry = NameRegistry or {}
Epochs = Epochs or {}
LastTickedEpoch = LastTickedEpoch or 0

local utils = require("utils")
local json = require("json")
local ao = ao or require("ao")
local balances = require("balances")
local arns = require("arns")
local gar = require("gar")
local demand = require("demand")
local epochs = require("epochs")
local vaults = require("vaults")

local ActionMap = {
	-- reads
	Info = "Info",
	State = "State",
	Transfer = "Transfer",
	Balance = "Balance",
	Balances = "Balances",
	DemandFactor = "DemandFactor",
	-- EPOCH READ APIS
	Epochs = "Epochs",
	Epoch = "Epoch",
	PrescribedObservers = "EpochPrescribedObservers",
	PrescribedNames = "EpochPrescribedNames",
	Observations = "EpochObservations",
	Distributions = "EpochDistributions",
	-- NAME REGISTRY READ APIS
	Record = "Record",
	Records = "Records",
	ReservedNames = "ReservedNames",
	ReservedName = "ReservedName",
	-- GATEWAY REGISTRY READ APIS
	Gateway = "Gateway",
	Gateways = "Gateways",
	-- writes
	CreateVault = "CreateVault",
	VaultedTransfer = "VaultedTransfer",
	ExtendVault = "ExtendVault",
	IncreaseVault = "IncreaseVault",
	BuyRecord = "BuyRecord",
	ExtendLease = "ExtendLease",
	IncreaseUndernameCount = "IncreaseUndernameCount",
	JoinNetwork = "JoinNetwork",
	LeaveNetwork = "LeaveNetwork",
	IncreaseOperatorStake = "IncreaseOperatorStake",
	DecreaseOperatorStake = "DecreaseOperatorStake",
	UpdateGatewaySettings = "UpdateGatewaySettings",
	SaveObservations = "SaveObservations",
	DelegateStake = "DelegateStake",
	DecreaseDelegateStake = "DecreaseDelegateStake",
}

-- Write handlers
Handlers.add(ActionMap.Transfer, utils.hasMatchingTag("Action", ActionMap.Transfer), function(msg)
	-- assert recipient is a valid arweave address
	local function checkAssertions()
		assert(utils.isValidArweaveAddress(msg.Tags.Recipient), "Invalid recipient")
		assert(tonumber(msg.Tags.Quantity) > 0, "Invalid quantity")
	end

	local inputStatus, inputResult = pcall(checkAssertions)

	if not inputStatus then
		ao.send({
			Target = msg.From,
			Tags = { Error = "Transfer-Error" },
			Data = tostring(inputResult),
		})
		return
	end

	local status, result = pcall(balances.transfer, msg.Tags.Recipient, msg.From, tonumber(msg.Tags.Quantity))
	if not status then
		ao.send({
			Target = msg.From,
			Tags = { Action = ActionMap.Transfer, Error = "Transfer-Error"},
			Data = tostring(result),
		})
	else
		if msg.Cast then
			-- Send Debit-Notice to the Sender
			ao.send({
				Target = msg.From,
				Action = "Debit-Notice",
				Recipient = msg.Tags.Recipient,
				Quantity = tostring(msg.Tags.Quantity),
				Data = "You transferred " .. msg.Tags.Quantity .. " to " .. msg.Tags.Recipient,
			})
			if msg.Tags.Function and msg.Tags.Parameters then
				-- Send Credit-Notice to the Recipient and include the function and parameters tags
				ao.send({
					Target = msg.Tags.Recipient,
					Action = "Credit-Notice",
					Sender = msg.From,
					Quantity = tostring(msg.Tags.Quantity),
					Function = tostring(msg.Tags.Function),
					Parameters = msg.Tags.Parameters,
					Data = "You received "
						.. msg.Tags.Quantity
						.. " from "
						.. msg.Tags.Recipient
						.. " with the instructions for function "
						.. msg.Tags.Function
						.. " with the parameters "
						.. msg.Tags.Parameters,
				})
			else
				-- Send Credit-Notice to the Recipient
				ao.send({
					Target = msg.Tags.Recipient,
					Action = "Credit-Notice",
					Sender = msg.From,
					Quantity = tostring(msg.Tags.Quantity),
					Data = "You received " .. msg.Tags.Quantity .. " from " .. msg.Tags.Recipient,
				})
			end
		end
	end
end)

Handlers.add(ActionMap.CreateVault, utils.hasMatchingTag("Action", ActionMap.CreateVault), function(msg)
	local function checkAssertions()
		assert(tonumber(msg.Tags.Quantity) > 0, "Invalid quantity")
		assert(tonumber(msg.Tags.LockLength) > 0, "Invalid lock length")
	end

	local inputStatus, inputResult = pcall(checkAssertions)

	if not inputStatus then
		ao.send({
			Target = msg.From,
			Tags = { Action = "Invalid-Create-Vault", Error = "Bad-Input"},
			Data = tostring(inputResult),
		})
		return
	end

	local result, err = balances.createVault(msg.From, msg.Tags.Quantity, msg.Tags.LockLength, msg.Timestamp, msg.Id)
	if err then
		ao.send({
			Target = msg.From,
			Tags = { Action = "Invalid-Create-Vault", Error = "Invalid-Create-Vault" },
			Data = tostring(err),
		})
	else
		ao.send({
			Target = msg.From,
			Tags = { Action = "Vault-Created-Notice" },
			Data = tostring(json.encode(result)),
		})
	end
end)

Handlers.add(ActionMap.VaultedTransfer, utils.hasMatchingTag("Action", ActionMap.VaultedTransfer), function(msg)
	local function checkAssertions()
		assert(utils.isValidArweaveAddress(msg.Tags.Recipient), "Invalid recipient")
		assert(tonumber(msg.Tags.Quantity) > 0, "Invalid quantity")
		assert(tonumber(msg.Tags.LockLength) > 0, "Invalid lock length")
	end

	local inputStatus, inputResult = pcall(checkAssertions)

	if not inputStatus then
		ao.send({
			Target = msg.From,
			Tags = { Action = "Invalid-Vaulted-Transfer", Error = "Bad-Input"},
			Data = tostring(inputResult),
		})
		return
	end

	local result, err = balances.vaultedTransfer(
		msg.From,
		msg.Tags.Recipient,
		msg.Tags.Quantity,
		msg.Tags.LockLength,
		msg.Timestamp,
		msg.Id
	)
	if err then
		ao.send({
			Target = msg.From,
			Tags = { Action = "Invalid-Vaulted-Transfer", Error = "Invalid-Vaulted-Transfer"},
			Data = tostring(err),
		})
	else
		ao.send({
			Target = msg.From,
			Tags = { Action = "Debit-Notice" },
			Data = tostring(json.encode(result)),
		})
		ao.send({
			Target = msg.Tags.Recipient,
			Tags = { Action = "Vaulted-Credit-Notice" },
			Data = tostring(json.encode(result)),
		})
	end
end)

Handlers.add(ActionMap.ExtendVault, utils.hasMatchingTag("Action", ActionMap.ExtendVault), function(msg)
	local checkAssertions = function()
		assert(tonumber(msg.Tags.ExtendLength) > 0, "Invalid extend length")
		assert(utils.isValidArweaveAddress(msg.Tags.VaultId), "Invalid vault id")
	end

	local inputStatus, inputResult = pcall(checkAssertions)

	if not inputStatus then
		ao.send({
			Target = msg.From,
			Tags = { Action = "Invalid-Extend-Vault", Error = "Bad-Input"},
			Data = tostring(inputResult),
		})
		return
	end

	local result, err = balances.extendVault(msg.From, msg.Tags.ExtendLength, msg.Timestamp, msg.Tags.VaultId)
	if err then
		ao.send({
			Target = msg.From,
			Tags = { Action = "Invalid-Extend-Vault", Error = "Invalid-Extend-Vault"},
			Data = tostring(err),
		})
	else
		ao.send({
			Target = msg.From,
			Tags = { Action = "Vault-Extended" },
			Data = tostring(json.encode(result)),
		})
	end
end)

Handlers.add(ActionMap.IncreaseVault, utils.hasMatchingTag("Action", ActionMap.IncreaseVault), function(msg)
	local function checkAssertions()
		assert(tonumber(msg.Tags.Quantity) > 0, "Invalid quantity")
		assert(utils.isValidArweaveAddress(msg.Tags.VaultId), "Invalid vault id")
	end

	local inputStatus, inputResult = pcall(checkAssertions)

	if not inputStatus then
		ao.send({
			Target = msg.From,
			Tags = { Action = "Invalid-Increase-Vault", Error = "Bad-Input"},
			Data = tostring(inputResult),
		})
		return
	end

	local result, err = balances.increaseVault(msg.From, msg.Tags.Quantity, msg.Tags.VaultId, msg.Timestamp)
	if err then
		ao.send({
			Target = msg.From,
			Tags = { Action = "Invalid-Increase-Vault", Error = "Invalid-Increase-Vault"},
			Data = tostring(err),
		})
	else
		ao.send({
			Target = msg.From,
			Tags = { Action = "Vault-Increased" },
			Data = tostring(json.encode(result)),
		})
	end
end)

Handlers.add(ActionMap.BuyRecord, utils.hasMatchingTag("Action", ActionMap.BuyRecord), function(msg)
	-- assert name is a string
	assert(type(msg.Tags.Name) == "string", "Invalid name")
	-- assert purchase type is a string
	assert(type(msg.Tags.PurchaseType) == "string", "Invalid purchase type")
	-- assert years is a positive number and less than 5
	assert(tonumber(msg.Tags.Years) > 0 and tonumber(msg.Tags.Years) < 5, "Invalid years")

	local checkAssertions = function()
		assert(type(msg.Tags.Name) == "string", "Invalid name")
		assert(type(msg.Tags.PurchaseType) == "string", "Invalid purchase type")
		assert(tonumber(msg.Tags.Years) > 0 and tonumber(msg.Tags.Years) < 5, "Invalid years")
	end

	local inputStatus, inputResult = pcall(checkAssertions)

	if not inputStatus then
		ao.send({
			Target = msg.From,
			Tags = { Action = "ArNS-Invalid-Buy-Record-Notice", Error = "Bad-Input"},
			Data = tostring(inputResult),
		})
		return
	end

	local status, result = pcall(
		arns.buyRecord,
		msg.Tags.Name,
		msg.Tags.PurchaseType,
		msg.Tags.Years,
		msg.From,
		msg.Timestamp,
		msg.Tags.ProcessId
	)
	if not status then
		ao.send({
			Target = msg.From,
			Tags = {
				Action = "ArNS-Invalid-Buy-Record-Notice",
				Error = "Invalid-Buy-Record",
			},
			Data = tostring(result),
		})
		return
	else
		ao.send({
			Target = msg.From,
			Tags = { Action = "ArNS-Purchase-Notice" },
			Data = tostring(json.encode(result)),
		})
	end
end)

Handlers.add(ActionMap.ExtendLease, utils.hasMatchingTag("Action", ActionMap.ExtendLease), function(msg)
	-- assert name is a string
	assert(type(msg.Tags.Name) == "string", "Invalid name")
	-- assert years is a positive number and less than 5
	assert(tonumber(msg.Tags.Years) > 0 and tonumber(msg.Tags.Years) < 5, "Invalid years")

	local status, result = pcall(arns.extendLease, msg.From, msg.Tags.Name, msg.Tags.Years, msg.Timestamp)
	if not status then
		ao.send({
			Target = msg.From,
			Tags = { Action = "Invalid-Extend-Lease", Error = "Invalid-Extend-Lease"},
			Data = tostring(result),
		})
	else
		ao.send({
			Target = msg.From,
			Tags = { Action = "Lease-Extended" },
			Data = tostring(json.encode(result)),
		})
	end
end)

Handlers.add(
	ActionMap.IncreaseUndernameCount,
	utils.hasMatchingTag("Action", ActionMap.IncreaseUndernameCount),
	function(msg)
		assert(type(msg.Tags.Name) == "string", "Invalid name")
		assert(tonumber(msg.Tags.Quantity) > 0, "Invalid quantity")

		local status, result =
			pcall(arns.increaseUndernameCount, msg.From, msg.Tags.Name, msg.Tags.Quantity, msg.Timestamp)
		if not status then
			ao.send({
				Target = msg.From,
				Tags = { Action = "Invalid-Undername-Increase", Error = "Invalid-Undername-Increase"},
				Data = tostring(result),
			})
		else
			ao.send({
				Target = msg.From,
				Tags = { Action = "Undername-Quantity-Increased" },
				Data = tostring(json.encode(result)),
			})
		end
	end
)

Handlers.add(ActionMap.JoinNetwork, utils.hasMatchingTag("Action", ActionMap.JoinNetwork), function(msg)
	local updatedSettings = {
		label = msg.Tags.Label,
		note = msg.Tags.Note,
		fqdn = msg.Tags.FQDN,
		port = tonumber(msg.Tags.Port) or 443,
		protocol = msg.Tags.Protocol or "https",
		allowDelegatedStaking = msg.Tags.AllowDelegatedStaking == "true",
		minDelegatedStake = tonumber(msg.Tags.MinDelegatedStake),
		delegateRewardShareRatio = tonumber(msg.Tags.DelegateRewardShareRatio) or 0,
		properties = msg.Tags.Properties or "FH1aVetOoulPGqgYukj0VE0wIhDy90WiQoV3U2PeY44",
		autoStake = msg.Tags.AutoStake == "true",
	}
	local observerAddress = msg.Tags.ObserverAddress or msg.Tags.From

	local status, result =
		pcall(gar.joinNetwork, msg.From, tonumber(msg.Tags.OperatorStake), updatedSettings, observerAddress, msg.Timestamp)
	if not status then
		ao.send({
			Target = msg.From,
			Tags = { Action = "GAR-Invalid-Network-Join", Error = "Invalid-Network-Join"},
			Data = tostring(result),
		})
	else
		ao.send({
			Target = msg.From,
			Tags = { Action = "GAR-Joined-Network" },
			Data = tostring(json.encode(result)),
		})
	end
end)

Handlers.add(ActionMap.LeaveNetwork, utils.hasMatchingTag("Action", ActionMap.LeaveNetwork), function(msg)
	local status, result = pcall(gar.leaveNetwork, msg.From, msg.Timestamp, msg.Id)
	if not status then
		ao.send({
			Target = msg.From,
			Tags = { Action = "GAR-Invalid-Network-Leave", Error = "Invalid-Network-Leave"},
			Data = tostring(result),
		})
	else
		ao.send({
			Target = msg.From,
			Tags = { Action = "GAR-Leaving-Network" },
			Data = tostring(json.encode(result)),
		})
	end
end)

Handlers.add(
	ActionMap.IncreaseOperatorStake,
	utils.hasMatchingTag("Action", ActionMap.IncreaseOperatorStake),
	function(msg)
		local checkAssertions = function()
			assert(tonumber(msg.Tags.Quantity) > 0, "Invalid quantity")
		end

		local inputStatus, inputResult = pcall(checkAssertions)

		if not inputStatus then
			ao.send({
				Target = msg.From,
				Tags = { Action = "GAR-Invalid-Stake-Increase", Error = "Bad-Input"},
				Data = tostring(inputResult),
			})
			return
		end

		local result, err = gar.increaseOperatorStake(msg.From, tonumber(msg.Tags.Quantity))
		if err then
			ao.send({
				Target = msg.From,
				Tags = { Action = "GAR-Invalid-Stake-Increase" },
				Data = tostring(err),
			})
		else
			ao.send({
				Target = msg.From,
				Tags = { Action = "GAR-Stake-Increased" },
				Data = tostring(json.encode(result)),
			})
		end
	end
)

Handlers.add(
	ActionMap.DecreaseOperatorStake,
	utils.hasMatchingTag("Action", ActionMap.DecreaseOperatorStake),
	function(msg)
		local checkAssertions = function()
			assert(tonumber(msg.Tags.Quantity) > 0, "Invalid quantity")
		end

		local inputStatus, inputResult = pcall(checkAssertions)

		if not inputStatus then
			ao.send({
				Target = msg.From,
				Tags = { Action = "GAR-Invalid-Stake-Decrease", Error = "Bad-Input"},
				Data = tostring(inputResult),
			})
			return
		end
		local status, result =
			pcall(gar.decreaseOperatorStake, msg.From, tonumber(msg.Tags.Quantity), msg.Timestamp, msg.Id)
		if not status then
			ao.send({
				Target = msg.From,
				Tags = { Action = "GAR-Invalid-Stake-Decrease", Error = "Invalid-Stake-Decrease" },
				Data = tostring(result),
			})
		else
			ao.send({
				Target = msg.From,
				Tags = { Action = "GAR-Stake-Decreased" },
				Data = tostring(json.encode(result)),
			})
		end
	end
)

Handlers.add(ActionMap.DelegateStake, utils.hasMatchingTag("Action", ActionMap.DelegateStake), function(msg)
	local checkAssertions = function()
		assert(utils.isValidArweaveAddress(msg.Tags.Target), "Invalid target address")
		assert(tonumber(msg.Tags.Quantity) > 0, "Invalid quantity")
	end

	local inputStatus, inputResult = pcall(checkAssertions)

	if not inputStatus then
		ao.send({
			Target = msg.From,
			Tags = { Error = "Bad-Input", Action = ActionMap.DelegateStake },
			Data = tostring(inputResult),
		})
		return
	end

	local status, result =
		pcall(gar.delegateStake, msg.From, msg.Tags.Target, tonumber(msg.Tags.Quantity), tonumber(msg.Timestamp))
	if not status then
		ao.send({
			Target = msg.From,
			Tags = { Error = "GAR-Invalid-Delegate-Stake-Increase", Action = ActionMap.DelegateStake, Message = result },
			Data = tostring(json.encode(result)),
		})
	else
		ao.send({
			Target = msg.From,
			Tags = { Action = "GAR-Delegate-Stake-Increased" },
			Data = tostring(json.encode(result)),
		})
	end
end)

Handlers.add(
	ActionMap.DecreaseDelegateStake,
	utils.hasMatchingTag("Action", ActionMap.DecreaseDelegateStake),
	function(msg)
		local checkAssertions = function()
			assert(utils.isValidArweaveAddress(msg.Tags.Target), "Invalid target address")
			assert(tonumber(msg.Tags.Quantity) > 0, "Invalid quantity")
		end

		local inputStatus, inputResult = pcall(checkAssertions)

		if not inputStatus then
			ao.send({
				Target = msg.From,
				Tags = { Error = "Bad-Input", Action = ActionMap.DecreaseDelegateStake },
				Data = tostring(inputResult),
			})
			return
		end

		local status, result = pcall(
			gar.decreaseDelegateStake,
			msg.Tags.Target,
			msg.From,
			tonumber(msg.Tags.Quantity),
			msg.Timestamp,
			msg.Id
		)
		if not status then
			ao.send({
				Target = msg.From,
				Tags = { Error = "GAR-Invalid-Delegate-Stake-Decrease", Action = ActionMap.DecreaseDelegateStake },
				Data = tostring(result),
			})
		else
			ao.send({
				Target = msg.From,
				Tags = { Action = "GAR-Delegate-Stake-Decreased" },
				Data = json.encode(result),
			})
		end
	end
)

Handlers.add(
	ActionMap.UpdateGatewaySettings,
	utils.hasMatchingTag("Action", ActionMap.UpdateGatewaySettings),
	function(msg)
		local gateway = gar.getGateway(msg.From)
		if not gateway then
			ao.send({
				Target = msg.From,
				Tags = { Action = "GAR-Invalid-Update-Gateway-Settings", Error="Failed-Update-Gateway-Settings"  },
				Data = "Gateway not found",
			})
			return
		end

		-- keep defaults, but update any new ones
		local updatedSettings = {
			label = msg.Tags.Label or gateway.settings.label,
			note = msg.Tags.Note or gateway.settings.note,
			fqdn = msg.Tags.FQDN or gateway.settings.fqdn,
			port = tonumber(msg.Tags.Port) or gateway.settings.port,
			protocol = msg.Tags.Protocol or gateway.settings.protocol,
			allowDelegatedStaking = not msg.Tags.AllowDelegatedStaking and gateway.settings.allowDelegatedStaking or msg.Tags.AllowDelegatedStaking == "true",
			minDelegatedStake = tonumber(msg.Tags.MinDelegatedStake) or gateway.settings.minDelegatedStake,
			delegateRewardShareRatio = tonumber(msg.Tags.DelegateRewardShareRatio)
				or gateway.settings.delegateRewardShareRatio,
			properties = msg.Tags.Properties or gateway.settings.properties,
			autoStake = msg.Tags.AutoStake == "true" or gateway.settings.autoStake,
		}
		local observerAddress = msg.Tags.ObserverAddress or gateway.observerAddress
		local status, result =
			pcall(gar.updateGatewaySettings, msg.From, updatedSettings, observerAddress, msg.Timestamp, msg.Id)
		if not status then
			ao.send({
				Target = msg.From,
				Tags = { Action = "GAR-Invalid-Update-Gateway-Settings", Error="Failed-Update-Gateway-Settings" },
				Data = tostring(result),
			})
		else
			ao.send({
				Target = msg.From,
				Tags = { Action = "GAR-Gateway-Settings-Updated" },
				Data = json.encode(result),
			})
		end
	end
)

Handlers.add(ActionMap.SaveObservations, utils.hasMatchingTag("Action", ActionMap.SaveObservations), function(msg)
	local reportTxId = msg.Tags.ReportTxId
	local failedGateways = utils.splitString(msg.Tags.FailedGateways, ",")
	local checkAssertions = function()
		assert(utils.isValidArweaveAddress(reportTxId), "Invalid report tx id")
		for _, gateway in ipairs(failedGateways) do
			assert(utils.isValidArweaveAddress(gateway), "Invalid gateway address")
		end
	end

	local inputStatus, inputResult = pcall(checkAssertions)

	if not inputStatus then
		ao.send({
			Target = msg.From,
			Tags = { Error = "Invalid-Save-Observations", Action = ActionMap.SaveObservations},
			Data = tostring(inputResult),
		})
		return
	end

	local status, result =
		pcall(epochs.saveObservations, msg.From, reportTxId, failedGateways, msg.Timestamp)
	if status then
		-- TODO: add tags for successfull save observation
		ao.send({ Target = msg.From, Data = json.encode(result) })
	else
		-- TODO: add additional tags for error
		ao.send({ Target = msg.From, Error = "Invalid-Saved-Observations", Data = json.encode(result) })
	end
end)

-- TICK HANDLER
Handlers.add("tick", utils.hasMatchingTag("Action", "Tick"), function(msg)
	local timestamp = tonumber(msg.Timestamp)
	-- TODO: how do we make this update atomic so that the state is changed all or nothing (should we?)
	local lastTickedEpochIndex = LastTickedEpoch
	local currentEpochIndex = epochs.getEpochIndexForTimestamp(timestamp)
	local function tickState(timestamp, blockHeight, hashchain)
		arns.pruneRecords(timestamp)
		arns.pruneReservedNames(timestamp)
		vaults.pruneVaults(timestamp)
		gar.pruneGateways(timestamp)
		demand.updateDemandFactor(timestamp)
		epochs.distributeRewardsForEpoch(timestamp)
		epochs.createEpoch(timestamp, tonumber(blockHeight), hashchain)
	end

	-- tick and distribute rewards for every index between the last ticked epoch and the current epoch
	for i = lastTickedEpochIndex + 1, currentEpochIndex - 1 do
		local previousState = {
			Balances = utils.deepCopy(Balances),
			Vaults = utils.deepCopy(Vaults),
			GatewayRegistry = utils.deepCopy(GatewayRegistry),
			NameRegistry = utils.deepCopy(NameRegistry),
			Epochs = utils.deepCopy(Epochs),
			DemandFactor = utils.deepCopy(DemandFactor),
		}
		local _, _, epochDistributionTimestamp = epochs.getEpochTimestampsForIndex(i)
		-- TODO: if we need to "recover" epochs, we can't rely on just the current message hashchain and block height
		local status, result = pcall(tickState, epochDistributionTimestamp, msg["Block-Height"], msg["Hash-Chain"])
		if status then
			ao.send({ Target = msg.From, Data = json.encode(result) })
			LastTickedEpoch = i -- update the last ticked state
		else
			-- reset the state to previous state
			Balances = previousState.Balances
			Vaults = previousState.Vaults
			GatewayRegistry = previousState.GatewayRegistry
			NameRegistry = previousState.NameRegistry
			Epochs = previousState.Epochs
			DemandFactor = previousState.DemandFactor
			ao.send({ Target = msg.From, Data = json.encode(result) })
		end
	end
end)

-- READ HANDLERS

Handlers.add(ActionMap.Info, Handlers.utils.hasMatchingTag("Action", ActionMap.Info), function(msg)
	ao.send({
		Target = msg.From,
		Tags = { Name = Name, Ticker = Ticker, Logo = Logo, Denomination = tostring(Denomination) },
	})
end)

Handlers.add(ActionMap.State, Handlers.utils.hasMatchingTag("Action", ActionMap.State), function(msg)
	ao.send({
		Target = msg.From,
		Data = json.encode({
			Name = Name,
			Ticker = Ticker,
			Denomination = Denomination,
			Balances = json.encode(Balances),
			GatewayRegistry = json.encode(GatewayRegistry),
			NameRegistry = json.encode(NameRegistry),
			Epochs = json.encode(Epochs),
			Vaults = json.encode(Vaults),
			DemandFactor = json.encode(DemandFactor),
		}),
	})
end)

Handlers.add(ActionMap.Gateways, Handlers.utils.hasMatchingTag("Action", ActionMap.Gateways), function(msg)
	local gateways = gar.getGateways()
	ao.send({
		Target = msg.From,
		Data = json.encode(gateways),
	})
end)

Handlers.add(ActionMap.Gateway, Handlers.utils.hasMatchingTag("Action", ActionMap.Gateway), function(msg)
	local gateway = gar.getGateway(msg.Tags.Address or msg.From)
	ao.send({
		Target = msg.From,
		Data = json.encode(gateway),
	})
end)

Handlers.add(ActionMap.Balances, Handlers.utils.hasMatchingTag("Action", ActionMap.Balances), function(msg)
	ao.send({
		Target = msg.From,
		Data = json.encode(Balances),
	})
end)

Handlers.add(ActionMap.Balance, Handlers.utils.hasMatchingTag("Action", ActionMap.Balance), function(msg)
	-- TODO: arconnect et. all expect to accept Target
	local balance = balances.getBalance(msg.Tags.Target or msg.Tags.Address or msg.From)
	-- must adhere to token.lua spec for arconnect compatibility
	ao.send({
		Target = msg.From,
		Data = balance,
		Balance = balance, 
		Ticker = Ticker, 
	})
end)

Handlers.add(ActionMap.DemandFactor, utils.hasMatchingTag("Action", ActionMap.DemandFactor), function(msg)
	-- wrap in a protected call, and return the result or error accoringly to sender
	local status, result = pcall(demand.getDemandFactor)
	if status then
		ao.send({ Target = msg.From, Data = tostring(result) })
	else
		ao.send({ Target = msg.From, Data = json.encode(result) })
	end
end)

Handlers.add(ActionMap.Record, utils.hasMatchingTag("Action", ActionMap.Record), function(msg)
	local record = arns.getRecord(msg.Tags.Name)
	ao.send({ Target = msg.From, Data = json.encode(record) })
end)

Handlers.add(ActionMap.Records, utils.hasMatchingTag("Action", ActionMap.Records), function(msg)
	local records = arns.getRecords()
	ao.send({ Target = msg.From, Data = json.encode(records) })
end)

Handlers.add(ActionMap.Epoch, utils.hasMatchingTag("Action", ActionMap.Epoch), function(msg)
	-- check if the epoch number is provided, if not get the epoch number from the timestamp
	local checkAssertions = function()
		assert(msg.Tags.EpochIndex or msg.Tags.Timestamp or msg.Timestamp, "Epoch index or timestamp is required")
	end

	local inputStatus, inputResult = pcall(checkAssertions)

	if not inputStatus then
		ao.send({
			Target = msg.From,
			Tags = { Error = "Bad-Input", Action = ActionMap.Epoch },
			Data = tostring(inputResult),
		})
		return
	end

	local epochIndex = tonumber(msg.Tags.EpochIndex) or epochs.getEpochIndexForTimestamp(tonumber(msg.Tags.Timestamp or msg.Timestamp))
	local epoch = epochs.getEpoch(epochIndex)
	ao.send({ Target = msg.From, Data = json.encode(epoch) })
end)

Handlers.add(ActionMap.Epochs, utils.hasMatchingTag("Action", ActionMap.Epochs), function(msg)
	local epochs = epochs.getEpochs()
	ao.send({ Target = msg.From, Data = json.encode(epochs) })
end)

Handlers.add(ActionMap.PrescribedObservers, utils.hasMatchingTag("Action", ActionMap.PrescribedObservers), function(msg)
	-- check if the epoch number is provided, if not get the epoch number from the timestamp
	local checkAssertions = function()
		assert(msg.Tags.EpochIndex or msg.Timestamp or msg.Tags.Timestamp, "Epoch index or timestamp is required")
	end

	local inputStatus, inputResult = pcall(checkAssertions)

	if not inputStatus then
		ao.send({
			Target = msg.From,
			Tags = { Error = "Bad-Input", Action = ActionMap.PrescribedObservers },
			Data = tostring(inputResult),
		})
		return
	end

	local epochIndex = tonumber(msg.Tags.EpochIndex) or epochs.getEpochIndexFromTimestamp(tonumber(msg.Timestamp))
	local prescribedObservers = epochs.getPrescribedObserversForEpoch(epochIndex)
	ao.send({ Target = msg.From, Data = json.encode(prescribedObservers) })
end)

Handlers.add(ActionMap.Observations, utils.hasMatchingTag("Action", ActionMap.Observations), function(msg)
	-- check if the epoch number is provided, if not get the epoch number from the timestamp
	local checkAssertions = function()
		assert(msg.Tags.EpochIndex or msg.Timestamp or msg.Tags.Timestamp, "Epoch index or timestamp is required")
	end

	local inputStatus, inputResult = pcall(checkAssertions)

	if not inputStatus then
		ao.send({
			Target = msg.From,
			Tags = { Error = "Bad-Input", Action = ActionMap.Observations },
			Data = tostring(inputResult),
		})
		return
	end

	local epochIndex = tonumber(msg.Tags.EpochIndex) or epochs.getEpochIndexFromTimestamp(tonumber(msg.Timestamp or msg.Tags.Timestamp))
	local observations = epochs.getObservationsForEpoch(epochIndex)
	ao.send({ Target = msg.From, Data = json.encode(observations) })
end)

Handlers.add(ActionMap.PrescribedNames, utils.hasMatchingTag("Action", ActionMap.PrescribedNames), function(msg)
	-- check if the epoch number is provided, if not get the epoch number from the timestamp
	local checkAssertions = function()
		assert(msg.Tags.EpochIndex or msg.Tags.Timestamp or msg.Timestamp, "Epoch index or timestamp is required")
	end

	local inputStatus, inputResult = pcall(checkAssertions)

	if not inputStatus then
		ao.send({
			Target = msg.From,
			Tags = { Error = "Bad-Input", Action = ActionMap.PrescribedNames },
			Data = tostring(inputResult),
		})
		return
	end

	local epochIndex = tonumber(msg.Tags.EpochIndex) or epochs.getEpochIndexForTimestamp(tonumber(msg.Timestamp or msg.Tags.Timestamp))
	local prescribedNames = epochs.getPrescribedNamesForEpoch(epochIndex)
	ao.send({ Target = msg.From, Data = json.encode(prescribedNames) })
end)

Handlers.add(ActionMap.Distributions, utils.hasMatchingTag("Action", ActionMap.Distributions), function(msg)
	-- check if the epoch number is provided, if not get the epoch number from the timestamp
	local checkAssertions = function()
		assert(msg.Tags.EpochIndex or msg.Timestamp or msg.Tags.Timestamp, "Epoch index or timestamp is required")
	end

	local inputStatus, inputResult = pcall(checkAssertions)

	if not inputStatus then
		ao.send({
			Target = msg.From,
			Tags = { Error = "Bad-Input", Action = ActionMap.Distributions },
			Data = tostring(inputResult),
		})
		return
	end

	local epochIndex = tonumber(msg.Tags.EpochIndex) or epochs.getEpochIndexFromTimestamp(tonumber(msg.Timestamp or msg.Tags.Timestamp))
	local distributions = epochs.getDistributionsForEpoch(epochIndex)
	ao.send({ Target = msg.From, Data = json.encode(distributions) })
end)

Handlers.add(ActionMap.ReservedNames, utils.hasMatchingTag("Action", ActionMap.ReservedNames), function(msg)
	local reservedNames = arns.getReservedNames()
	ao.send({ Target = msg.From, Data = json.encode(reservedNames) })
end)

Handlers.add(ActionMap.ReservedName, utils.hasMatchingTag("Action", ActionMap.ReservedName), function(msg)
	local reservedName = arns.getReservedName(msg.Tags.Name)
	ao.send({ Target = msg.From, Data = json.encode(reservedName) })
end)

-- END READ HANDLERS

-- UTILITY HANDLERS USED FOR MIGRATION
Handlers.add("addGateway", utils.hasMatchingTag("Action", "AddGateway"), function(msg)
	if msg.From ~= Owner then
		ao.send({ Target = msg.From, Data = "Unauthorized" })
		return
	end
	local status, result = pcall(gar.addGateway, msg.Tags.Address, json.decode(msg.Data))
	if status then
		ao.send({ Target = msg.From, Data = json.encode(result) })
	else
		ao.send({ Target = msg.From, Data = json.encode(result) })
	end
end)

Handlers.add("addRecord", utils.hasMatchingTag("Action", "AddRecord"), function(msg)
	if msg.From ~= Owner then
		ao.send({ Target = msg.From, Data = "Unauthorized" })
		return
	end
	local status, result = pcall(arns.addRecord, msg.Tags.Name, json.decode(msg.Data))
	if status then
		ao.send({ Target = msg.From, Data = json.encode(result) })
	else
		ao.send({ Target = msg.From, Data = json.encode(result) })
	end
end)

Handlers.add("addReservedName", utils.hasMatchingTag("Action", "AddReservedName"), function(msg)
	if msg.From ~= Owner then
		ao.send({ Target = msg.From, Data = "Unauthorized" })
		return
	end
	local status, result = pcall(arns.addReservedName, msg.Tags.Name, json.decode(msg.Data))
	if status then
		ao.send({ Target = msg.From, Data = json.encode(result) })
	else
		ao.send({ Target = msg.From, Data = json.encode(result) })
	end
end)

-- END UTILITY HANDLERS USED FOR MIGRATION

return process
