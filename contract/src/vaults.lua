Vaults = Vaults or {}

-- Utility functions that modify global Vaults object
local vaults = {}
local balances = require("balances")
local utils = require("utils")
local constants = require("constants")

function vaults.createVault(from, qty, lockLength, currentTimestamp, msgId)
	if vaults.getVault(from, msgId) then
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

	balances.reduceBalance(from, qty)
	vaults.setVault(from, msgId, {
		balance = qty,
		startTimestamp = currentTimestamp,
		endTimestamp = currentTimestamp + lockLength,
	})
	return vaults.getVault(from, msgId)
end

function vaults.vaultedTransfer(from, recipient, qty, lockLength, currentTimestamp, msgId)
	if balances.getBalance(from) < qty then
		error("Insufficient balance")
	end

	local vault = vaults.getVault(from, msgId)

	if vault then
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

	balances.reduceBalance(from, qty)
	vaults.setVault(recipient, msgId, {
		balance = qty,
		startTimestamp = currentTimestamp,
		endTimestamp = currentTimestamp + lockLength,
	})

	return vaults.getVault(recipient, msgId)
end

function vaults.extendVault(from, extendLength, currentTimestamp, vaultId)
	local vault = vaults.getVault(from, vaultId)

	if not vault then
		error("Invalid vault ID.")
	end

	if currentTimestamp >= vault.endTimestamp then
		error("This vault has ended.")
	end

	local totalTimeRemaining = vault.endTimestamp - currentTimestamp
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

	vault.endTimestamp = vault.endTimestamp + extendLength
	return vaults.getVault(from, vaultId)
end

function vaults.increaseVault(from, qty, vaultId, currentTimestamp)
	if balances.getBalance(from) < qty then
		error("Insufficient balance")
	end

	local vault = vaults.getVault(from, vaultId)

	if not vault then
		error("Invalid vault ID.")
	end

	if currentTimestamp >= vault.endTimestamp then
		error("This vault has ended.")
	end

	balances.reduceBalance(from, qty)
	vault.balance = vault.balance + qty
end

function vaults.getVaults()
	local vaults = utils.deepCopy(Vaults)
	return vaults or {}
end

function vaults.getVault(target, id)
	local vaults = vaults.getVaults()
	return vaults[target] and vaults[target][id]
end

function vaults.setVault(target, id, vault)
	-- create the top key first if not exists
	if not Vaults[target] then
		Vaults[target] = {}
	end
	-- set the vault
	Vaults[target][id] = vault
end

-- return any vaults to owners that have expired
function vaults.pruneVaults(currentTimestamp)
	local allVaults = vaults.getVaults()
	for owner, vaults in pairs(allVaults) do
		for id, nestedVault in pairs(vaults) do
			if currentTimestamp >= nestedVault.endTimestamp then
				balances.increaseBalance(owner, nestedVault.balance)
				vaults[id] = nil
			end
		end
		-- update the owner vault
		allVaults[owner] = vaults
	end
	-- set the vaults to the updated vaults
	Vaults = allVaults
end

return vaults
