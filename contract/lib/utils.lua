local utils = {}

function utils.hasMatchingTag(tag, value)
    return Handlers.utils.hasMatchingTag(tag, value)
end

function utils.reply(msg)
    Handlers.utils.reply(msg)
end

--- Validates the fields of a 'buy record' message for compliance with expected formats and value ranges.
-- This function checks the following fields in the message:
-- 1. 'name' - Required and must be a string matching specific naming conventions.
-- 2. 'processId' - Optional, must match a predefined pattern (including a special case 'atomic' or a standard 43-character base64url string).
-- 3. 'years' - Optional, must be an integer between 1 and 5.
-- 4. 'type' - Optional, must be either 'lease' or 'permabuy'.
-- 5. 'auction' - Optional, must be a boolean value.
-- @param msg The message table containing the Tags field with all necessary data.
-- @return boolean, string First return value indicates whether the message is valid (true) or not (false),
-- and the second return value provides an error message in case of validation failure.
function utils.validateBuyRecord(tags)
    -- Validate the presence and type of the 'name' field
    if type(tags.name) ~= "string" then
        return false, "name is required and must be a string."
    end

    -- Validate the character count 'name' field to ensure names 4 characters or below are excluded
    if string.len(tags.name) <= 4 then
        return false, "1-4 character names are not allowed"
    end

    local name = tostring(tags.name)
    local startsWithAlphanumeric = name:match("^%w")
    local endsWithAlphanumeric = name:match("%w$")
    local middleValid = name:match("^[%w-]+$")
    local validLength = #name >= 5 and #name <= 51

    if not (startsWithAlphanumeric and endsWithAlphanumeric and middleValid and validLength) then
        return false, "name pattern is invalid."
    end

    -- First, check for the 'atomic' special case.
    local processId = tostring(tags.processId)
    local isAtomic = processId == "atomic"

    -- Then, check for a 43-character base64url pattern.
    -- The pattern checks for a string of length 43 containing alphanumeric characters, hyphens, or underscores.
    local isValidBase64Url = string.match(processId, "^[%w-_]+$") and #processId == 43

    if not isValidBase64Url and not isAtomic then
        return false, "processId pattern is invalid."
    end

    -- If 'years' is present, validate it as an integer between 1 and 5
    if tags.years then
        if type(tags.years) ~= "number" or tags.years % 1 ~= 0 or tags.years < 1 or tags.years > 5 then
            return false, "years must be an integer between 1 and 5."
        end
    end

    -- Validate 'purchaseType' field if present, ensuring it is either 'lease' or 'permabuy'
    if tags.purchaseType then
        if not (tags.purchaseType == 'lease' or tags.purchaseType == 'permabuy') then
            return false, "type pattern is invalid."
        end

        -- Do not allow permabuying names 11 characters or below for this experimentation period
        if tags.purchaseType == 'permabuy' and string.len(tags.name) <= 11 then
            return false, "cannot permabuy name 11 characters or below at this time"
        end
    end

    -- Validate the 'auction' field if present, ensuring it is a boolean value
    if tags.auction then
        if type(tags.auction) ~= "boolean" then
            return false, "auction must be a boolean."
        end
    end

    -- If all validations pass, return true with an empty message indicating success
    return true, ""
end

return utils
