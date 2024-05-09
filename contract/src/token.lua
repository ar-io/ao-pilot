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
		return false, "Invalid lock length. Must be between 10080 - 3153600."
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

function token.vaultedTransfer()
	-- TODO: implement
	return false
end

function token.extendVault()
	-- TODO: implement
	return false
end

function token.increaseVault()
	-- TODO: implement
	return false
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
