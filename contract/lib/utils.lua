local constants = require '.constants'
local utils = {}

function utils.hasMatchingTag(tag, value)
    return Handlers.utils.hasMatchingTag(tag, value)
end

function utils.reply(msg)
    Handlers.utils.reply(msg)
end

function utils.printTable(t, indent)
    indent = indent or ""
    if type(t) ~= "table" then
        print(indent .. tostring(t))
    else
        for key, value in pairs(t) do
            if type(value) == "table" then
                print(indent .. tostring(key) .. ":")
                utils.printTable(value, indent .. "  ")
            else
                print(indent .. tostring(key) .. ": " .. tostring(value))
            end
        end
    end
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
    if type(tags.Name) ~= "string" then
        return false, "name is required and must be a string."
    end

    -- Validate the character count 'name' field to ensure names 4 characters or below are excluded
    if string.len(tags.Name) <= 4 then
        return false, "1-4 character names are not allowed"
    end

    local name = tostring(tags.Name)
    local startsWithAlphanumeric = name:match("^%w")
    local endsWithAlphanumeric = name:match("%w$")
    local middleValid = name:match("^[%w-]+$")
    local validLength = #name >= 5 and #name <= 51

    if not (startsWithAlphanumeric and endsWithAlphanumeric and middleValid and validLength) then
        return false, "name pattern is invalid."
    end

    -- First, check for the 'atomic' special case.
    local processId = tostring(tags.ProcessId)
    local isAtomic = processId == "atomic"

    -- Then, check for a 43-character base64url pattern.
    -- The pattern checks for a string of length 43 containing alphanumeric characters, hyphens, or underscores.
    local isValidBase64Url = string.match(processId, "^[%w-_]+$") and #processId == 43

    if not isValidBase64Url and not isAtomic then
        return false, "processId pattern is invalid."
    end

    -- If 'years' is present, validate it as an integer between 1 and 5
    if tags.Years then
        if type(tags.Years) ~= "number" or tags.Years % 1 ~= 0 or tags.Years < 1 or tags.Years > 5 then
            return false, "years must be an integer between 1 and 5."
        end
    end

    -- Validate 'PurchaseType' field if present, ensuring it is either 'lease' or 'permabuy'
    if tags.PurchaseType then
        if not (tags.PurchaseType == 'lease' or tags.PurchaseType == 'permabuy') then
            return false, "type pattern is invalid."
        end

        -- Do not allow permabuying names 11 characters or below for this experimentation period
        if tags.PurchaseType == 'permabuy' and string.len(tags.Name) <= 11 then
            return false, "cannot permabuy name 11 characters or below at this time"
        end
    end

    -- Validate the 'auction' field if present, ensuring it is a boolean value
    if tags.Auction then
        if type(tags.Auction) ~= "boolean" then
            return false, "auction must be a boolean."
        end
    end

    -- If all validations pass, return true with an empty message indicating success
    return true, ""
end

function utils.walletHasSufficientBalance(wallet, quantity)
    return Balances[wallet] ~= nil and Balances[wallet] >= quantity
end

function utils.calculateLeaseFee(name, years)
    -- Initial cost to register a name
    -- TODO: Harden the types here to make fees[name.length] an error
    local initialNamePurchaseFee = constants.GENESIS_FEES[string.len(name)]

    -- total cost to purchase name (no demand factor)
    return (
        initialNamePurchaseFee +
        utils.calculateAnnualRenewalFee(
            name,
            years
        )
    );
end

function utils.calculateAnnualRenewalFee(name, years)
    -- Determine annual registration price of name
    local initialNamePurchaseFee = constants.GENESIS_FEES[string.len(name)]

    -- Annual fee is specific % of initial purchase cost
    local nameAnnualRegistrationFee =
        initialNamePurchaseFee * constants.ANNUAL_PERCENTAGE_FEE;

    local totalAnnualRenewalCost = nameAnnualRegistrationFee * years;

    return totalAnnualRenewalCost;
end

function utils.calculatePermabuyFee(name)
    -- genesis price
    local initialNamePurchaseFee = constants.GENESIS_FEES[string.len(name)]

    -- calculate the annual fee for the name for default of 10 years
    local permabuyPrice =
    --  No demand factor
        initialNamePurchaseFee +
        -- total renewal cost pegged to 10 years to purchase name
        utils.calculateAnnualRenewalFee(
            name,
            constants.PERMABUY_LEASE_FEE_LENGTH
        );
    return permabuyPrice
end

function utils.calculateRegistrationFee(purchaseType, name, years)
    if purchaseType == 'lease' then
        return utils.calculateLeaseFee(
            name,
            years
        );
    elseif purchaseType == 'permabuy' then
        return utils.calculatePermabuyFee(
            name
        );
    end
