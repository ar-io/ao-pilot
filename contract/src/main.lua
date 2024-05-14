-- Adjust package.path to include the current directory
local process = { _version = "0.0.1" }

local ao = require("ao")
local utils = require("utils")
local json = require("json")

Name = "Test IO"
Ticker = "tIO"
Logo = "Sie_26dvgyok0PZD_-iQAFOhOd5YxDTkczOLoqTTL_A"
Denomination = 6
Demand = require("demand")
Token = require("token")
GatewayRegistry = require("gar")
NameRegistry = require("arns")

local ActionMap = {
	Info = "Info",
	Transfer = "Transfer",
	GetBalance = "Balance",
	GetBalances = "Balances",
	CreateVault = "CreateVault",
	VaultedTransfer = "VaultedTransfer",
	ExtendVault = "ExtendVault",
	IncreaseVault = "IncreaseVault",
	BuyRecord = "BuyRecord",
	SubmitAuctionBid = "SubmitAuctionBid",
	ExtendLease = "ExtendLease",
	IncreaseUndernameCount = "IncreaseUndernameCount",
	JoinNetwork = "JoinNetwork",
	LeaveNetwork = "LeaveNetwork",
	IncreaseOperatorStake = "IncreaseOperatorStake",
	DecreaseOperatorStake = "DecreaseOperatorStake",
	UpdateGatewaySettings = "UpdateGatewaySettings",
	GetGateway = "GetGateway",
	GetGateways = "GetGateways",
	SaveObservations = "SaveObservations",
	DemandFactor = "DemandFactor",
	DelegateStake = "DelegateStake",
	DecreaseDelegateStake = "DecreaseDelegateStake",
}

-- Handlers for contract functions

Handlers.add("info", Handlers.utils.hasMatchingTag("Action", "Info"), function(msg)
	ao.send({
		Target = msg.From,
		Tags = { Name = Name, Ticker = Ticker, Logo = Logo, Denomination = tostring(Denomination) },
	})
end)

Handlers.add(ActionMap.Transfer, utils.hasMatchingTag("Action", ActionMap.Transfer), function(msg)
	local result, err = Token.transfer(msg.Tags.Recipient, msg.From, tonumber(msg.Tags.Quantity))
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

Handlers.add(ActionMap.GetBalance, utils.hasMatchingTag("Action", ActionMap.GetBalance), function(msg)
	local result = Token.getBalance(msg.Tags.Target, msg.From)
	ao.send({
		Target = msg.From,
		Balance = tostring(result),
		Data = json.encode(tonumber(result)),
	})
end)

Handlers.add(ActionMap.GetBalances, utils.hasMatchingTag("Action", ActionMap.GetBalances), function(msg)
	local result = Token.getBalances()
	ao.send({ Target = msg.From, Data = json.encode(result) })
end)

Handlers.add(ActionMap.CreateVault, utils.hasMatchingTag("Action", ActionMap.CreateVault), function(msg)
	local result, err = Token.createVault(msg.From, msg.Tags.Quantity, msg.Tags.LockLength, msg.Timestamp, msg.Id)
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
	local result, err = Token.vaultedTransfer(
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
	local result, err = Token.extendVault(msg.From, msg.Tags.ExtendLength, msg.Timestamp, msg.Tags.VaultId)
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
	local result, err = Token.increaseVault(msg.From, msg.Tags.Quantity, msg.Tags.VaultId, msg.Timestamp)
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
	local success, result = pcall(
		NameRegistry.buyRecord,
		msg.Tags.Name,
		msg.Tags.PurchaseType,
		msg.Tags.Years,
		msg.From,
		msg.Tags.Auction,
		msg.Timestamp,
		msg.Tags.ProcessId
	)
	if not success then
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

Handlers.add(ActionMap.SubmitAuctionBid, utils.hasMatchingTag("Action", ActionMap.SubmitAuctionBid), function(msg)
	local status, result = pcall(NameRegistry.submitAuctionBid, msg.From, msg.Tags.Name, msg.Tags.Bid, msg.Timestamp)
	if not status then
		ao.send({
			Target = msg.From,
			Tags = { Action = "Invalid-Auction-Bid" },
			Data = tostring(result),
		})
	else
		ao.send({
			Target = msg.From,
			Tags = { Action = "Auction-Bid-Submitted" },
			Data = tostring(json.encode(result)),
		})
	end
end)

Handlers.add(ActionMap.ExtendLease, utils.hasMatchingTag("Action", ActionMap.ExtendLease), function(msg)
	local success, result = pcall(NameRegistry.extendLease, msg.From, msg.Tags.Name, msg.Tags.Years, msg.Timestamp)
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
			pcall(NameRegistry.increaseUndernameCount, msg.From, msg.Tags.Name, msg.Tags.Quantity, msg.Timestamp)
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
	GatewayRegistryjoinNetwork(msg)
end)

Handlers.add(ActionMap.LeaveNetwork, utils.hasMatchingTag("Action", ActionMap.LeaveNetwork), function(msg)
	local result, err = GatewayRegistryleaveNetwork(msg.From, msg.Timestamp, msg.Id)
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
		local result, err = GatewayRegistryincreaseOperatorStake(msg.From, tonumber(msg.Tags.Quantity))
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
		local result, err =
			GatewayRegistrydecreaseOperatorStake(msg.From, tonumber(msg.Tags.Quantity), msg.Timestamp, msg.Id)
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
	local result, err =
		GatewayRegistrydelegateStake(msg.From, msg.Tags.Target, tonumber(msg.Tags.Quantity), msg.Timestamp)
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
			GatewayRegistrydecreaseDelegateStake(msg.From, msg.Tags.Target, tonumber(msg.Tags.Quantity), msg.Timestamp)
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
		local result, err = GatewayRegistryupdateGatewaySettings(
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

Handlers.add(ActionMap.GetGateway, utils.hasMatchingTag("Action", ActionMap.GetGateway), function(msg)
	local result, err = GatewayRegistrygetGateway(msg.Tags.Target)
	if err then
		ao.send({
			Target = msg.From,
			Tags = { Action = "GAR-Invalid-Gateway-Target" },
			Data = tostring(err),
		})
	else
		ao.send({
			Target = msg.From,
			Tags = { Action = "GAR-Get-Gateway" },
			Data = tostring(json.encode(result)),
		})
	end
end)

Handlers.add(ActionMap.GetGateways, utils.hasMatchingTag("Action", ActionMap.GetGateways), function(msg)
	local result = GatewayRegistrygetGateways()
	ao.send({
		Target = msg.From,
		Tags = { Action = "GAR-Get-Gateways" },
		Data = tostring(json.encode(result)),
	})
end)

Handlers.add(ActionMap.SaveObservations, utils.hasMatchingTag("Action", ActionMap.SaveObservations), function(msg)
	GatewayRegistrysaveObservations(msg)
end)

-- handler showing how we can fetch data from classes in lua
Handlers.add(ActionMap.DemandFactor, utils.hasMatchingTag("Action", ActionMap.DemandFactor), function(msg)
	-- wrap in a protected call, and return the result or error accoringly to sender
	local status, result = pcall(Demand.getDemandFactor)
	if status then
		ao.send({ Target = msg.From, Data = tostring(result) })
	else
		ao.send({ Target = msg.From, Error = json.encode(result) })
	end
end)

return process
