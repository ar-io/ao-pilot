-- token.lua
require("state")
local constants = require("constants")
local json = require '.json'
local token = {}

function token.transfer(recipient, from, qty)
	assert(type(recipient) == 'string', 'Recipient is required!')
	assert(type(qty) == 'number', 'Quantity is required and must be a number!')
	assert(qty > 0, 'Quantity must be greater than 0')

	if not Balances[from] then Balances[from] = 0 end

	if not Balances[recipient] then Balances[recipient] = 0 end

	if Balances[from] >= qty then
		Balances[from] = Balances[from] - qty
		Balances[recipient] = Balances[recipient] + qty
		return true
	else
		return false, "Insufficient funds!";
	end
end

function token.createVault(from, qty, lockLength, currentTimestamp, msgId)
	if not Balances[from] then Balances[from] = 0 end

	if Balances[from] < qty then
		return false, "Insufficient funds!"
	end

	if Vaults[from] and Vaults[from][msgId] ~= nil then
		return false, "Vault with id " .. msgId .. " already exists"
	end

	if lockLength < constants.MIN_TOKEN_LOCK_TIME or lockLength > constants.MAX_TOKEN_LOCK_TIME then
		return false,
			"Invalid lock length. Must be between " ..
			constants.MIN_TOKEN_LOCK_TIME .. " - " .. constants.MAX_TOKEN_LOCK_TIME
	end

	Balances[from] = Balances[from] - qty

	if Vaults[from] == nil then
		Vaults[from] = {}
	end

	Vaults[from][msgId] = {
		balance = qty,
		startTimestamp = currentTimestamp,
		endTimestamp = currentTimestamp + lockLength
	}
	return Vaults[from][msgId]
end

function token.vaultedTransfer(from, recipient, qty, lockLength, currentTimestamp, msgId)
	if not Balances[from] then Balances[from] = 0 end

	if Balances[from] < qty then
		return false, "Insufficient funds!"
	end

	if Vaults[recipient] and Vaults[recipient][msgId] then
		return false, "Vault with id " .. msgId .. " already exists"
	end

	if lockLength < constants.MIN_TOKEN_LOCK_TIME or lockLength > constants.MAX_TOKEN_LOCK_TIME then
		return false,
			"Invalid lock length. Must be between " ..
			constants.MIN_TOKEN_LOCK_TIME .. " - " .. constants.MAX_TOKEN_LOCK_TIME
	end

	Balances[from] = Balances[from] - qty

	if Vaults[recipient] == nil then
		Vaults[recipient] = {}
	end

	Vaults[recipient][msgId] = {
		balance = qty,
		startTimestamp = currentTimestamp,
		endTimestamp = currentTimestamp + lockLength
	}

	return Vaults[recipient][msgId]
end

function token.extendVault(from, extendLength, currentTimestamp, vaultId)
	if Vaults[from] == nil or Vaults[from][vaultId] == nil then
		return false, "Invalid vault ID."
	end

	if currentTimestamp >= Vaults[from][vaultId].endTimestamp then
		return false, "This vault has ended."
	end

	local totalTimeRemaining = Vaults[from][vaultId].endTimestamp - currentTimestamp;
	if
		extendLength < constants.MIN_TOKEN_LOCK_BLOCK_LENGTH or
		extendLength > constants.MAX_TOKEN_LOCK_BLOCK_LENGTH or
		totalTimeRemaining + extendLength > constants.MAX_TOKEN_LOCK_BLOCK_LENGTH
	then
		return false, "Invalid lock length. Must be between " ..
			constants.MIN_TOKEN_LOCK_TIME .. " - " .. constants.MAX_TOKEN_LOCK_TIME
	end

	local newEnd = Vaults[from][vaultId].endTimestamp + extendLength
	Vaults[from][vaultId].endTimestamp = newEnd;
	return Vaults[from][vaultId]
end

function token.increaseVault(from, qty, vaultId, currentTimestamp)
	if not Balances[from] then Balances[from] = 0 end

	if Balances[from] < qty then
		return false, "Insufficient funds!"
	end

	if Vaults[from] == nil or Vaults[from][vaultId] == nil then
		return false, "Invalid vault ID."
	end

	if currentTimestamp >= Vaults[from][vaultId].endTimestamp then
		return false, "This vault has ended."
	end

	Balances[from] = Balances[from] - qty
	Vaults[from][vaultId].balance = Vaults[from][vaultId].balance + qty
end

function token.getBalance(target, from)
	local bal = '0'
	-- If not Target is provided, then return the Senders balance
	if (target and Balances[target]) then
		bal = tostring(Balances[target])
	elseif Balances[from] then
		bal = tostring(Balances[from])
	end
	return bal
end

function token.getBalances()
	return json.encode(Balances)
end

return token