end

function utils.calculateUndernameCost(name, increaseQty, registrationType, years)
    local initialNameFee = constants.GENESIS_FEES[string.len(name)] -- Get the fee based on the length of the name
    if initialNameFee == nil then
        -- Handle the case where there is no fee for the given name length
        return 0
    end

    local undernamePercentageFee = 0
    if registrationType == 'lease' then
        undernamePercentageFee = constants.UNDERNAME_LEASE_FEE_PERCENTAGE
    elseif registrationType == 'permabuy' then
        undernamePercentageFee = constants.UNDERNAME_PERMABUY_FEE_PERCENTAGE
    end

    local totalFeeForQtyAndYears = initialNameFee * undernamePercentageFee * increaseQty * years
    return totalFeeForQtyAndYears
end

function utils.isLeaseRecord(record)
    return record.type == 'lease'
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

function utils.isNameInGracePeriod(record, currentTimestamp)
    if not record or not record.endTimestamp then
        return false
    end -- if it has no timestamp, it is a permabuy
    if (utils.ensureMilliseconds(record.endTimestamp) + constants.MS_IN_GRACE_PERIOD) < currentTimestamp then
        return false
    end
    return true
end

function utils.isActiveReservedName(caller, reservedName, currentTimestamp)
    if not reservedName then return false end

    local target = reservedName.target
    local endTimestamp = reservedName.endTimestamp
    local permanentlyReserved = not target and not endTimestamp

    if permanentlyReserved then
        return true
    end

    local isCallerTarget = caller ~= nil and target == caller
    local isActiveReservation = endTimestamp and endTimestamp > currentTimestamp

    -- If the caller is not the target, and it's still active - the name is considered reserved
    if not isCallerTarget and isActiveReservation then
        return true
    end
    return false
end

function utils.isExistingActiveRecord(record, currentTimestamp)
    if not record then return false end

    if not utils.isLeaseRecord(record) then
        return true
    end

    if utils.isNameInGracePeriod(record, currentTimestamp) then
        return true
    else
        return false
    end
end

function utils.isShortNameRestricted(name, currentTimestamp)
    return (#name < constants.MINIMUM_ALLOWED_NAME_LENGTH and currentTimestamp < constants.SHORT_NAME_RESERVATION_UNLOCK_TIMESTAMP)
end

function utils.isNameRequiredToBeAuction(name, type)
    return (type == 'permabuy' and #name < 12)
end

function utils.assertAvailableRecord(caller, name, currentTimestamp, type, auction)
    local isActiveRecord = utils.isExistingActiveRecord(Records[name], currentTimestamp)
    local isReserved = utils.isActiveReservedName(caller, Reserved[name], currentTimestamp)
    local isShortName = utils.isShortNameRestricted(name, currentTimestamp)
    local isAuctionRequired = utils.isNameRequiredToBeAuction(name, type)
    if isActiveRecord then
        return false, constants.ARNS_NON_EXPIRED_NAME_MESSAGE
    end

    if Reserved[name] and Reserved[name].target == caller then
        -- if the caller is the target of the reserved name, they can buy it
        return true, ""
    end

    if isReserved then
        return false, constants.ARNS_NAME_RESERVED_MESSAGE
    end

    if isShortName then
        return false, constants.ARNS_INVALID_SHORT_NAME
    end

    -- TODO: we may want to move this up if we want to force permabuys for short names on reserved names
    if isAuctionRequired and not auction then
        return false, constants.ARNS_NAME_MUST_BE_AUCTIONED_MESSAGE
    end

    return true
end

function utils.validateIncreaseUndernames(record, qty, currentTimestamp)
    if qty < 1 or qty > 9990 then
        return false, 'Qty is invalid'
    end

    if record == nil then
        return false, constants.ARNS_NAME_DOES_NOT_EXIST_MESSAGE;
    end

    -- This name's lease has expired and cannot have undernames increased
    if not utils.isExistingActiveRecord(record, currentTimestamp) then
        return false, "This name has expired and must renewed before its undername support can be extended."
    end

    -- the new total qty
    if record.undernames + qty > constants.MAX_ALLOWED_UNDERNAMES then
        return false, constants.ARNS_MAX_UNDERNAME_MESSAGE
    end

    return true, ""
end

function utils.calculateYearsBetweenTimestamps(startTimestamp, endTimestamp)
    local yearsRemainingFloat =
        (endTimestamp - startTimestamp) / constants.MS_IN_A_YEAR;
    return string.format("%.2f", yearsRemainingFloat)
end

return utils
