-- Adjust package.path to include the current directory
local process = { _version = "0.0.1" }

require("state")
local token = require("token")
local arns = require("arns")
local gar = require("gar")
local utils = require("utils")
local json = require("json")
local constants = require("constants")

if not Demand then
	require('demand') -- Load the demand module
	Demand = DemandFactor:init(constants.DEMAND_SETTINGS, fees)
end

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
	DecreaseDelegateStake = "DecreaseDelegateStake"
}

-- Handlers for contract functions

Handlers.add("info", Handlers.utils.hasMatchingTag("Action", "Info"), function(msg)
	ao.send({
		Target = msg.From,
		Tags = { Name = Name, Ticker = Ticker, Logo = Logo, Denomination = tostring(Denomination) },
	})
end)

Handlers.add(ActionMap.Transfer, utils.hasMatchingTag("Action", ActionMap.Transfer), function(msg)
	local result, err = token.transfer(msg.Tags.Recipient, msg.From, tonumber(msg.Tags.Quantity))
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
	local result = token.getBalance(msg.Tags.Target, msg.From)
	ao.send({
		Target = msg.From,
		Balance = tostring(result),
		Data = json.encode(tonumber(result)),
	})
end)

Handlers.add(ActionMap.GetBalances, utils.hasMatchingTag("Action", ActionMap.GetBalances), function(msg)
	local result = token.getBalances()
	ao.send({ Target = msg.From, Data = json.encode(result) })
end)

Handlers.add(ActionMap.CreateVault, utils.hasMatchingTag("Action", ActionMap.CreateVault), function(msg)
	local result, err = token.createVault(msg.From, msg.Tags.Quantity, msg.Tags.LockLength, msg.Timestamp, msg.Id)
	if err then
		ao.send({
			Target = msg.From,
			Tags = { Action = 'Invalid-Create-Vault' },
			Data = tostring(err)
		})
	else
		ao.send({
			Target = msg.From,
			Tags = { Action = 'Vault-Created-Notice' },
			Data = tostring(json.encode(result))
		})
	end
end)

Handlers.add(ActionMap.VaultedTransfer, utils.hasMatchingTag("Action", ActionMap.VaultedTransfer), function(msg)
	local result, err = token.vaultedTransfer(msg.From, msg.Tags.Recipient, msg.Tags.Quantity, msg.Tags.LockLength,
		msg.Timestamp, msg.Id)
	if err then
		ao.send({
			Target = msg.From,
			Tags = { Action = 'Invalid-Vaulted-Transfer' },
			Data = tostring(err)
		})
	else
		ao.send({
			Target = msg.From,
			Tags = { Action = 'Debit-Notice' },
			Data = tostring(json.encode(result))
		})
		ao.send({
			Target = msg.Tags.Recipient,
			Tags = { Action = 'Vaulted-Credit-Notice' },
			Data = tostring(json.encode(result))
		})
	end
end)

Handlers.add(ActionMap.ExtendVault, utils.hasMatchingTag("Action", ActionMap.ExtendVault), function(msg)
	local result, err = token.extendVault(msg.From, msg.Tags.ExtendLength, msg.Timestamp, msg.Tags.VaultId)
	if err then
		ao.send({
			Target = msg.From,
			Tags = { Action = 'Invalid-Extend-Vault' },
			Data = tostring(err)
		})
	else
		ao.send({
			Target = msg.From,
			Tags = { Action = 'Vault-Extended' },
			Data = tostring(json.encode(result))
		})
	end
end)

Handlers.add(ActionMap.IncreaseVault, utils.hasMatchingTag("Action", ActionMap.IncreaseVault), function(msg)
	local result, err = token.increaseVault(msg.From, msg.Tags.Quantity, msg.Tags.VaultId, msg.Timestamp)
	if err then
		ao.send({
			Target = msg.From,
			Tags = { Action = 'Invalid-Increase-Vault' },
			Data = tostring(err)
		})
	else
		ao.send({
			Target = msg.From,
			Tags = { Action = 'Vault-Increased' },
			Data = tostring(json.encode(result))
		})
	end
end)

