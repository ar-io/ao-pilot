local state = require("state")
local startTimestamp = 0


local json = require("json") -- Assuming json library for encoding/decoding

describe("State loading functionality", function()
    -- Sample data for testing
    local validJson, invalidJson, emptyJson
    local startTimestamp = os.time()

    -- Setup function to initialize test data
    before_each(function()
        validJson = json.encode({
            records = { key1 = { processId = 123, value = "Record1" } },
            gateways = { key2 = { details = "Gateway1" } },
            observations = { key3 = { observation = "Observation1" } },
            distributions = { distribution1 = "Data1" },
            demandFactoring = { demandKey = "Demand1" }
        })
    end)

    -- Tests for each specific scenario
    it("should correctly load state from valid JSON data", function()
        local reply, err = state.loadState(validJson, startTimestamp)
        assert.is_nil(err)
        assert.is_true((string.find(reply, "Records Updated: 1")) > 0)
        assert.is_true((string.find(reply, "Gateways Updated: 1")) > 0)
        assert.is_true((string.find(reply, "Observations Updated: 1")) > 0)
        assert.is_true((string.find(reply, "Distributions Updated: 1")) > 0)
        assert.is_true((string.find(reply, "Demand Updated: 1")) > 0)
    end)

    it("should handle partial state update", function()
        local partialJson = json.encode({ records = { key1 = { processId = 123, value = "Record2" } } })
        local reply, err = state.loadState(partialJson, startTimestamp)

        assert.is_nil(err)
        assert.is_true((string.find(reply, "Records Updated: 1")) > 0)
        Records = {}
    end)


    it("should handle JSON with missing expected fields", function()
        local incompleteJson = json.encode({ records = 100, gateways = "gateways" }) -- No processId
        local reply, err = state.loadState(incompleteJson, startTimestamp)

        assert.is_false(reply)
        assert.are.same("The 'records' field is missing or not in the expected format.", err)
    end)

    after_each(function()
        -- Reset or clear global or shared variables if necessary
        Records = nil
        Gateways = nil
        Observations = nil
        Distributions = nil
        Demand = nil
    end)
end)
