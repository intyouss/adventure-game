# Main UI Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign main scene from TabContainer/BottomNav layout to vertical-stacked layout with battle/equipment/chest areas plus bottom button row for skill-inventory, shop, and leaderboard sliding panel.

**Architecture:** Main scene becomes a vertical Control with named containers (BattleArea, EquipmentArea, ChestArea) and a BottomButtonRow. Mode switching toggles container visibility. Skill inventory and shop are overlay panels within the main scene. Leaderboard is an AnimationPlayer-driven sliding panel.

**Tech Stack:** Godot 4.x, GDScript

---

## File Structure

| File | Role |
|------|------|
| `client/scenes/main/main_scene.tscn` | Root scene — vertical layout with all containers |
| `client/scenes/main/main_ui.gd` | Orchestrator — mode switching, visibility, signal wiring |
| `client/scenes/main/battle_area.gd` | Battle area — stage tabs, battle scene, 5 skill slots |
| `client/scenes/main/equipment_area.gd` | Equipment area — 10-slot grid, equip/unequip |
| `client/scenes/main/chest_area.gd` | Chest area — open, upgrade, comparison popup |
| `client/scenes/main/skill_inventory_panel.gd` | Skill inventory — 6-col grid, replace-to-slot |
| `client/scenes/main/shop_panel.gd` | Shop menu — 2-col grid, shop entry points |
| `client/scenes/main/bottom_button_row.gd` | Bottom row — 3 buttons, highlight active |
| `client/scenes/main/leaderboard_panel.gd` | Leaderboard sliding panel |

All new scripts go under `client/scenes/main/` alongside existing `main_ui.gd`.

---

### Task 1: Rewrite main_scene.tscn — new vertical layout

**Files:**
- Modify: `client/scenes/main/main_scene.tscn`

- [ ] **Step 1: Replace scene structure**

Rewrite `main_scene.tscn` with the new layout. Key containers:

```gdscript
# Structure (in tscn, described as node tree):
# Main (Control)
#   HUD (Control) — LevelLabel, ExpBar, GoldLabel, TicketLabel, CPLabel
#   BattleArea (Control) — placeholder, script: battle_area.gd
#   EquipmentArea (Control) — placeholder, script: equipment_area.gd
#   ChestArea (Control) — placeholder, script: chest_area.gd
#   BottomButtonRow (Control) — 3 buttons
#   SkillInventoryPanel (Control) — initially hidden
#   ShopPanel (Control) — initially hidden
#   LeaderboardPanel (Control) — initially off-screen right
```

Anchor settings:
- HUD: top, full width, height 60
- BattleArea: below HUD, full width, height 220
- EquipmentArea: below BattleArea, full width, height 140
- ChestArea: below EquipmentArea, full width, height 50
- BottomButtonRow: anchored to bottom, full width, height 44
- Panels: full-size overlays, `visible = false` by default

- [ ] **Step 2: Verify scene loads in Godot**

Run: Open project in Godot editor, verify main_scene.tscn opens without errors.

- [ ] **Step 3: Commit**

```bash
git add client/scenes/main/main_scene.tscn
git commit -m "refactor: restructure main scene layout to vertical stack"
```

---

### Task 2: Rewrite main_ui.gd — orchestrator with mode switching

**Files:**
- Modify: `client/scenes/main/main_ui.gd`

- [ ] **Step 1: Replace script with new orchestrator**

