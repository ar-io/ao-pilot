-- token.lua
local constants = require("constants")
local token = {
	balances = {},
	vaults = {},
}

function token.transfer(recipient, from, qty)
	assert(type(recipient) == "string", "Recipient is required!")
	-- TODO: assert to/from are 43 character arweave tx ids
	assert(type(qty) == "number", "Quantity is required and must be a number!")
	assert(qty > 0, "Quantity must be greater than 0")

	token.reduceBalance(from, qty)
	token.increaseBalance(recipient, qty)

	return {
		[from] = token.balances[from],
		[recipient] = token.balances[recipient],
	}
end

function token.createVault(from, qty, lockLength, currentTimestamp, msgId)
	if token.getVault(from, msgId) then
		error("Vault with id " .. msgId .. " already exists")
	end

	if lockLength < constants.MIN_TOKEN_LOCK_TIME or lockLength > constants.MAX_TOKEN_LOCK_TIME then
		error(
			"Invalid lock length. Must be between "
				.. constants.MIN_TOKEN_LOCK_TIME
				.. " - "
				.. constants.MAX_TOKEN_LOCK_TIME
		)
	end

	token.reduceBalance(from, qty)
	token.setVault(from, msgId, {
		balance = qty,
		startTimestamp = currentTimestamp,
		endTimestamp = currentTimestamp + lockLength,
	})
	return token.getVault(from, msgId)
end

function token.vaultedTransfer(from, recipient, qty, lockLength, currentTimestamp, msgId)
	if token.getVault(recipient, msgId) ~= nil then
		error("Vault with id " .. msgId .. " already exists")
	end

	if lockLength < constants.MIN_TOKEN_LOCK_TIME or lockLength > constants.MAX_TOKEN_LOCK_TIME then
		error(
			"Invalid lock length. Must be between "
				.. constants.MIN_TOKEN_LOCK_TIME
				.. " - "
				.. constants.MAX_TOKEN_LOCK_TIME
		)
	end

	token.reduceBalance(from, qty)
	token.setVault(recipient, msgId, {
		balance = qty,
		startTimestamp = currentTimestamp,
		endTimestamp = currentTimestamp + lockLength,
	})

	return token.getVault(recipient, msgId)
end

function token.extendVault(from, extendLength, currentTimestamp, vaultId)
	if token.getVault(from, vaultId) == nil then
		error("Invalid vault ID.")
	end

	if currentTimestamp >= token.getVault(from, vaultId).endTimestamp then
		error("This vault has ended.")
	end

	local totalTimeRemaining = token.getVault(from, vaultId).endTimestamp - currentTimestamp
	if
		extendLength < constants.MIN_TOKEN_LOCK_BLOCK_LENGTH
		or extendLength > constants.MAX_TOKEN_LOCK_BLOCK_LENGTH
		or totalTimeRemaining + extendLength > constants.MAX_TOKEN_LOCK_BLOCK_LENGTH
	then
		error(
			"Invalid lock length. Must be between "
				.. constants.MIN_TOKEN_LOCK_TIME
				.. " - "
				.. constants.MAX_TOKEN_LOCK_TIME
		)
	end

	local newEnd = token.getVault(from, vaultId).endTimestamp + extendLength
	token.getVault(from, vaultId).endTimestamp = newEnd
	return token.getVault(from, vaultId)
end

function token.increaseVault(from, qty, vaultId, currentTimestamp)
	if token.getBalance(from) < qty then
		error("Insufficient funds!")
	end

	if token.getVault(from, vaultId) then
		error("Invalid vault ID.")
	end

	if currentTimestamp >= token.getVault(from, vaultId).endTimestamp then
		error("This vault has ended.")
	end

	token.reduceBalance(from, qty)
	token.getVault(from, vaultId).balance = token.getVault(from, vaultId).balance + qty
end

function token.getBalance(target)
	return token.balances[target] or 0
end

function token.getBalances()
	return token.balances
end

function token.getVaults()
	return token.vaults
end

function token.getVault(target, id)
	if not token.vaults[target] then
		return nil
	end
	return token.vaults[target][id]
end

function token.reduceBalance(target, qty)
	if token.getBalance(target) < qty then
		error("Insufficient balance")
	end

	token.balances[target] = token.getBalance(target) - qty
end

function token.increaseBalance(target, qty)
	local prevBalance = token.balances[target] or 0
	token.balances[target] = prevBalance + qty
	return
end

function token.setVault(target, id, vault)
	if not token.vaults[target] then
		token.vaults[target] = {}
	end
	token.vaults[target][id] = vault
end

return token
