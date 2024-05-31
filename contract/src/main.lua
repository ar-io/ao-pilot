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
local vaults = require("vaults")

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
	PrescribedObservers = "PrescribedObservers",
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
	assert(utils.isValidArweaveAddress(msg.Tags.Recipient), "Invalid recipient")
	-- assert quantity is a positive number
	assert(tonumber(msg.Tags.Quantity) > 0, "Invalid quantity")

	local status, _ = pcall(balances.transfer, msg.Tags.Recipient, msg.From, tonumber(msg.Tags.Quantity))
	if status then
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
	else
		ao.send({
			Target = msg.From,
			Tags = { Action = "Transfer-Error" },
			Data = tostring(reuslt),
		})
	end
end)

Handlers.add(ActionMap.CreateVault, utils.hasMatchingTag("Action", ActionMap.CreateVault), function(msg)
	-- assert quantity is a positive number
	assert(tonumber(msg.Tags.Quantity) > 0, "Invalid quantity")
	-- assert lock length is a positive number
	assert(tonumber(msg.Tags.LockLength) > 0, "Invalid lock length")

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
	-- assert recipient is a valid arweave address
	assert(utils.isValidArweaveAddress(msg.Tags.Recipient), "Invalid recipient")
	-- assert quantity is a positive number
	assert(tonumber(msg.Tags.Quantity) > 0, "Invalid quantity")
	-- assert lock length is a positive number
	assert(tonumber(msg.Tags.LockLength) > 0, "Invalid lock length")

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
	-- assert extend length is a positive number
	assert(tonumber(msg.Tags.ExtendLength) > 0, "Invalid extend length")
	-- assert vault id is a valid arweave tx id
	assert(utils.isValidArweaveTxId(msg.Tags.VaultId), "Invalid vault id")

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
	-- assert quantity is a positive number
	assert(tonumber(msg.Tags.Quantity) > 0, "Invalid quantity")
	-- assert vault id is a valid arweave tx id
	assert(utils.isValidArweaveTxId(msg.Tags.VaultId), "Invalid vault id")

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
	-- assert name is a string
	assert(type(msg.Tags.Name) == "string", "Invalid name")
	-- assert purchase type is a string
	assert(type(msg.Tags.PurchaseType) == "string", "Invalid purchase type")
	-- assert years is a positive number and less than 5
	assert(tonumber(msg.Tags.Years) > 0 and tonumber(msg.Tags.Years) < 5, "Invalid years")

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
				Sender = msg.From,
			},
			Data = tostring(result),
		})
		return
	else
		ao.send({
			Target = msg.From,
			Tags = { Action = "ArNS-Purchase-Notice", Sender = msg.From },
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
		assert(type(msg.Tags.Name) == "string", "Invalid name")
		assert(tonumber(msg.Tags.Quantity) > 0, "Invalid quantity")

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
	-- assert stake is a positive number
	assert(tonumber(msg.Tags.Stake) > 0, "Invalid stake")
	-- assert settings is a valid table
	assert(type(msg.Tags.Settings) == "table", "Invalid settings")
	-- assert observer address is a valid arweave address
	assert(utils.isValidArweaveAddress(msg.Tags.ObserverAddress), "Invalid observer address")

	local status, result = pcall(
		gar.joinNetwork,
		msg.From,
		tonumber(msg.Tags.Stake),
		msg.Tags.Settings,
		msg.Tags.ObserverAddresss or msg.Tags.From,
		msg.Timestamp
	)
	if not status then
		ao.send({
			Target = msg.From,
			Tags = { Action = "GAR-Invalid-Network-Join" },
			Data = tostring(result),
		})
	else
		ao.send({
			Target = msg.From,
			Tags = { Action = "GAR-Joined-Network", EndTimeStamp = tostring(result.endTimestamp) },
			Data = tostring(json.encode(result)),
		})
	end
end)

Handlers.add(ActionMap.LeaveNetwork, utils.hasMatchingTag("Action", ActionMap.LeaveNetwork), function(msg)
	local status, result = pcall(gar.leaveNetwork, msg.From, msg.Timestamp, msg.Id)
	if not status then
		ao.send({
			Target = msg.From,
			Tags = { Action = "GAR-Invalid-Network-Leave" },
			Data = tostring(err),
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
		-- assert quantity is a positive number
		assert(tonumber(msg.Tags.Quantity) > 0, "Invalid quantity")
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
		-- assert quantity is a positive number
		assert(tonumber(msg.Tags.Quantity) > 0, "Invalid quantity")
		local status, result =
			pcall(gar.decreaseOperatorStake, msg.From, tonumber(msg.Tags.Quantity), msg.Timestamp, msg.Id)
		if not status then
			ao.send({
				Target = msg.From,
				Tags = { Action = "GAR-Invalid-Stake-Decrease" },
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
	assert(utils.isValidArweaveAddress(msg.Tags.Target), "Invalid target address")
	assert(tonumber(msg.Tags.Quantity) > 0, "Invalid quantity")

	local status, result =
		pcall(gar.delegateStake, msg.From, msg.Tags.Target, tonumber(msg.Tags.Quantity), msg.Timestamp)
	if not status then
		ao.send({
			Target = msg.From,
			Tags = { Action = "GAR-Invalid-Delegate-Stake-Increase" },
			Data = tostring(result),
		})
	else
		ao.send({
			Target = msg.From,
			Tags = { Action = "GAR-Delegate-Stake-Increased" },
			Data = json.encode(result),
		})
	end
end)

Handlers.add(
	ActionMap.DecreaseDelegateStake,
	utils.hasMatchingTag("Action", ActionMap.DecreaseDelegateStake),
	function(msg)
		-- assert target is a valid arweave address
		assert(utils.isValidArweaveAddress(msg.Tags.Target), "Invalid target address")
		assert(tonumber(msg.Tags.Quantity) > 0, "Invalid quantity")

		local status, result =
			pcall(gar.decreaseDelegateStake, msg.From, msg.Tags.Target, tonumber(msg.Tags.Quantity), msg.Timestamp)
		if not status then
			ao.send({
				Target = msg.From,
				Tags = { Action = "GAR-Invalid-Delegate-Stake-Decrease" },
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
		-- assert observer wallet is a valid arweave address
		-- assert updated settings is a valid table
		assert(type(msg.Tags.UpdatedSettings) == "table", "Invalid updated settings")

		-- assert observer wallet if it is provided
		if msg.Tags.ObserverWallet then
			assert(utils.isValidArweaveAddress(msg.Tags.ObserverWallet), "Invalid observer wallet")
		end

		local status, result = pcall(
			gar.updateGatewaySettings,
			msg.From,
			msg.Tags.UpdatedSettings,
			msg.Tags.ObserverWallet,
			msg.Timestamp,
			msg.Id
		)
		if not status then
			ao.send({
				Target = msg.From,
				Tags = { Action = "GAR-Invalid-Update-Gateway-Settings" },
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
	-- assesrt report tx id is valid arweave tx id
	-- assert failed gateways is an array of valid gateway addresses
	assert(type(msg.Data.reportTxId) == "string", "Invalid reportTxId")
	assert(type(msg.Data.failedGateways) == "table", "Invalid failedGateways")

	local status, result =
		pcall(epochs.saveObservations, msg.From, msg.Data.reportTxId, msg.Data.failedGateways, msg.Timestamp)
	if status then
		-- TODO: add tags for successfull save observation
		ao.send({ Target = msg.From, Data = tostring(result) })
	else
		-- TODO: add additional tags for error
		ao.send({ Target = msg.From, Data = json.encode(result) })
	end
end)

-- -- Read-only handlers
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
	local epochIndex = tonumber(msg.Tags.EpochNumber) or epochs.getEpochIndexFromTimestamp(msg.Timestamp)
	local epoch = epochs.getEpoch(epochIndex)
	ao.send({ Target = msg.From, Data = json.encode(epoch) })
end)

Handlers.add(ActionMap.Epochs, utils.hasMatchingTag("Action", ActionMap.Epochs), function(msg)
	local epochs = epochs.getEpochs()
	ao.send({ Target = msg.From, Data = json.encode(epochs) })
end)

Handlers.add(ActionMap.PrescribedObservers, utils.hasMatchingTag("Action", ActionMap.PrescribedObservers), function(msg)
	local epochIndex = epochs.getEpochTimestampsForIndex(msg.Timestamp)
	local prescribedObservers = epochs.getPrescribedObserversForEpoch(epochIndex)
	ao.send({ Target = msg.From, Data = json.encode(prescribedObservers) })
end)

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

Handlers.add("tick", utils.hasMatchingTag("Action", "Tick"), function(msg)
	local timestamp = tonumber(msg.Timestamp)
	-- TODO: how do we make this update atomic so that the state is changed all or nothing (should we?)
	local previousState = {
		Balances = utils.copyTable(Balances),
		Vaults = utils.copyTable(Vaults),
		GatewayRegistry = utils.copyTable(GatewayRegistry),
		NameRegistry = utils.copyTable(NameRegistry),
		Epochs = utils.copyTable(Epochs),
		DemandFactor = utils.copyTable(DemandFactor),
	}
	local function tickState(timestamp)
		demand.updateDemandFactor(timestamp)
		arns.pruneRecords(timestamp)
		arns.pruneReservedNames(timestamp)
		vaults.pruneVaults(timestamp)
		gar.pruneGatewayRegistry(timestamp, msg.HashChain)
		epochs.distributeRewardsForEpoch(timestamp)
		epochs.createEpochForTimestamp(timestamp)
	end

	local status, result = pcall(tickState, timestamp)
	if status then
		ao.send({ Target = msg.From, Data = json.encode(result) })
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
end)

return process