```gdscript
extends Control

enum Mode { NORMAL, SKILL_INVENTORY, SHOP }

@onready var hud = $HUD
@onready var battle_area = $BattleArea
@onready var equipment_area = $EquipmentArea
@onready var chest_area = $ChestArea
@onready var bottom_row = $BottomButtonRow
@onready var skill_inventory_panel = $SkillInventoryPanel
@onready var shop_panel = $ShopPanel
@onready var leaderboard_panel = $LeaderboardPanel

@onready var level_label = $HUD/LevelLabel
@onready var exp_bar = $HUD/ExpBar
@onready var gold_label = $HUD/GoldLabel
@onready var ticket_label = $HUD/TicketLabel
@onready var cp_label = $HUD/CPLabel

var _mode: Mode = Mode.NORMAL

func _ready():
	EventBus.login_success.connect(_refresh_hud)
	EventBus.auto_login_success.connect(_refresh_hud)
	bottom_row.mode_changed.connect(_on_mode_changed)
	_refresh_hud()
	_enter_mode(Mode.NORMAL)

func _on_mode_changed(new_mode: Mode):
	_enter_mode(new_mode)

func _enter_mode(mode: Mode):
	_mode = mode
	match mode:
		Mode.NORMAL:
			battle_area.visible = true
			equipment_area.visible = true
			chest_area.visible = true
			skill_inventory_panel.visible = false
			shop_panel.visible = false
		Mode.SKILL_INVENTORY:
			battle_area.visible = true
			equipment_area.visible = false
			chest_area.visible = false
			skill_inventory_panel.visible = true
			shop_panel.visible = false
		Mode.SHOP:
			battle_area.visible = false
			equipment_area.visible = false
			chest_area.visible = false
			skill_inventory_panel.visible = false
			shop_panel.visible = true
	bottom_row.set_active_mode(mode)

func _refresh_hud():
	await PlayerState.load_all()
	var c = PlayerState.character
	if c.is_empty(): return
	level_label.text = "Lv.%d" % c.get("level", 1)
	var exp_to_next = c.get("exp_to_next", 100)
	exp_bar.max_value = max(exp_to_next, 1)
	exp_bar.value = c.get("exp", 0)
	gold_label.text = "💰 %d" % c.get("gold", 0)
	ticket_label.text = "🎫 %d" % c.get("skill_tickets", 0)
	cp_label.text = "CP %.0f" % c.get("cp", 0)
```

- [ ] **Step 2: Commit**

```bash
git add client/scenes/main/main_ui.gd
git commit -m "feat: main_ui orchestrator with mode switching"
```

---

### Task 3: Create bottom_button_row.gd

**Files:**
- Create: `client/scenes/main/bottom_button_row.gd`

- [ ] **Step 1: Create button row script**

```gdscript
extends Control

signal mode_changed(mode: int)

enum Mode { NORMAL, SKILL_INVENTORY, SHOP }

@onready var skill_btn = $SkillBtn
@onready var shop_btn = $ShopBtn
@onready var leaderboard_btn = $LeaderboardBtn

var _current_mode: Mode = Mode.NORMAL

func _ready():
	skill_btn.pressed.connect(_on_skill_pressed)
	shop_btn.pressed.connect(_on_shop_pressed)
	leaderboard_btn.pressed.connect(_on_leaderboard_pressed)

func _on_skill_pressed():
	if _current_mode == Mode.SKILL_INVENTORY:
		_current_mode = Mode.NORMAL
		mode_changed.emit(Mode.NORMAL)
	else:
		_current_mode = Mode.SKILL_INVENTORY
		mode_changed.emit(Mode.SKILL_INVENTORY)
	_update_highlight()

func _on_shop_pressed():
	if _current_mode == Mode.SHOP:
		_current_mode = Mode.NORMAL
		mode_changed.emit(Mode.NORMAL)
	else:
		_current_mode = Mode.SHOP
		mode_changed.emit(Mode.SHOP)
	_update_highlight()

func _on_leaderboard_pressed():
	# Handled by main_ui to toggle leaderboard panel
	pass

func set_active_mode(mode: Mode):
	_current_mode = mode
	_update_highlight()

func _update_highlight():
	skill_btn.modulate = Color.YELLOW if _current_mode == Mode.SKILL_INVENTORY else Color.WHITE
	shop_btn.modulate = Color.YELLOW if _current_mode == Mode.SHOP else Color.WHITE
```

- [ ] **Step 2: Update main_scene.tscn BottomButtonRow children**

In `main_scene.tscn`, add under BottomButtonRow:

```
BottomButtonRow (Control)
  SkillBtn (Button) text="📋 技能仓库"
  ShopBtn (Button) text="🏪 商店"
  LeaderboardBtn (Button) text="🏆"
```

