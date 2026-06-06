package repository

// ChestRepo is a thin wrapper for chest-related operations.
// Most chest ops go through CharacterRepo.UpdateChestFields.
type ChestRepo struct {
	charRepo *CharacterRepo
}

func NewChestRepo(charRepo *CharacterRepo) *ChestRepo {
	return &ChestRepo{charRepo: charRepo}
}