Handlers.add(ActionMap.BuyRecord, utils.hasMatchingTag("Action", ActionMap.BuyRecord), function(msg)
	local result, err = arns.buyRecord(
		msg.Tags.Name,
		msg.Tags.PurchaseType,
		msg.Tags.Years,
		msg.From,
		msg.Tags.Auction,
		msg.Timestamp,
		msg.Tags.ProcessId
	)
	if err then
		ao.send({
			Target = msg.From,
			Tags = {
				Action = "ArNS-Invalid-Buy-Record-Notice",
				Name = tostring(msg.Tags.Name),
				ProcessId = tostring(msg.Tags.ProcessId),
			},
			Data = tostring(err),
		})
	else
		ao.send({
			Target = msg.From,
			Tags = { Action = "ArNS-Purchase-Notice", Sender = msg.From },
			Data = tostring(json.encode(result)),
		})
	end
end)

Handlers.add(ActionMap.SubmitAuctionBid, utils.hasMatchingTag("Action", ActionMap.SubmitAuctionBid), function(msg)
	arns.submitAuctionBid(msg)
end)

Handlers.add(ActionMap.ExtendLease, utils.hasMatchingTag("Action", ActionMap.ExtendLease), function(msg)
	local result, err = arns.extendLease(msg.From, msg.Tags.Name, msg.Tags.Years, msg.Timestamp)
	if err then
		ao.send({
			Target = msg.From,
			Tags = { Action = 'Invalid-Extend-Lease' },
			Data = tostring(err)
		})
	else
		ao.send({
			Target = msg.From,
			Tags = { Action = 'Lease-Extended' },
			Data = tostring(json.encode(result))
		})
	end
end)

Handlers.add(ActionMap.IncreaseUndernameCount,
	utils.hasMatchingTag("Action", ActionMap.IncreaseUndernameCount),
	function(msg)
		local result, err = arns.increaseUndernameCount(msg.From, msg.Tags.Name, msg.Tags.Quantity, msg.Timestamp)
		if err then
			ao.send({
				Target = msg.From,
				Tags = { Action = 'Invalid-Undername-Increase' },
				Data = tostring(err)
			})
		else
			ao.send({
				Target = msg.From,
				Tags = { Action = 'Undername-Quantity-Increased' },
				Data = tostring(json.encode(result))
			})
		end
	end)

Handlers.add(ActionMap.JoinNetwork, utils.hasMatchingTag("Action", ActionMap.JoinNetwork), function(msg)
	gar.joinNetwork(msg)
end)

Handlers.add(ActionMap.LeaveNetwork, utils.hasMatchingTag("Action", ActionMap.LeaveNetwork), function(msg)
	local result, err = gar.leaveNetwork(msg.From, msg.Timestamp, msg.Id)
	if err then
		ao.send({
			Target = msg.From,
			Tags = { Action = 'GAR-Invalid-Network-Leave' },
			Data = tostring(err)
		})
	else
		ao.send({
			Target = msg.From,
			Tags = { Action = 'GAR-Leaving-Network', EndTimeStamp = tostring(result.endTimestamp) },
			Data = tostring(json.encode(result))
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
				Tags = { Action = 'GAR-Invalid-Stake-Increase' },
				Data = tostring(err)
			})
		else
			ao.send({
				Target = msg.From,
				Tags = { Action = 'GAR-Stake-Increased', OperatorStake = tostring(result.operatorStake) },
				Data = tostring(json.encode(result))
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
				Tags = { Action = 'GAR-Invalid-Stake-Decrease' },
				Data = tostring(err)
			})
		else
			ao.send({
				Target = msg.From,
				Tags = { Action = 'GAR-Stake-Decreased', OperatorStake = tostring(result.operatorStake) },
				Data = tostring(json.encode(result))
			})
		end
	end
)