Attach `bottom_button_row.gd` script. Connect `LeaderboardBtn.pressed` to `main_ui._on_leaderboard_toggle()`.

- [ ] **Step 3: Commit**

```bash
git add client/scenes/main/bottom_button_row.gd client/scenes/main/main_scene.tscn
git commit -m "feat: bottom button row with mode toggling"
```

---

### Task 4: Create battle_area.gd — battle with 5 skill slots

**Files:**
- Create: `client/scenes/main/battle_area.gd`

- [ ] **Step 1: Create battle area script**

Integrates stage selection, battle rendering, and 5 skill slots into one control.

```gdscript
extends Control

@onready var chapter_tabs = $ChapterTabs
@onready var stage_name_label = $StageName
@onready var battle_scene = $BattleScene
@onready var skill_slot_0 = $SkillSlots/Slot0  # innate
@onready var skill_slot_1 = $SkillSlots/Slot1
@onready var skill_slot_2 = $SkillSlots/Slot2
@onready var skill_slot_3 = $SkillSlots/Slot3
@onready var skill_slot_4 = $SkillSlots/Slot4

var _slots: Array = []
var _current_chapter: int = 1
var _current_stage: String = ""

func _ready():
	_slots = [skill_slot_0, skill_slot_1, skill_slot_2, skill_slot_3, skill_slot_4]
	_setup_innate_slot()
	_setup_chapter_tabs()
	EventBus.skill_updated.connect(_refresh_skill_slots)
	_refresh_skill_slots()

func _setup_innate_slot():
	skill_slot_0.disabled = true
	skill_slot_0.modulate = Color(1.0, 0.75, 0.0)  # golden for innate
	skill_slot_0.text = "🔥"
	# Get innate skill from character profession
	var prof = PlayerState.character.get("profession", "战士")
	skill_slot_0.tooltip_text = "固定技能: %s" % prof

func _setup_chapter_tabs():
	var chapters = PlayerState.stage_progress.get("max_chapter", 10)
	for ch in range(1, chapters + 1):
		var btn = Button.new()
		btn.text = "第%d章" % ch
		btn.toggle_mode = true
		var chapter = ch
		btn.pressed.connect(func(): _switch_chapter(chapter))
		chapter_tabs.add_child(btn)
		if ch == 1:
			btn.button_pressed = true
	_switch_chapter(1)

func _switch_chapter(chapter: int):
	_current_chapter = chapter
	_load_stages()

func _load_stages():
	# Clear previous stage list
	for child in battle_scene.get_children():
		child.queue_free()

	var res = await NetworkManager.request("GET", "/api/stage/config?chapter=%d" % _current_chapter)
	var stages = []
	if res.code == 0:
		stages = res.data.get("stages", res.data.get("configs", []))
	else:
		for i in range(1, 11):
			stages.append({"stage_id": "%d-%d" % [_current_chapter, i], "level": i})

	for cfg in stages:
		var stage_id = cfg.get("stage_id", "")
		var level = cfg.get("level", 1)
		var unlocked = level <= PlayerState.stage_level if _current_chapter == PlayerState.stage_chapter else _current_chapter < PlayerState.stage_chapter
		var btn = Button.new()
		btn.text = stage_id
		btn.disabled = not unlocked
		var sid = stage_id
		btn.pressed.connect(func(): _start_battle(sid))
		battle_scene.add_child(btn)

func _start_battle(stage_id: String):
	_current_stage = stage_id
	stage_name_label.text = stage_id
	EventBus.battle_started.emit(stage_id)
	var bc = load("res://scenes/battle/battle_controller.gd").new()
	get_tree().root.add_child(bc)
	bc.start_stage(stage_id)

func _refresh_skill_slots():
	var equipped = PlayerState.skill_equipped
	for i in range(1, 5):
		var slot = _slots[i]
		if i - 1 < equipped.size() and equipped[i - 1] != null and equipped[i - 1] != "":
			var name = _find_skill_name(str(equipped[i - 1]))
			slot.text = name if name != "" else "?"
			slot.modulate = Color.WHITE
			slot.get_node_or_null("Border").visible = true
		else:
			slot.text = "+"
			slot.modulate = Color(0.3, 0.3, 0.3)
			slot.get_node_or_null("Border").visible = false

func _find_skill_name(skill_id: String) -> String:
	for skill in PlayerState.skill_inventory:
		if skill.get("skill_id", skill.get("id", "")) == skill_id:
			return skill.get("name", "")
	return ""
```

