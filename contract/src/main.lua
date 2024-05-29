-- Adjust package.path to include the current directory
local process = { _version = "0.0.1" }

Name = "Test IO"
Ticker = "tIO"
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

local utils = require("utils")
local json = require("json")
local ao = ao or require("ao")
local balances = require("balances")
local arns = require("arns")
local gar = require("gar")
local demand = require("demand")
local epochs = require("epochs")

local ActionMap = {
	-- reads
	Info = "Info",
	State = "State",
	Record = "Record",
	Records = "Records",
	Transfer = "Transfer",
	Balance = "Balance",
	Balances = "Balances",
	Gateway = "Gateway",
	Gateways = "Gateways",
	DemandFactor = "DemandFactor",
	Epochs = "Epochs",
	Epoch = "Epoch",
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

-- -- Handlers for contract functions

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
			Balances = Balances,
			GatewayRegistry = GatewayRegistry,
			NameRegistry = NameRegistry,
			Epochs = Epochs,
			Vaults = Vaults,
			DemandFactor = DemandFactor,
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
	local gateway = gar.getGateway(msg.Tags.Target)
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
	local balance = balances.getBalance(msg.Tags.Target)
	ao.send({
		Target = msg.From,
		Data = tostring(balance),
	})
end)

Handlers.add(ActionMap.Transfer, utils.hasMatchingTag("Action", ActionMap.Transfer), function(msg)
	local result, err = balances.transfer(msg.Tags.Recipient, msg.From, tonumber(msg.Tags.Quantity))
	if result and not msg.Cast then
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
	else
		ao.send({
			Target = msg.From,
			Tags = { Action = "Transfer-Error", ["Message-Id"] = msg.Id, Error = tostring(err) },
			Data = tostring(err),
		})
	end
end)

