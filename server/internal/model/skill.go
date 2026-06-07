package model

// Skill represents a skill owned by a player.
type Skill struct {
	ID      string  `json:"id"`
	Name    string  `json:"name"`
	Quality int     `json:"quality"`
	Level   int     `json:"level"`
	Cards   int     `json:"cards"` // duplicate cards for upgrading
	Coeff   float64 `json:"coeff"` // skill damage coefficient
}

// SkillConfig defines a skill template.
type SkillConfig struct {
	ID        string  `json:"id"`
	Name      string  `json:"name"`
	Quality   int     `json:"quality"`
	BaseCoeff float64 `json:"base_coeff"`
}

// MaxSkillQuality is the maximum skill quality (skills use 5 tiers, not 7).
const MaxSkillQuality = 5

// SkillQualityNames maps skill quality to display name.
var SkillQualityNames = map[int]string{
	1: "普通",
	2: "优秀",
	3: "稀有",
	4: "精良",
	5: "传说",
}

// Initial skill pool (v1: 4 skills across 5 qualities).
var SkillPool = []SkillConfig{
	// Quality 1 - 普通
	{ID: "s-fireball", Name: "火球术", Quality: 1, BaseCoeff: 1.2},
	{ID: "s-iceshard", Name: "冰晶术", Quality: 1, BaseCoeff: 1.1},
	{ID: "s-windblade", Name: "风刃", Quality: 1, BaseCoeff: 1.15},
	{ID: "s-earthspike", Name: "地刺", Quality: 1, BaseCoeff: 1.25},
	// Quality 2 - 优秀
	{ID: "s-icebolt", Name: "冰锥术", Quality: 2, BaseCoeff: 1.5},
	{ID: "s-firestorm", Name: "烈焰风暴", Quality: 2, BaseCoeff: 1.6},
	{ID: "s-thunderclap", Name: "雷击", Quality: 2, BaseCoeff: 1.55},
	{ID: "s-poisonmist", Name: "毒雾", Quality: 2, BaseCoeff: 1.45},
	// Quality 3 - 稀有
	{ID: "s-meteor", Name: "陨石术", Quality: 3, BaseCoeff: 2.0},
	{ID: "s-blizzard", Name: "暴风雪", Quality: 3, BaseCoeff: 2.1},
	{ID: "s-lightning", Name: "雷霆万钧", Quality: 3, BaseCoeff: 2.05},
	{ID: "s-shadowstrike", Name: "暗影突袭", Quality: 3, BaseCoeff: 1.95},
	// Quality 4 - 精良
	{ID: "s-phoenix", Name: "凤凰涅槃", Quality: 4, BaseCoeff: 2.5},
	{ID: "s-earthquake", Name: "地震术", Quality: 4, BaseCoeff: 2.6},
	{ID: "s-holylight", Name: "圣光裁决", Quality: 4, BaseCoeff: 2.55},
	{ID: "s-voidrift", Name: "虚空裂隙", Quality: 4, BaseCoeff: 2.45},
	// Quality 5 - 传说
	{ID: "s-dragonfire", Name: "龙息", Quality: 5, BaseCoeff: 3.0},
	{ID: "s-ragnarok", Name: "诸神黄昏", Quality: 5, BaseCoeff: 3.2},
	{ID: "s-celestial", Name: "天罚", Quality: 5, BaseCoeff: 3.1},
	{ID: "s-apocalypse", Name: "末日降临", Quality: 5, BaseCoeff: 2.9},
}

// GachaPool maps shop level → allowed qualities + weight overrides.
// Weights are relative; total normalized.
type GachaTier struct {
	Qualities []int
	Weights   map[int]float64
}

// MaxShopLevel is the maximum skill shop level.
const MaxShopLevel = 28

// GachaTiers provides gacha quality pools by shop level band.
// Level 1-4: Common+Uncommon   | Level 5-8: adds Rare
// Level 9-12: adds Epic        | Level 13-20: adds Legendary
// Level 21-28: higher Legendary weight
var GachaTiers = [][]int{
	0: nil, // unused (1-indexed would map to shop level 0)
	1: {1, 2},
	2: {1, 2},
	3: {1, 2},
	4: {1, 2},
	5: {1, 2, 3},
	6: {1, 2, 3},
	7: {1, 2, 3},
	8: {1, 2, 3},
	9: {1, 2, 3, 4},
	10: {1, 2, 3, 4},
	11: {1, 2, 3, 4},
	12: {1, 2, 3, 4},
	13: {1, 2, 3, 4, 5},
	14: {1, 2, 3, 4, 5},
	15: {1, 2, 3, 4, 5},
	16: {1, 2, 3, 4, 5},
	17: {1, 2, 3, 4, 5},
	18: {1, 2, 3, 4, 5},
	19: {1, 2, 3, 4, 5},
	20: {1, 2, 3, 4, 5},
	21: {1, 2, 3, 4, 5},
	22: {1, 2, 3, 4, 5},
	23: {1, 2, 3, 4, 5},
	24: {1, 2, 3, 4, 5},
	25: {1, 2, 3, 4, 5},
	26: {1, 2, 3, 4, 5},
	27: {1, 2, 3, 4, 5},
	28: {1, 2, 3, 4, 5},
}

// GachaWeights provides quality weights by shop level.
// At higher shop levels, higher rarities have increased weights.
func GachaWeights(shopLevel int) map[int]float64 {
	switch {
	case shopLevel <= 4:
		return map[int]float64{1: 0.70, 2: 0.30}
	case shopLevel <= 8:
		return map[int]float64{1: 0.50, 2: 0.35, 3: 0.15}
	case shopLevel <= 12:
		return map[int]float64{1: 0.40, 2: 0.30, 3: 0.20, 4: 0.10}
	case shopLevel <= 20:
		return map[int]float64{1: 0.30, 2: 0.25, 3: 0.20, 4: 0.15, 5: 0.10}
	default:
		return map[int]float64{1: 0.20, 2: 0.20, 3: 0.20, 4: 0.20, 5: 0.20}
	}
}