- [ ] **Step 2: Build battle_area node tree in main_scene.tscn**

Add under BattleArea:

```
BattleArea (Control) script=battle_area.gd
  ChapterTabs (HBoxContainer)
  StageName (Label) — centered, large font
  BattleScene (Control) — battle rendering placeholder
  SkillSlots (HBoxContainer)
    Slot0 (Button) — innate
    Slot1 (Button)
    Slot2 (Button)
    Slot3 (Button)
    Slot4 (Button)
```

- [ ] **Step 3: Commit**

```bash
git add client/scenes/main/battle_area.gd client/scenes/main/main_scene.tscn
git commit -m "feat: battle area with stage selection and 5 skill slots"
```

---

### Task 5: Refactor equipment_area.gd — simplified display

**Files:**
- Create: `client/scenes/main/equipment_area.gd`
- Reference: `client/scenes/equipment/equipment_ui.gd` (for slot names and colors)

- [ ] **Step 1: Create simplified equipment area**

```gdscript
extends Control

const SLOTS = ["weapon","helmet","armor","shoes","ring1","ring2","necklace","bracer","belt","gloves"]
const SLOT_NAMES = {
	"weapon":"武器","helmet":"头盔","armor":"铠甲","shoes":"鞋子",
	"ring1":"戒指1","ring2":"戒指2","necklace":"项链","bracer":"护腕","belt":"腰带","gloves":"手套"
}

@onready var slot_grid = $SlotGrid

func _ready():
	EventBus.inventory_changed.connect(_refresh)
	_refresh()

func _refresh():
	for slot_name in SLOTS:
		var equip_uid = PlayerState.equipped.get(slot_name, "")
		var btn = slot_grid.get_node_or_null(slot_name)
		if not btn or not btn is Button:
			continue
		if equip_uid != "" and equip_uid != null:
			var found = _find_item_by_uid(equip_uid)
			if not found.is_empty():
				var model = EquipmentModel.new().from_dict(found)
				btn.text = "%s\n%s" % [SLOT_NAMES.get(slot_name, slot_name), model.get_quality_name()]
				btn.modulate = model.get_quality_color()
			else:
				btn.text = "%s\n[空]" % SLOT_NAMES.get(slot_name, slot_name)
				btn.modulate = Color.WHITE
		else:
			btn.text = "%s\n[空]" % SLOT_NAMES.get(slot_name, slot_name)
			btn.modulate = Color.WHITE

	# Connect unequip on click
	var slot = slot_name
	btn.pressed.connect(func(): _on_unequip(slot))

func _on_unequip(slot_name: String):
	var equip_uid = PlayerState.equipped.get(slot_name, "")
	if equip_uid == "" or equip_uid == null:
		return
	await NetworkManager.request("POST", "/api/equipment/unequip", {"slot": slot_name})
	await PlayerState.load_equipment()
	_refresh()

func _find_item_by_uid(uid: String) -> Dictionary:
	for item in PlayerState.equipment_inventory:
		if item.get("uid", item.get("id", "")) == uid:
			return item
	return {}
```

- [ ] **Step 2: Build EquipmentArea node tree in main_scene.tscn**

```
EquipmentArea (Control) script=equipment_area.gd
  SlotGrid (GridContainer) columns=5
    weapon (Button)
    helmet (Button)
    armor (Button)
    shoes (Button)
    ring1 (Button)
    ring2 (Button)
    necklace (Button)
    bracer (Button)
    belt (Button)
    gloves (Button)
```

- [ ] **Step 3: Commit**

