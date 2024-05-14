local constants = {}

-- GAR
constants.DEFAULT_UNDERNAME_COUNT = 10
constants.DEADLINE_DURATION_MS = 60 * 60 * 1000 -- One hour of miliseconds
constants.oneYearSeconds = 60 * 60 * 24 * 365
constants.thirtyDaysSeconds = 60 * 60 * 24 * 30
constants.defaultUndernameCount = 10

-- ARNS
constants.DEFAULT_UNDERNAME_COUNT = 10
constants.DEADLINE_DURATION_MS = 60 * 60 * 1000 -- One hour of miliseconds
constants.PERMABUY_LEASE_FEE_LENGTH = 10
constants.ANNUAL_PERCENTAGE_FEE = 0.2
constants.ARNS_NAME_DOES_NOT_EXIST_MESSAGE = "Name does not exist in the ArNS Registry!"
constants.ARNS_MAX_UNDERNAME_MESSAGE = "Name has reached undername limit of 10000"
constants.MAX_ALLOWED_UNDERNAMES = 10000
constants.UNDERNAME_LEASE_FEE_PERCENTAGE = 0.001
constants.UNDERNAME_PERMABUY_FEE_PERCENTAGE = 0.005
constants.oneYearMs = 31536000 * 1000
constants.gracePeriodMs = 3 * 7 * 24 * 60 * 60 * 1000
constants.maxLeaseLengthYears = 5

-- DEMAND
constants.demandSettings = {
	movingAvgPeriodCount = 7,
	periodLengthMs = 60 * 1000 * 24, -- one day
	demandFactorBaseValue = 1,
	demandFactorMin = 0.5,
	demandFactorUpAdjustment = 0.05,
	demandFactorDownAdjustment = 0.025,
	stepDownThreshold = 3,
	criteria = "revenue",
}

-- BALANCES
constants.MAX_TOKEN_LOCK_TIME = 12 * 365 * 24 * 60 * 60 * 1000 -- The maximum amount of blocks tokens can be locked in a vault (12 years of blocks)
constants.MIN_TOKEN_LOCK_TIME = 14 * 24 * 60 * 60 * 1000 -- The minimum amount of blocks tokens can be locked in a vault (14 days of blocks)

constants.genesisFees = {
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
	[51] = 1000,
}

return constants
