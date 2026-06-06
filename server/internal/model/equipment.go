package model

// Equipment represents a single piece of equipment.
type Equipment struct {
	ID       string  `json:"id"`
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