```bash
git add client/scenes/main/equipment_area.gd client/scenes/main/main_scene.tscn
git commit -m "feat: simplified equipment area with 10-slot grid"
```

---

### Task 6: Refactor chest_area.gd — comparison popup on open

**Files:**
- Create: `client/scenes/main/chest_area.gd`

- [ ] **Step 1: Create chest area with comparison popup**

```gdscript
extends Control

@onready var chest_count_label = $ChestCount
@onready var zone_label = $ZoneLabel
@onready var open_btn = $OpenBtn
@onready var upgrade_btn = $UpgradeBtn
@onready var quantity_selector = $QuantitySelector
@onready var compare_popup = $ComparePopup
@onready var new_item_stats = $ComparePopup/NewItemStats
@onready var current_item_stats = $ComparePopup/CurrentItemStats
@onready var keep_btn = $ComparePopup/KeepBtn
@onready var replace_btn = $ComparePopup/ReplaceBtn

var _selected_count: int = 1
var _pending_drop: Dictionary = {}

func _ready():
	open_btn.pressed.connect(_open_chest)
	upgrade_btn.pressed.connect(_upgrade_zone)
	quantity_selector.add_item("1个")
	quantity_selector.add_item("5个")
	quantity_selector.add_item("10个")
	quantity_selector.add_item("全部")
	quantity_selector.item_selected.connect(func(idx):
		match idx:
			0: _selected_count = 1
			1: _selected_count = 5
			2: _selected_count = 10
			3: _selected_count = PlayerState.chest_count
	)
	quantity_selector.select(0)
	keep_btn.pressed.connect(_on_keep)
	replace_btn.pressed.connect(_on_replace)
	_refresh()

func _refresh():
	await PlayerState.load_chest_info()
	chest_count_label.text = "箱子: %d" % PlayerState.chest_count
	zone_label.text = "区域Lv.%d" % PlayerState.zone_level

func _open_chest():
	var count = min(_selected_count, PlayerState.chest_count)
	if count < 1:
		return
	var res = await NetworkManager.request("POST", "/api/chest/open", {"count": count})
	if res.code == 0:
		var results = res.data.get("results", [])
		if results.size() > 0:
			_show_compare_popup(results[0])
		await PlayerState.load_all()
		_refresh()

func _show_compare_popup(item: Dictionary):
	_pending_drop = item
	var model = EquipmentModel.new().from_dict(item)
	var slot = item.get("slot", "weapon")
	new_item_stats.text = "%s · %s\nATK:%d DEF:%d HP:%d" % [
		model.get_slot_name(), model.get_quality_name(),
		item.get("atk", 0), item.get("def", 0), item.get("hp", 0)
	]

	var equipped_uid = PlayerState.equipped.get(slot, "")
	if equipped_uid != "" and equipped_uid != null:
		var eq_item = _find_item(equipped_uid)
		if not eq_item.is_empty():
			var eq_model = EquipmentModel.new().from_dict(eq_item)
			current_item_stats.text = "当前: %s · %s\nATK:%d DEF:%d HP:%d" % [
				eq_model.get_slot_name(), eq_model.get_quality_name(),
				eq_item.get("atk", 0), eq_item.get("def", 0), eq_item.get("hp", 0)
			]
			keep_btn.visible = true
			replace_btn.text = "替换新装备"
		else:
			current_item_stats.text = "当前: [空]"
			keep_btn.visible = false
			replace_btn.text = "装备"
	else:
		current_item_stats.text = "当前: [空]"
		keep_btn.visible = false
		replace_btn.text = "装备"
	compare_popup.visible = true

func _on_keep():
	# Decompose the new item
	var uid = _pending_drop.get("uid", _pending_drop.get("id", ""))
	if uid != "":
		await NetworkManager.request("POST", "/api/equipment/decompose", {"item_uids": [uid]})
	compare_popup.visible = false
	_pending_drop = {}

func _on_replace():
	var item_uid = _pending_drop.get("uid", _pending_drop.get("id", ""))
	var slot = _pending_drop.get("slot", "weapon")
	await NetworkManager.request("POST", "/api/equipment/equip", {"item_uid": item_uid, "slot": slot})
	await PlayerState.load_equipment()
	compare_popup.visible = false
	_pending_drop = {}
	EventBus.inventory_changed.emit()

func _upgrade_zone():
	var res = await NetworkManager.request("POST", "/api/chest/upgrade_zone")
	if res.code == 0:
		await _refresh()

func _find_item(uid: String) -> Dictionary:
	for item in PlayerState.equipment_inventory:
		if item.get("uid", item.get("id", "")) == uid:
			return item
	return {}
```

