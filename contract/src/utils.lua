local base64 = require("base64")
local crypto = require("crypto.init")
local utils = {}

function utils.hasMatchingTag(tag, value)
	return Handlers.utils.hasMatchingTag(tag, value)
end

function utils.reply(msg)
	Handlers.utils.reply(msg)
end

-- Then, check for a 43-character base64url pattern.
-- The pattern checks for a string of length 43 containing alphanumeric characters, hyphens, or underscores.
function utils.isValidBase64Url(url)
	local isValidBase64Url = #url == 43 and string.match(url, "^[%w-_]+$") ~= nil

	if not isValidBase64Url then
		error("String pattern is invalid.")
	end
	return url
end

function utils.isValidArweaveAddress(address)
	local isValidArweaveAddress = #address == 43 and string.match(address, "^[%w-_]+$") ~= nil

	if not isValidArweaveAddress then
		error("Inavlid arweave address.")
	end
	return address
end

function utils.validateFQDN(fqdn)
	-- Check if the fqdn is not nil and not empty
	if not fqdn or fqdn == "" then
		error("FQDN is empty")
	end

	-- Split the fqdn into parts by dot and validate each part
	local parts = {}
	for part in fqdn:gmatch("[^%.]+") do
		table.insert(parts, part)
	end

	-- Validate each part of the domain
	for _, part in ipairs(parts) do
		-- Check that the part length is between 1 and 63 characters
		if #part < 1 or #part > 63 then
			error("Invalid fqdn format: each part must be between 1 and 63 characters")
		end
		-- Check that the part does not start or end with a hyphen
		if part:match("^-") or part:match("-$") then
			error("Invalid fqdn format: parts must not start or end with a hyphen")
		end
		-- Check that the part contains only alphanumeric characters and hyphen
		if not part:match("^[A-Za-z0-9-]+$") then
			error("Invalid fqdn format: parts must contain only alphanumeric characters or hyphen")
		end
	end

	-- Check if there is at least one top-level domain (TLD)
	if #parts < 2 then
		error("Invalid fqdn format: missing top-level domain")
	end

	return fqdn
end

function utils.findInArray(array, predicate)
	for i = 1, #array do
		if predicate(array[i]) then
			return i -- Return the index of the found element
		end
	end
	return nil -- Return nil if the element is not found
end

function utils.walletHasSufficientBalance(wallet, quantity)
	return Balances[wallet] ~= nil and Balances[wallet] >= quantity
end

function utils.copyTable(table)
	local copy = {}
	for key, value in pairs(table) do
		copy[key] = value
	end
	return copy
end

function utils.deepCopy(original)
	if not original then
		return nil
	end
	local copy = {}
	for key, value in pairs(original) do
		if type(value) == "table" then
			copy[key] = utils.deepCopy(value) -- Recursively copy the nested table
		else
			copy[key] = value
		end
	end
	return copy
end

function utils.lengthOfTable(table)
	local count = 0
	for _ in pairs(table) do
		count = count + 1
	end
	return count
end
function utils.getHashFromBase64URL(str)
	local decodedHash = base64.decode(str, base64.URL_DECODER)
	local hashStream = crypto.utils.stream.fromString(decodedHash)
	return crypto.digest.sha2_256(hashStream).asBytes()
end

function utils.splitString(str, delimiter)
    local result = {}
    for match in (str..delimiter):gmatch("(.-)"..delimiter) do
        result[#result + 1] = match
    end
    return result
end

return utils
