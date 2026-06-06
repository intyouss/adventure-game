package model

// Equipment represents a single piece of equipment.
type Equipment struct {
	ID      string `json:"id"`
	Slot    string `json:"slot"`
	Quality int    `json:"quality"`
	ATK     int    `json:"atk"`
	DEF     int    `json:"def"`
	HP      int    `json:"hp"`
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

// QualityStatRanges defines stat ranges per quality level.
// [min, max] for ATK, DEF, HP respectively.
var QualityStatRanges = map[int][3][2]int{
	1: {{1, 5}, {0, 2}, {0, 10}},
	2: {{3, 8}, {2, 5}, {5, 20}},
	3: {{8, 15}, {5, 10}, {20, 40}},
	4: {{15, 25}, {10, 18}, {40, 70}},
	5: {{25, 40}, {18, 28}, {70, 110}},
	6: {{40, 60}, {28, 40}, {110, 160}},
	7: {{60, 85}, {40, 55}, {160, 220}},
}