- [ ] **Step 2: Build ChestArea + ComparePopup in main_scene.tscn**

```
ChestArea (Control) script=chest_area.gd
  ChestCount (Label)
  ZoneLabel (Label)
  QuantitySelector (OptionButton)
  OpenBtn (Button) text="开箱"
  UpgradeBtn (Button) text="升级"
  ComparePopup (Panel)
    NewItemStats (Label)
    CurrentItemStats (Label)
    KeepBtn (Button) text="保留原装备"
    ReplaceBtn (Button) text="替换新装备"
```

- [ ] **Step 3: Commit**

```bash
git add client/scenes/main/chest_area.gd client/scenes/main/main_scene.tscn
git commit -m "feat: chest area with equipment comparison popup"
```

---

### Task 7: Create skill_inventory_panel.gd

**Files:**
- Create: `client/scenes/main/skill_inventory_panel.gd`

- [ ] **Step 1: Create skill inventory grid**

```gdscript
extends Control

@onready var grid = $ScrollContainer/Grid
@onready var close_btn = $CloseBtn

var _selected_skill_index: int = -1
var _slot_buttons: Array = []

func _ready():
	close_btn.pressed.connect(_on_close)
	EventBus.skill_updated.connect(_refresh)
	_refresh()

func _refresh():
	for child in grid.get_children():
		child.queue_free()
	_slot_buttons.clear()

	# Each skill: button with name + level
	for i in range(PlayerState.skill_inventory.size()):
		var skill = PlayerState.skill_inventory[i]
		var btn = Button.new()
		var model = SkillModel.new().from_dict(skill)
		btn.text = "%s\nLv.%d" % [model.name, model.level]
		btn.modulate = model.get_quality_color()
		var idx = i
		btn.pressed.connect(func(): _on_skill_selected(idx))
		grid.add_child(btn)
		_slot_buttons.append(btn)

	# Grid layout: 6 columns
	grid.columns = 6

func _on_skill_selected(index: int):
	if index < 0 or index >= PlayerState.skill_inventory.size():
		return
	_selected_skill_index = index
	var skill = PlayerState.skill_inventory[index]
	var skill_id = skill.get("skill_id", skill.get("id", ""))

	# Equip to first available slot (2-5, slot 1-4 in PlayerState)
	var equipped = PlayerState.skill_equipped
	var target_slot = -1
	for i in range(4):
		if i >= equipped.size() or equipped[i] == null or equipped[i] == "":
			target_slot = i
			break
	if target_slot < 0:
		target_slot = 0  # Replace slot 1 if all full

	var res = await NetworkManager.request("POST", "/api/skill/equip", {"skill_id": skill_id, "slot": target_slot})
	if res.code == 0:
		await PlayerState.load_skills()
		_refresh()
		EventBus.skill_updated.emit()

func _on_close():
	hide()
```

- [ ] **Step 2: Build SkillInventoryPanel in main_scene.tscn**

```
SkillInventoryPanel (Control) visible=false, script=skill_inventory_panel.gd
  ScrollContainer
    Grid (GridContainer) columns=6
  CloseBtn (Button) text="✕"
```

- [ ] **Step 3: Commit**

```bash
git add client/scenes/main/skill_inventory_panel.gd client/scenes/main/main_scene.tscn
git commit -m "feat: skill inventory panel with 6-column grid"
```

---

### Task 8: Create shop_panel.gd