Handlers.add(ActionMap.CreateVault, utils.hasMatchingTag("Action", ActionMap.CreateVault), function(msg)
	local result, err = balances.createVault(msg.From, msg.Tags.Quantity, msg.Tags.LockLength, msg.Timestamp, msg.Id)
	if err then
		ao.send({
			Target = msg.From,
			Tags = { Action = "Invalid-Create-Vault" },
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
			Tags = { Action = "Invalid-Vaulted-Transfer" },
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
	local result, err = balances.extendVault(msg.From, msg.Tags.ExtendLength, msg.Timestamp, msg.Tags.VaultId)
	if err then
		ao.send({
			Target = msg.From,
			Tags = { Action = "Invalid-Extend-Vault" },
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
	local result, err = balances.increaseVault(msg.From, msg.Tags.Quantity, msg.Tags.VaultId, msg.Timestamp)
	if err then
		ao.send({
			Target = msg.From,
			Tags = { Action = "Invalid-Increase-Vault" },
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
				Name = tostring(msg.Tags.Name),
				ProcessId = tostring(msg.Tags.ProcessId),
			},
			Data = tostring(result),
		})
		return
	else
		ao.send({
			Target = msg.From,
			Tags = { Action = "ArNS-Purchase-Notice", Sender = msg.From },
			Error = tostring(result),
			Data = tostring(json.encode(result)),
		})
	end
end)

Handlers.add(ActionMap.ExtendLease, utils.hasMatchingTag("Action", ActionMap.ExtendLease), function(msg)
	local success, result = pcall(arns.extendLease, msg.From, msg.Tags.Name, msg.Tags.Years, msg.Timestamp)
	if not success then
		ao.send({
			Target = msg.From,
			Tags = { Action = "Invalid-Extend-Lease" },
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
		local status, result =
			pcall(arns.increaseUndernameCount, msg.From, msg.Tags.Name, msg.Tags.Quantity, msg.Timestamp)
		if not status then
			ao.send({
				Target = msg.From,
				Tags = { Action = "Invalid-Undername-Increase" },
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
	gar.joinNetwork(msg)
end)

Handlers.add(ActionMap.LeaveNetwork, utils.hasMatchingTag("Action", ActionMap.LeaveNetwork), function(msg)
	local result, err = gar.leaveNetwork(msg.From, msg.Timestamp, msg.Id)
	if err then
		ao.send({
			Target = msg.From,
			Tags = { Action = "GAR-Invalid-Network-Leave" },
			Data = tostring(err),
		})
	else
		ao.send({
			Target = msg.From,
			Tags = { Action = "GAR-Leaving-Network", EndTimeStamp = tostring(result.endTimestamp) },
			Data = tostring(json.encode(result)),
		})
	end
end)

Handlers.add(
	ActionMap.IncreaseOperatorStake,
	utils.hasMatchingTag("Action", ActionMap.IncreaseOperatorStake),
	function(msg)
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
				Tags = { Action = "GAR-Stake-Increased", OperatorStake = tostring(result.operatorStake) },
				Data = tostring(json.encode(result)),
			})
		end
	end
)

Handlers.add(
	ActionMap.DecreaseOperatorStake,
	utils.hasMatchingTag("Action", ActionMap.DecreaseOperatorStake),
	function(msg)
		local result, err = gar.decreaseOperatorStake(msg.From, tonumber(msg.Tags.Quantity), msg.Timestamp, msg.Id)
		if err then
			ao.send({
				Target = msg.From,
				Tags = { Action = "GAR-Invalid-Stake-Decrease" },
				Data = tostring(err),
			})
		else
			ao.send({
				Target = msg.From,
				Tags = { Action = "GAR-Stake-Decreased", OperatorStake = tostring(result.operatorStake) },
				Data = tostring(json.encode(result)),
			})
		end
	end
)

Handlers.add(ActionMap.DelegateStake, utils.hasMatchingTag("Action", ActionMap.DelegateStake), function(msg)
	local result, err = gar.delegateStake(msg.From, msg.Tags.Target, tonumber(msg.Tags.Quantity), msg.Timestamp)
	if err then
		ao.send({
			Target = msg.From,
			Tags = { Action = "GAR-Invalid-Delegate-Stake-Increase" },
			Data = tostring(err),
		})
	else
		ao.send({
			Target = msg.From,
			Tags = {
				Action = "GAR-Delegate-Stake-Increased",
				DelegatedStake = tostring(result.delegates[msg.From].DelegatedStake),
			},
			Data = tostring(json.encode(result)),
		})
	end
end)

Handlers.add(
	ActionMap.DecreaseDelegateStake,
	utils.hasMatchingTag("Action", ActionMap.DecreaseDelegateStake),
	function(msg)
		local result, err =
			gar.decreaseDelegateStake(msg.From, msg.Tags.Target, tonumber(msg.Tags.Quantity), msg.Timestamp)
		if err then
			ao.send({
				Target = msg.From,
				Tags = { Action = "GAR-Invalid-Delegate-Stake-Decrease" },
				Data = tostring(err),
			})
		else
			ao.send({
				Target = msg.From,
				Tags = {
					Action = "GAR-Delegate-Stake-Decreased",
					DelegatedStake = tostring(result.delegates[msg.From].DelegatedStake),
				},
				Data = tostring(json.encode(result)),
			})
		end
	end
)

Handlers.add(
	ActionMap.UpdateGatewaySettings,
	utils.hasMatchingTag("Action", ActionMap.UpdateGatewaySettings),
	function(msg)
		local result, err = gar.updateGatewaySettings(
			msg.From,
			msg.Tags.UpdatedSettings,
			msg.Tags.ObserverWallet,
			msg.Timestamp,
			msg.Id
		)
		if err then
			ao.send({
				Target = msg.From,
				Tags = { Action = "GAR-Invalid-Update-Gateway-Settings" },
				Data = tostring(err),
			})
		else
			ao.send({
				Target = msg.From,
				Tags = { Action = "GAR-Gateway-Settings-Updated" },
				Data = tostring(json.encode(result)),
			})
		end
	end
)

Handlers.add(ActionMap.SaveObservations, utils.hasMatchingTag("Action", ActionMap.SaveObservations), function(msg)
	gar.saveObservations(msg)
end)

-- handler showing how we can fetch data from classes in lua
Handlers.add(ActionMap.DemandFactor, utils.hasMatchingTag("Action", ActionMap.DemandFactor), function(msg)
	-- wrap in a protected call, and return the result or error accoringly to sender
	local status, result = pcall(demand.getDemandFactor)
	if status then
		ao.send({ Target = msg.From, Data = tostring(result) })
	else
		ao.send({ Target = msg.From, Error = json.encode(result) })
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

Handlers.add(ActionMap.Epoch, utils.hasMatchingTag("Action", ActionMap.Epochs), function(msg)
	local epochIndex = msg.Tags.EpochNumber or epochs.getEpochIndexFromTimestamp(msg.Timestamp)
	local epoch = epochs.getEpoch(epochIndex)
	ao.send({ Target = msg.From, Data = json.encode(epoch) })
end)

Handlers.add(ActionMap.Epochs, utils.hasMatchingTag("Action", ActionMap.Epochs), function(msg)
	local epochs = epochs.getEpoch(msg.Timestamp)
	ao.send({ Target = msg.From, Data = json.encode(Epochs) })
end)

return process
