package model

import "fmt"

// StageConfig defines a single level's configuration.
type StageConfig struct {
	StageID string        `json:"stage_id"`
	Chapter int           `json:"chapter"`
	Level   int           `json:"level"`
	Waves   []WaveConfig  `json:"waves"`
}

// WaveConfig defines a wave of monsters.
type WaveConfig struct {
	IsBoss   bool            `json:"is_boss"`
	Monsters []MonsterConfig `json:"monsters"`
}

// MonsterConfig defines monster stats in a wave.
type MonsterConfig struct {
	Count int `json:"count"`
	HP    int `json:"hp"`
	ATK   int `json:"atk"`
	DEF   int `json:"def"`
}

// StageRewards defines rewards for clearing a stage.
type StageRewards struct {
	Gold         int64 `json:"gold"`
	SkillTickets int64 `json:"skill_tickets"`
	Chests       int   `json:"chests"`
}

// GenerateStageConfig creates a procedurally generated stage config.
func GenerateStageConfig(chapter, level int) StageConfig {
	stageID := fmt.Sprintf("%d-%d", chapter, level)
	baseHP := 30 + (chapter-1)*20 + (level-1)*5
	baseATK := 5 + (chapter-1)*3 + (level-1)
	baseDEF := 2 + (chapter-1)*2 + (level-1)

	var waves []WaveConfig
	for i := 0; i < 5; i++ {
		isBoss := i == 4
		count := 3
		hpMul := 1.0
		atkMul := 1.0
		if isBoss {
			count = 1
			hpMul = 5.0
			atkMul = 2.0
		}
		waves = append(waves, WaveConfig{
			IsBoss: isBoss,
			Monsters: []MonsterConfig{{
				Count: count,
				HP:    int(float64(baseHP) * hpMul),
				ATK:   int(float64(baseATK) * atkMul),
				DEF:   baseDEF,
			}},
		})
	}

	return StageConfig{StageID: stageID, Chapter: chapter, Level: level, Waves: waves}
}

// CalculateRewards computes rewards for clearing a stage.
func CalculateRewards(chapter, level int) StageRewards {
	baseTickets := int64(1)
	chests := 2
	if level == 10 { // boss level of chapter
		baseTickets = 3
		chests = 3
	}
	return StageRewards{Gold: 0, SkillTickets: baseTickets, Chests: chests}
}
