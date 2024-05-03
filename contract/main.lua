

-- Adjust package.path to include the current directory
package.path = package.path .. ';./lib/?.lua'

local arns = require 'arns'
local balances = require 'balances'
local gar = require 'gar'

print(arns.add(1, 2))
print(arns.subtract(2, 1))
print(balances.add(1, 2))
print(balances.subtract(2, 1))
print(gar.add(1, 2))
print(gar.subtract(2, 1))
