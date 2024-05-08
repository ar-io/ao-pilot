-- token.lua
require("state")
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
	
	  if (
		lockLength.valueOf() < MIN_TOKEN_LOCK_BLOCK_LENGTH ||
		lockLength.valueOf() > MAX_TOKEN_LOCK_BLOCK_LENGTH
	  ) {
		throw new ContractError(INVALID_VAULT_LOCK_LENGTH_MESSAGE);
	  }
	
	  const end = startHeight.valueOf() + lockLength.valueOf();
	  const newVault: VaultData = {
		balance: qty.valueOf(),
		start: startHeight.valueOf(),
		end,
	  };
	  vaults[address] = {
		...vaults[address],
		[id]: newVault,
	  };
	  unsafeDecrementBalance(balances, address, qty);
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
