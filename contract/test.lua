

-- Adjust package.path to include the current directory
package.path = package.path .. ';./lib/?.lua'

local arns = require 'arns'
local luaunit = require 'luaunit' -- Corrected the variable name

function test_add()
    luaunit.assertEquals(arns.add(1, 2), 3)
end

function test_subtract()
    luaunit.assertEquals(arns.subtract(2, 1), 1)
end

os.exit(luaunit.LuaUnit.run())
