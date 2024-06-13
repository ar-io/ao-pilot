-- spec/utils_spec.lua
local utils = require("src.common.utils")

describe("utils.camelCase", function()
	it("should convert snake_case to camelCase", function()
		assert.are.equal(utils.camelCase("start_end"), "startEnd")
		assert.are.equal(utils.camelCase("multiple_words_example"), "multipleWordsExample")
	end)

	it("should convert kebab-case to camelCase", function()
		assert.are.equal(utils.camelCase("start-end"), "startEnd")
		assert.are.equal(utils.camelCase("multiple-words-example"), "multipleWordsExample")
	end)

	it("should convert space-separated words to camelCase", function()
		assert.are.equal(utils.camelCase("start end"), "startEnd")
		assert.are.equal(utils.camelCase("multiple words example"), "multipleWordsExample")
	end)

	it("should convert PascalCase to camelCase", function()
		assert.are.equal(utils.camelCase("StartEnd"), "startEnd")
		assert.are.equal(utils.camelCase("MultipleWordsExample"), "multipleWordsExample")
	end)

	it("should handle mixed cases", function()
		assert.are.equal(utils.camelCase("Start_end-Test"), "startEndTest")
		assert.are.equal(utils.camelCase("Multiple_Words-example Test"), "multipleWordsExampleTest")
	end)

	it("should handle already camelCase strings", function()
		assert.are.equal(utils.camelCase("startEnd"), "startEnd")
		assert.are.equal(utils.camelCase("multipleWordsExample"), "multipleWordsExample")
	end)

	it("should handle single character strings", function()
		assert.are.equal(utils.camelCase("a"), "a")
		assert.are.equal(utils.camelCase("A"), "a")
	end)

	it("should handle empty strings", function()
		assert.are.equal(utils.camelCase(""), "")
	end)
end)