**Files:**
- Create: `client/scenes/main/shop_panel.gd`

- [ ] **Step 1: Create shop menu**

```gdscript
extends Control

@onready var grid = $Grid
@onready var close_btn = $CloseBtn

func _ready():
	close_btn.pressed.connect(_on_close)
	_setup_shops()

func _setup_shops():
	var shops = [
		{"name": "技能商店", "icon": "📜", "available": true, "scene": "res://scenes/skill/skill_ui.gd"},
		{"name": "装备商店", "icon": "⚔️", "available": false},
		{"name": "待扩展", "icon": "❓", "available": false},
		{"name": "待扩展", "icon": "❓", "available": false},
	]
	for shop in shops:
		var btn = Button.new()
		btn.text = "%s\n%s" % [shop.icon, shop.name]
		btn.disabled = not shop.available
		if shop.available:
			var scene_path = shop.scene
			btn.pressed.connect(func(): _open_shop(scene_path))
		grid.add_child(btn)
	grid.columns = 2

func _open_shop(scene_path: String):
	var shop_scene = load(scene_path).new()
	add_child(shop_scene)

func _on_close():
	hide()
```

- [ ] **Step 2: Build ShopPanel in main_scene.tscn**

```
ShopPanel (Control) visible=false, script=shop_panel.gd
  Grid (GridContainer) columns=2
  CloseBtn (Button) text="✕"
```

- [ ] **Step 3: Commit**

```bash
git add client/scenes/main/shop_panel.gd client/scenes/main/main_scene.tscn
git commit -m "feat: shop panel with 2-column grid"
```

---

### Task 9: Create leaderboard_panel.gd — sliding panel

**Files:**
- Create: `client/scenes/main/leaderboard_panel.gd`

- [ ] **Step 1: Create sliding leaderboard**

```gdscript
extends Control

@onready var panel = $Panel
@onready var list = $Panel/LeaderboardList
@onready var chapter_tabs = $Panel/ChapterTabs
@onready var load_more_btn = $Panel/LoadMoreBtn
@onready var collapse_btn = $Panel/CollapseBtn
@onready var anim_player = $AnimationPlayer

var _current_chapter: int = 1
var _current_page: int = 1
var _page_size: int = 50
var _has_more: bool = false
var _is_open: bool = false

func _ready():
	collapse_btn.pressed.connect(_collapse)
	load_more_btn.pressed.connect(_load_next_page)
	_setup_chapter_tabs()
	_refresh()

func open_panel():
	_is_open = true
	anim_player.play("slide_in")
	collapse_btn.visible = true

func _collapse():
	_is_open = false
	anim_player.play("slide_out")

func _setup_chapter_tabs():
	for ch in range(1, 11):
		var btn = Button.new()
		btn.text = "第%d章" % ch
		btn.toggle_mode = true
		var chapter = ch
		btn.pressed.connect(func(): _switch_chapter(chapter))
		chapter_tabs.add_child(btn)
		if ch == 1:
			btn.button_pressed = true

func _switch_chapter(chapter: int):
	_current_chapter = chapter
	_current_page = 1
	_refresh()

func _load_next_page():
	_current_page += 1
	_load_rankings(true)

func _refresh():
	_current_page = 1
	list.clear()
	_load_my_rank()
	_load_rankings(false)

func _load_my_rank():
	var res = await NetworkManager.request("GET", "/api/leaderboard/my_rank?chapter=%d" % _current_chapter)
	if res.code == 0:
		var mr = res.data
		var rank = mr.get("rank", "?")
		var nickname = mr.get("nickname", "?")
		var level = mr.get("level", 1)
		var cp = mr.get("cp", 0)
		var idx = list.get_item_count()
		list.add_item("★ %3s | 🧑 %-12s | Lv.%3d | CP %.0f" % [rank, nickname, level, cp])
		list.set_item_custom_bg_color(idx, Color(0.2, 0.2, 0.4, 0.5))

func _load_rankings(append: bool):
	if not append:
		list.clear()

	var res = await NetworkManager.request("GET", "/api/leaderboard?page=%d&size=%d&chapter=%d" % [_current_page, _page_size, _current_chapter])
	if res.code == 0:
		var rankings = res.data.get("rankings", res.data if res.data is Array else [])
		_has_more = rankings.size() >= _page_size
		for entry in rankings:
			var rank = entry.get("rank", "?")
			var nickname = entry.get("nickname", "?")
			var level = entry.get("level", 1)
			var cp = entry.get("cp", 0)
			list.add_item("%4s | 🧑 %-12s | Lv.%3d | CP %.0f" % [rank, nickname, level, cp])
		load_more_btn.visible = _has_more
```

