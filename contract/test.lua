

-- Adjust package.path to include the current directory
package.path = package.path .. ';./lib/?.lua'

local arns = require 'arns'
local gar = require 'gar' 
local constants = require 'constants'
local luaunit = require 'luaunit'

function testBuyRecord()
    local reply = arns.buyRecord("name", "type", "processTxId", "owner")
    luaunit.assertEquals(reply, {
        owner = "owner",
        price = 0,
        type = "type",
        undernameCount = 10,
        processTxId = "processTxId"
    })
end


local testSettings = {
    fqdn = 'test.com',
    protocol = 'https',
    port = 443,
    allowDelegatedStaking = true,
    minDelegatedStake = 100,
    autoStake = true,
    label = 'test',
}

function testJoinNetwork()
    os.clock = function () return 100 end
    local reply = gar.joinNetwork("caller", 100, testSettings, "observerWallet")
    luaunit.assertEquals(reply, {
        operatorStake = 100,
        vaults = {},
        delegates = {},
        startTimestamp = 100,
        stats = {
            prescribedEpochCount = 0,
            observeredEpochCount = 0,
            totalEpochParticipationCount = 0,
            passedEpochCount = 0,
            failedEpochCount = 0,
            failedConsecutiveEpochs = 0,
            passedConsecutiveEpochs = 0,
        },
        settings = testSettings,
        status = 'joined',
        observerWallet = "observerWallet",
    })
end

function testLeaveNetwork()
    os.clock = function () return 200 end
    gar['caller'] = {
        operatorStake = 100,
        vaults = {},
        delegates = {},
        startTimestamp = 100,
        stats = {
            prescribedEpochCount = 0,
            observeredEpochCount = 0,
            totalEpochParticipationCount = 0,
            passedEpochCount = 0,
            failedEpochCount = 0,
            failedConsecutiveEpochs = 0,
            passedConsecutiveEpochs = 0,
        },
        settings = testSettings,
        status = 'joined',
        observerWallet = "observerWallet",
    }

    local reply = gar.leaveNetwork("caller")
    luaunit.assertEquals(reply, {
        operatorStake = 0,
        vaults = {
            caller = {
                amount = 100,
                startTimestamp = 200,
                endTimestamp = 200 + constants.thirtyDaysSeconds * 1000
            }
        },
        delegates = {},
        startTimestamp = 100,
        endTimestamp = 200 + constants.thirtyDaysSeconds * 1000,
        stats = {
            prescribedEpochCount = 0,
            observeredEpochCount = 0,
            totalEpochParticipationCount = 0,
            passedEpochCount = 0,
            failedEpochCount = 0,
            failedConsecutiveEpochs = 0,
            passedConsecutiveEpochs = 0,
        },
        settings = testSettings,
        status = 'leaving',
        observerWallet = "observerWallet",
    })
end

os.exit(luaunit.LuaUnit.run())
