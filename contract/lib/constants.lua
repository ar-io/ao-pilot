-- GAR
DEFAULT_UNDERNAME_COUNT = 10
DEADLINE_DURATION_MS = 60 * 60 * 1000 -- One hour of miliseconds
MS_IN_A_YEAR = 31536000 * 1000
MIN_OPERATOR_STAKE = 10000 * 1000000  -- Ten thousand IO
MIN_DELEGATED_STAKE = 50 * 1000000    -- Fifty IO

-- Gar
local constants = {}
constants.thirtyDaysSeconds = 60 * 60 * 24 * 30

-- ARNS
DEFAULT_UNDERNAME_COUNT = 10
DEADLINE_DURATION_MS = 60 * 60 * 1000 -- One hour of miliseconds
MS_IN_A_YEAR = 31536000 * 1000
PERMABUY_LEASE_FEE_LENGTH = 10
ANNUAL_PERCENTAGE_FEE = 0.2
ARNS_NAME_DOES_NOT_EXIST_MESSAGE = "Name does not exist in the ArNS Registry!"
ARNS_MAX_UNDERNAME_MESSAGE = "Name has reached undername limit of 10000"
MAX_ALLOWED_UNDERNAMES = 10000
UNDERNAME_LEASE_FEE_PERCENTAGE = 0.001
UNDERNAME_PERMABUY_FEE_PERCENTAGE = 0.005
MS_IN_GRACE_PERIOD = 3 * 7 * 24 * 60 * 60 * 1000

-- BALANCES
GENESIS_FEES = {
    [1] = 5000000,
    [2] = 500000,
    [3] = 100000,
    [4] = 25000,
    [5] = 10000,
    [6] = 5000,
    [7] = 2500,
    [8] = 1500,
    [9] = 1250,
    [10] = 1250,
    [11] = 1250,
    [12] = 1250,
    [13] = 1000,
    [14] = 1000,
    [15] = 1000,
    [16] = 1000,
    [17] = 1000,
    [18] = 1000,
    [19] = 1000,
    [20] = 1000,
    [21] = 1000,
    [22] = 1000,
    [23] = 1000,
    [24] = 1000,
    [25] = 1000,
    [26] = 1000,
    [27] = 1000,
    [28] = 1000,
    [29] = 1000,
    [30] = 1000,
    [31] = 1000,
    [32] = 1000,
    [33] = 1000,
    [34] = 1000,
    [35] = 1000,
    [36] = 1000,
    [37] = 1000,
    [38] = 1000,
    [39] = 1000,
    [40] = 1000,
    [41] = 1000,
    [42] = 1000,
    [43] = 1000,
    [44] = 1000,
    [45] = 1000,
    [46] = 1000,
    [47] = 1000,
    [48] = 1000,
    [49] = 1000,
    [50] = 1000,
    [51] = 1000
}

return constants
