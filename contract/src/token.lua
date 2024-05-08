-- token.lua
local json = require '.json'
if not Denomination then
	Denomination = 6
end
if not Balances then
	Balances = {}
end

local token = {}

function token.transfer(recipient, from, qty)
	assert(type(recipient) == 'string', 'Recipient is required!')

	if not Balances[from] then Balances[from] = 0 end

	if not Balances[recipient] then Balances[recipient] = 0 end

	assert(type(qty) == 'number', 'qty must be number')
	assert(qty > 0, 'Quantity must be greater than 0')
	if Balances[from] >= qty then
		Balances[from] = Balances[from] - qty
		Balances[recipient] = Balances[recipient] + qty
		return true
	else
		return false, Balances[from];
	end
end

-- TO DO: Add vaulting
function token.vault()
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
