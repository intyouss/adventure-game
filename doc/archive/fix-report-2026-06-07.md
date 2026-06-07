# 修复归档报告

> 日期: 2026-06-07 | 基准: `doc/archive/compliance-report-2026-06-07.md`

---

## 已修复问题 (4/6)

### 🔴 致命: skills/skill_slots JSONB 格式不匹配

**文件:**
- `server/migrations/002_create_characters.up.sql:12` — `skill_slots` DEFAULT `'{"1":"",...}'` → `'["","","",""]'`
- `server/migrations/004_add_stage_progress.up.sql:3` — `skills` DEFAULT `'[]'` → `'{}'`
- `server/internal/service/skill_svc.go` — `GetEquippedSkills()` 新增旧格式兼容回退

**说明:** 迁移默认值从 object→array (skill_slots) 和 array→object (skills)，与 Go 代码解析格式一致。同时为已存在的旧数据添加了兼容回退逻辑。

---

### 🔴 致命: 战斗服务未接入

**文件:** `server/cmd/server/main.go`

**变更:**
- 移除 `_ = battleSvc`
- WebSocket handler 从 echo 改为完整消息分发：
  - `request_stage_config` → 返回生成关卡配置
  - `battle_summary` → Plan A 即时校验 → Plan B 服务端模拟 → settle 结算
- 新增 `parseStageFromID()` 辅助函数

---

### 🔴 高: 关卡奖励含金币

**文件:** `server/internal/model/stage.go`

**变更:** `CalculateRewards()` 不再计算/返回金币，`Gold` 固定为 `0`。设计文档明确关卡不掉落金币。

---

### 🟡 中: 装备区信号连接泄漏

**文件:** `client/scenes/main/equipment_area.gd:23-24`

**变更:**
```gdscript
# 旧: is_connected 无法匹配 bound callable
if btn.pressed.is_connected(_on_unequip):
    btn.pressed.disconnect(_on_unequip)

# 新: 遍历所有连接后断开
for conn in btn.pressed.get_connections():
    btn.pressed.disconnect(conn.callable)
```

---

## 遗留问题

| 严重度 | 问题 | 说明 |
|:------:|------|------|
| 🔴 高 | total_pulls 存错列 | 仍存于 equipments JSONB，需独立列 |
| 🔴 高 | 无数据库事务 | equip/decompose/chest/stage 需事务保护 |
| 🟡 中 | 排行榜分数简化 | 缺时间加权 |
| 🟡 中 | 无Redis排行榜元数据 | PostgreSQL直查 |
| 🟡 中 | 技能槽重复装备未检查 | — |
| 🟢 低 | 多个未使用错误码 | 需补充逻辑 |

---

## 构建状态

- Go server: ✅ 编译通过 (`go build ./cmd/server/`)
- Godot client: 需在 Godot 编辑器中验证
