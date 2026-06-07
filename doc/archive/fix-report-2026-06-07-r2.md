# 修复归档报告（第二轮）

> 日期: 2026-06-07 | 基准: `doc/archive/compliance-report-2026-06-07.md`

---

## 本轮已修复 (4/4)

### 🔴 高: total_pulls 存错列 → 独立列

**文件:**
- `server/migrations/006_add_total_pulls.up.sql` — 新增 `total_pulls INT NOT NULL DEFAULT 0` 列
- `server/internal/repository/skill_repo.go` — 4 处查询从 `equipments->>'total_pulls'` 改为直接读列

---

### 🟡 中: 排行榜分数公式 + Redis元数据

**文件:** `server/internal/service/leaderboard_svc.go`

- `UpdateScore()`: `chapter×1000+level` → `chapter×10000+level`
- 新增 Redis hash 缓存: `leaderboard:meta:{charID}` 存储 nickname/level/cp
- `GetTopN()`: Redis优先读取元数据，DB兜底

---

### 🟡 中: 技能槽重复装备检查

**文件:** `server/internal/service/skill_svc.go`

`SetSkillSlot()` 新增检查：同一技能不能装备到多个槽位。

---

### 🟡 中: 货币流水错误不再静默丢弃

**文件:** `currency_svc.go`、`equipment_svc.go`、`chest_svc.go`、`skill_svc.go`

所有 `_ = InsertCurrencyLog` 改为 `if err := ...; err != nil { slog.Error(...) }`

---

### 🔴 高: 数据库事务

**文件:**
- `server/internal/repository/character_repo.go` — 新增 `DB()` 访问器
- `server/internal/repository/equipment_repo.go` — 新增 `DB()` 访问器
- `server/internal/service/equipment_svc.go` — `Equip()`/`Unequip()`/`Decompose()` 包装事务
- `server/internal/service/chest_svc.go` — `OpenChest()`/`UpgradeZone()` 包装事务

模式: `BeginTx` → `FOR UPDATE` 读取 → `InTx` 写入 → `Commit`

---

## 构建状态

- Go server: ✅ `go build ./cmd/server/` 通过
