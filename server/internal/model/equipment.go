package model

// Equipment represents a single piece of equipment.
type Equipment struct {
	ID       string  `json:"id"`
	Name     string  `json:"name"`
	Slot     string  `json:"slot"`
	Quality  int     `json:"quality"`
	ATK      int     `json:"atk"`
	DEF      int     `json:"def"`
	HP       int     `json:"hp"`
	CritRate float64 `json:"crit_rate"`
	AtkSpeed float64 `json:"atk_speed"`
}

// EquipmentSlots lists all 10 equipment slots in order.
var EquipmentSlots = []string{
	"weapon", "helmet", "armor", "shoes",
	"ring1", "ring2", "necklace", "bracer", "belt", "gloves",
}

// QualityNames maps quality level to display name.
var QualityNames = map[int]string{
	1: "普通",
	2: "优秀",
	3: "稀有",
	4: "精良",
	5: "史诗",
	6: "传说",
	7: "神话",
}

// QualityStatRanges defines stat ranges per quality level: [min, max] for ATK, DEF, HP.
// Secondary stats CritRate and AtkSpeed are randomized within fixed ranges.
var QualityStatRanges = map[int][3][2]int{
	1: {{5, 15}, {3, 8}, {20, 50}},
	2: {{16, 30}, {9, 18}, {51, 100}},
	3: {{31, 50}, {19, 32}, {101, 180}},
	4: {{51, 80}, {33, 52}, {181, 320}},
	5: {{81, 120}, {53, 78}, {321, 520}},
	6: {{121, 180}, {79, 115}, {521, 800}},
	7: {{181, 260}, {116, 165}, {801, 1200}},
}

// EquipmentNames maps slot → quality → list of names.
var EquipmentNames = map[string]map[int][]string{
	"weapon": {
		1: {"生锈的铁剑", "破损的木杖", "钝刃短刀"},
		2: {"精铁长剑", "淬火弯刀", "橡木法杖"},
		3: {"寒冰之刃", "烈焰战斧", "暗影匕首"},
		4: {"龙牙长剑", "圣光战锤", "幽魂镰刀"},
		5: {"霜之哀伤", "火之高兴", "雷霆之怒"},
		6: {"灭世者", "诸神之剑", "混沌之刃"},
		7: {"创世神剑", "永恒之光", "虚空斩"},
	},
	"helmet": {
		1: {"破旧皮帽", "生锈铁盔"},
		2: {"精铁头盔", "硬皮兜帽"},
		3: {"秘银头盔", "暗影面具"},
		4: {"龙鳞头盔", "圣光之冠"},
		5: {"智慧王冠", "不朽头盔"},
		6: {"神谕头盔", "混沌面甲"},
		7: {"创世王冠", "虚空凝视"},
	},
	"armor": {
		1: {"破旧皮甲", "生锈铁甲"},
		2: {"精铁铠甲", "硬皮战甲"},
		3: {"秘银战甲", "暗影长袍"},
		4: {"龙鳞战甲", "圣光铠甲"},
		5: {"不朽战甲", "符文铠甲"},
		6: {"神谕战甲", "混沌魔甲"},
		7: {"创世神甲", "虚空之壳"},
	},
	"shoes": {
		1: {"草鞋", "破旧皮靴"},
		2: {"精铁战靴", "硬皮长靴"},
		3: {"秘银长靴", "暗影之靴"},
		4: {"龙鳞战靴", "圣光之靴"},
		5: {"疾风之靴", "不朽战靴"},
		6: {"神行靴", "混沌步伐"},
		7: {"创世神靴", "虚空行者"},
	},
	"ring1": {
		1: {"铜戒指", "骨戒"},
		2: {"银戒指", "翠玉戒"},
		3: {"蓝宝石戒", "暗影之戒"},
		4: {"龙眼戒", "圣光之戒"},
		5: {"永恒之戒", "暴风之戒"},
		6: {"神谕之戒", "混沌之环"},
		7: {"创世之戒", "虚空之环"},
	},
	"ring2": {
		1: {"铜戒指", "骨戒"},
		2: {"银戒指", "翠玉戒"},
		3: {"蓝宝石戒", "暗影之戒"},
		4: {"龙眼戒", "圣光之戒"},
		5: {"永恒之戒", "暴风之戒"},
		6: {"神谕之戒", "混沌之环"},
		7: {"创世之戒", "虚空之环"},
	},
	"necklace": {
		1: {"麻绳项链", "兽牙挂坠"},
		2: {"银链坠", "翡翠挂坠"},
		3: {"蓝宝石坠", "暗影护符"},
		4: {"龙牙挂坠", "圣光护符"},
		5: {"不朽挂坠", "元素之心"},
		6: {"神谕护符", "混沌之坠"},
		7: {"创世之心", "虚空之坠"},
	},
	"bracer": {
		1: {"破旧护腕", "皮护腕"},
		2: {"铁护腕", "硬皮护腕"},
		3: {"秘银护腕", "暗影护腕"},
		4: {"龙鳞护腕", "圣光护腕"},
		5: {"不朽护腕", "符文护腕"},
		6: {"神谕护腕", "混沌护腕"},
		7: {"创世护腕", "虚空护腕"},
	},
	"belt": {
		1: {"麻绳腰带", "破旧皮带"},
		2: {"铁扣腰带", "硬皮腰带"},
		3: {"秘银腰带", "暗影束带"},
		4: {"龙鳞腰带", "圣光腰带"},
		5: {"不朽腰带", "符文束带"},
		6: {"神谕腰带", "混沌束带"},
		7: {"创世腰带", "虚空束带"},
	},
	"gloves": {
		1: {"破旧手套", "皮手套"},
		2: {"铁手套", "硬皮手套"},
		3: {"秘银手套", "暗影手套"},
		4: {"龙鳞手套", "圣光手套"},
		5: {"不朽手套", "符文手套"},
		6: {"神谕手套", "混沌之握"},
		7: {"创世之手", "虚空之握"},
	},
}

// RandomEquipName picks a random name for a given slot and quality.
func RandomEquipName(slot string, quality int) string {
	slotNames, ok := EquipmentNames[slot]
	if !ok {
		return slot
	}
	names, ok := slotNames[quality]
	if !ok || len(names) == 0 {
		names = slotNames[1]
	}
	// Use a simple deterministic name; random selection is in the service layer
	// This is just a fallback
	return names[0]
}
