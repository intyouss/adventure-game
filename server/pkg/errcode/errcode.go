package errcode

const (
	// 通用
	ErrInternal          = -1
	ErrInvalidTarget     = 10001
	ErrSendTooFrequent   = 10002
	ErrPhoneRequired     = 10003
	ErrInvalidPassword   = 10004
	ErrAlreadyRegistered = 10005
	ErrInvalidCode       = 10006
	ErrNicknameInvalid   = 10007
	ErrAccountNotFound   = 10008
	ErrWrongPassword     = 10009
	ErrLoginTooFrequent  = 10010
	ErrInvalidRefresh    = 10011
	ErrRefreshExpired    = 10012
	ErrUnauthorized      = 10013
	ErrRateLimited       = 10014
	ErrInvalidBody       = 10015

	// 装备 (3xxxx)
	ErrItemNotFound  = 30001
	ErrSlotMismatch  = 30002
	ErrSlotOccupied  = 30003
	ErrItemEquipped  = 30004
	ErrItemNotInInv  = 30005

	// 技能 (4xxxx)
	ErrInsufficientTicket = 40001
	ErrInvalidCount       = 40002
	ErrSkillNotFound      = 40003
	ErrSkillSlotOccupied  = 40004
	ErrInsufficientCards  = 40005
	ErrSkillMaxLevel      = 40006

	// 开箱 (5xxxx)
	ErrInsufficientChests = 50001
	ErrInsufficientGold   = 50002
	ErrZoneMaxLevel       = 50003

	// 关卡 (6xxxx)
	ErrStageNotFound    = 60001
	ErrStageNotUnlocked = 60002

	// 战斗 (7xxxx)
	ErrPlanAFailed    = 70001
	ErrPlanBFailed    = 70002
	ErrSummaryInvalid = 70003
)

var Messages = map[int]string{
	ErrInternal:          "internal server error",
	ErrInvalidTarget:     "invalid target format",
	ErrSendTooFrequent:   "send code too frequent",
	ErrPhoneRequired:     "phone or email required",
	ErrInvalidPassword:   "invalid password format",
	ErrAlreadyRegistered: "already registered",
	ErrInvalidCode:       "invalid or expired code",
	ErrNicknameInvalid:   "nickname too short or too long",
	ErrAccountNotFound:   "account not found",
	ErrWrongPassword:     "wrong password",
	ErrLoginTooFrequent:  "login too frequent",
	ErrInvalidRefresh:    "invalid refresh token",
	ErrRefreshExpired:    "refresh token expired",
	ErrUnauthorized:      "unauthorized",
	ErrRateLimited:       "rate limit exceeded",
	ErrInvalidBody:       "invalid request body",
	ErrItemNotFound:      "item not found",
	ErrSlotMismatch:      "slot mismatch",
	ErrSlotOccupied:      "slot already occupied",
	ErrItemEquipped:      "item is equipped, unequip first",
	ErrItemNotInInv:      "item not in inventory",
	ErrInsufficientTicket:"insufficient skill tickets",
	ErrInvalidCount:      "invalid count",
	ErrSkillNotFound:     "skill not found",
	ErrSkillSlotOccupied: "skill slot occupied",
	ErrInsufficientCards: "insufficient cards for upgrade",
	ErrSkillMaxLevel:     "skill already max level",
	ErrInsufficientChests:"insufficient chests",
	ErrInsufficientGold:  "insufficient gold",
	ErrZoneMaxLevel:      "zone already max level",
	ErrStageNotFound:     "stage not found",
	ErrStageNotUnlocked:  "stage not unlocked",
	ErrPlanAFailed:       "verification failed (plan A)",
	ErrPlanBFailed:       "verification failed (plan B)",
	ErrSummaryInvalid:    "battle summary invalid",
}

func Msg(code int) string {
	if m, ok := Messages[code]; ok {
		return m
	}
	return "unknown error"
}
