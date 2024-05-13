local constants = require("constants")
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
		error("processId pattern is invalid.")
	end
	return url
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

function utils.validateUpdateGatewaySettings(settings, observerWallet)
	-- Validate 'fqdn' field
	if settings.fqdn and not utils.validateFQDN(settings.fqdn) then
		error("Invalid fqdn format")
	end

	-- Validate 'port' field
	if settings.port and (settings.port < 0 or settings.port > 65535) then
		error("Invalid port number")
	end

	-- Validate 'protocol' field
	if settings.protocol and not (settings.protocol == "https" or settings.protocol == "http") then
		error("Invalid protocol")
	end

	-- Validate 'properties' field
	if settings.properties and not utils.isValidBase64Url(settings.properties) then
		error("Invalid properties format")
	end

	-- Validate 'note' field
	if settings.note and #settings.note > 256 then
		error("Invalid note length")
	end

	-- Validate 'label' field
	if settings.label and #settings.label > 64 then
		error("Invalid label length")
	end

	-- Validate 'observerWallet' field
	if observerWallet and not utils.isValidBase64Url(observerWallet) then
		error("Invalid observerWallet format")
	end

	-- Validate 'autoStake' and 'allowDelegatedStaking' booleans
	if settings.autoStake ~= nil and type(settings.autoStake) ~= "boolean" then
		error("Invalid autoStake value")
	end
	if settings.allowDelegatedStaking ~= nil and type(settings.allowDelegatedStaking) ~= "boolean" then
		error("Invalid allowDelegatedStaking value")
	end

	-- Validate 'delegateRewardShareRatio' field
	if
		settings.delegateRewardShareRatio
		and (settings.delegateRewardShareRatio < 0 or settings.delegateRewardShareRatio > 100)
	then
		error("Invalid delegateRewardShareRatio value")
	end

	-- Validate 'minDelegatedStake' field
	if settings.minDelegatedStake and settings.minDelegatedStake < 100 then
		error("Invalid minDelegatedStake value")
	end

	return true
end

function utils.walletHasSufficientBalance(wallet, quantity)
	return Balances[wallet] ~= nil and Balances[wallet] >= quantity
end

function utils.ensureMilliseconds(timestamp)
	-- Assuming any timestamp before 100000000000 is in seconds
	-- This is a heuristic approach since determining the exact unit of a timestamp can be ambiguous
	local threshold = 100000000000
	if timestamp < threshold then
		-- If the timestamp is below the threshold, it's likely in seconds, so convert to milliseconds
		return timestamp * 1000
	else
		-- If the timestamp is above the threshold, assume it's already in milliseconds
		return timestamp
	end
end

return utils