- [ ] **Step 2: Add AnimationPlayer to main_scene.tscn**

Add AnimationPlayer to LeaderboardPanel with two animations:
- `slide_in`: Panel position from (x=screen_width) to (x=screen_width - panel_width) over 0.3s
- `slide_out`: Panel position back to (x=screen_width) over 0.3s

LeaderboardPanel starts with `visible = true` but panel positioned off-screen right.

```
LeaderboardPanel (Control) script=leaderboard_panel.gd
  AnimationPlayer
  Panel (Control) — positioned off-screen
    CollapseBtn (Button) text="◀ 收起"
    ChapterTabs (HBoxContainer)
    LeaderboardList (ItemList)
    LoadMoreBtn (Button) text="加载更多"
```

- [ ] **Step 3: Wire leaderboard toggle in main_ui.gd**

Add to `main_ui.gd`:

```gdscript
func _on_leaderboard_toggle():
	if leaderboard_panel._is_open:
		leaderboard_panel._collapse()
	else:
		leaderboard_panel.open_panel()
```

Connect `$BottomButtonRow/LeaderboardBtn.pressed` to `_on_leaderboard_toggle`.

- [ ] **Step 4: Commit**

```bash
git add client/scenes/main/leaderboard_panel.gd client/scenes/main/main_scene.tscn client/scenes/main/main_ui.gd
git commit -m "feat: leaderboard sliding panel from right"
```

---

### Task 10: Final integration — visibility wiring and signal cleanup

**Files:**
- Modify: `client/scenes/main/main_ui.gd`
- Modify: `client/scenes/main/battle_area.gd`

- [ ] **Step 1: Ensure skill inventory panel close returns to NORMAL mode**

In `skill_inventory_panel.gd`, after `_on_close`:

```gdscript
func _on_close():
	get_parent()._enter_mode(get_parent().Mode.NORMAL) if get_parent().has_method("_enter_mode") else hide()
```

In `shop_panel.gd`, after `_on_close`:

```gdscript
func _on_close():
	get_parent()._enter_mode(get_parent().Mode.NORMAL) if get_parent().has_method("_enter_mode") else hide()
```

- [ ] **Step 2: Add chest_area result notification to main_ui**

In `chest_area.gd`, after successful chest open, emit a signal or call main_ui refresh:

```gdscript
signal gold_updated(amount: int)

func _open_chest():
	# ... existing code ...
	EventBus.gold_changed.emit(res.data.get("gold_remaining", 0))
	EventBus.inventory_changed.emit()
```

- [ ] **Step 3: Verify scene structure is complete**

Check that main_scene.tscn has all nodes properly named and connected:

```
Main
├── HUD (LevelLabel, ExpBar, GoldLabel, TicketLabel, CPLabel)
├── BattleArea (ChapterTabs, StageName, BattleScene, SkillSlots[5])
├── EquipmentArea (SlotGrid[10])
├── ChestArea (chest labels, open/upgrade btns, ComparePopup)
├── BottomButtonRow (SkillBtn, ShopBtn, LeaderboardBtn)
├── SkillInventoryPanel (ScrollContainer/Grid, CloseBtn)
├── ShopPanel (Grid, CloseBtn)
└── LeaderboardPanel (AnimationPlayer, Panel with list/tabs)
```

- [ ] **Step 4: Commit**

```bash
git add client/scenes/main/
git commit -m "feat: final integration wiring for main UI redesign"
```