Handlers.add(
	ActionMap.DelegateStake,
	utils.hasMatchingTag("Action", ActionMap.DelegateStake),
	function(msg)
		local result, err = gar.delegateStake(msg.From, msg.Tags.Target, tonumber(msg.Tags.Quantity), msg.Timestamp)
		if err then
			ao.send({
				Target = msg.From,
				Tags = { Action = 'GAR-Invalid-Delegate-Stake-Increase' },
				Data = tostring(err)
			})
		else
			ao.send({
				Target = msg.From,
				Tags = { Action = 'GAR-Delegate-Stake-Increased', DelegatedStake = tostring(result.delegates[msg.From].DelegatedStake) },
				Data = tostring(json.encode(result))
			})
		end
	end
)

Handlers.add(
	ActionMap.DecreaseDelegateStake,
	utils.hasMatchingTag("Action", ActionMap.DecreaseDelegateStake),
	function(msg)
		local result, err = gar.decreaseDelegateStake(msg.From, msg.Tags.Target, tonumber(msg.Tags.Quantity),
			msg.Timestamp)
		if err then
			ao.send({
				Target = msg.From,
				Tags = { Action = 'GAR-Invalid-Delegate-Stake-Decrease' },
				Data = tostring(err)
			})
		else
			ao.send({
				Target = msg.From,
				Tags = { Action = 'GAR-Delegate-Stake-Decreased', DelegatedStake = tostring(result.delegates[msg.From].DelegatedStake) },
				Data = tostring(json.encode(result))
			})
		end
	end
)


Handlers.add(
	ActionMap.UpdateGatewaySettings,
	utils.hasMatchingTag("Action", ActionMap.UpdateGatewaySettings),
	function(msg)
		local result, err = gar.updateGatewaySettings(msg.From, msg.Tags.UpdatedSettings, msg.Tags.ObserverWallet,
			msg.Timestamp, msg.Id)
		if err then
			ao.send({
				Target = msg.From,
				Tags = { Action = 'GAR-Invalid-Update-Gateway-Settings' },
				Data = tostring(err)
			})
		else
			ao.send({
				Target = msg.From,
				Tags = { Action = 'GAR-Gateway-Settings-Updated' },
				Data = tostring(json.encode(result))
			})
		end
	end
)

Handlers.add(
	ActionMap.GetGateway,
	utils.hasMatchingTag("Action", ActionMap.GetGateway),
	function(msg)
		local result, err = gar.getGateway(msg.Tags.Target)
		if err then
			ao.send({
				Target = msg.From,
				Tags = { Action = 'GAR-Invalid-Gateway-Target' },
				Data = tostring(err)
			})
		else
			ao.send({
				Target = msg.From,
				Tags = { Action = 'GAR-Get-Gateway' },
				Data = tostring(json.encode(result))
			})
		end
	end
)

Handlers.add(
	ActionMap.GetGateways,
	utils.hasMatchingTag("Action", ActionMap.GetGateways),
	function(msg)
		local result = gar.getGateways()
		ao.send({
			Target = msg.From,
			Tags = { Action = 'GAR-Get-Gateways' },
			Data = tostring(json.encode(result))
		})
	end
)

Handlers.add(ActionMap.SaveObservations, utils.hasMatchingTag("Action", ActionMap.SaveObservations), function(msg)
	local result, err = gar.saveObservations(msg.From, msg.Tags.ObserverReportTxId, msg.Tags.FailedGateways,
		msg.Timestamp)
	if err then
		ao.send({
			Target = msg.From,
			Tags = { Action = 'Invalid-Save-Observation' },
			Data = tostring(err)
		})
	else
		ao.send({
			Target = msg.From,
			Tags = { Action = 'Observation-Saved' },
			Data = tostring(json.encode(result))
		})
	end
end)

-- handler showing how we can fetch data from classes in lua
Handlers.add(ActionMap.DemandFactor, utils.hasMatchingTag("Action", ActionMap.DemandFactor), function(msg)
	-- wrap in a protected call, and return the result or error accoringly to sender
	local status, result = pcall(function() return Demand:getDemandFactor() end)
	if status then
		ao.send({ Target = msg.From, Data = tostring(result) })
	else
		ao.send({ Target = msg.From, Error = json.encode(result) })
	end
end)

return process;
