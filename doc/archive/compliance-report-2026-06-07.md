# 前后端设计合规报告

> 日期: 2026-06-07 | 基准: `doc/detailed-design.md` + `doc/superpowers/specs/2026-06-07-main-ui-redesign.md`

---

## 一、前端合规状态

### UI布局规范 — 19/19 通过 (100%)

| # | 规范项 | 状态 |
|---|--------|:----:|
| 1 | 垂直堆叠布局（非TabContainer） | ✅ |
| 2 | HUD区域（Lv/EXP/💰/🎫/CP） | ✅ |
| 3 | 战斗区域含章节标签 | ✅ |
| 4 | 关卡名居中显示 | ✅ |
| 5 | 5技能槽，槽位0固定🔥 | ✅ |
| 6 | 装备区10格5×2网格 | ✅ |
| 7 | 开箱区：计数/等级/开箱/升级 | ✅ |
| 8 | 底部按钮行3个按钮 | ✅ |
| 9 | 技能仓库模式：战斗可见、装备/开箱隐藏 | ✅ |
| 10 | 商店模式：全部隐藏 | ✅ |
| 11 | 排行榜侧滑面板（AnimationPlayer） | ✅ |
| 12 | 开箱装备对比弹窗 | ✅ |
| 13 | 技能仓库6列网格 | ✅ |
| 14 | 商店2列网格 | ✅ |
| 15 | 排行榜含章节切换+加载更多+我的排名 | ✅ |
| 16 | 已移除TabContainer/BottomNav | ✅ |
| 17 | 独立抽卡按钮已移至商店 | ⚠️ 部分（独立场景仍存在） |
| 18 | NORMAL↔NORMAL切换 | ✅ |
| 19 | 按钮模式高亮 | ✅ |

### 前端日志覆盖 — 54/57 (95%)

- ✅ 所有按钮和交互处理器已添加 `[UI]` 格式化日志
- ✅ 日志格式统一：`print("[UI] action=ACTION_NAME key=value")`
- 例外：`battle_simulator.gd` 为纯模拟引擎，无可交互元素

### 已知前端问题

| 严重度 | 问题 | 位置 |
|:------:|------|------|
| 🔴 中 | 信号连接泄漏：`equipment_area.gd:_refresh()` 重复绑定向 | `client/scenes/main/equipment_area.gd:23` |
| 🟡 中 | 战斗区技能槽1-4无可点击交互 | `client/scenes/main/battle_area.gd` |
| 🟢 低 | 独立场景日志缺失（已修复） | 4个独立场景 |
| 🟢 低 | `equipment_ui.gd` 死代码（未连接的handler） | `_on_inventory_selected`, `_on_equip` |
| 🟢 低 | 重复Mode枚举定义（`main_ui.gd` + `bottom_button_row.gd`） | 两处定义 |

---

## 二、后端合规状态

### API端点覆盖 — 27/27 实现 (100%)

所有设计文档指定的API端点均已实现。额外端点：`GET /api/skill/slots`，`GET /api/stage/config`。

### 中间件覆盖

| 中间件 | 状态 | 说明 |
|--------|:----:|------|
| JWT鉴权 | ✅ | 全局应用，白名单跳过auth路由 |
| CORS | ✅ | 允许所有源（需生产加固） |
| Recovery | ✅ | 捕获panic返回500 |
| 请求日志 | ✅ | `[REQ]`/`[RES]`格式含request_id |
| 限流 | ❌ | 设计文档要求但未实现 |
| 请求大小限制 | ❌ | 未配置 |

### 后端关键问题

| 严重度 | 问题 | 描述 |
|:------:|------|------|
| 🔴 致命 | skills JSONB格式不匹配 | 迁移初始化 `[]` 但代码解析为 `map`，首次抽卡可能panic |
| 🔴 致命 | skill_slots JSONB格式不匹配 | 迁移初始化 `{object}` 但代码解析为 `[array]` |
| 🔴 致命 | 战斗服务未接入 | `battleSvc` 创建但丢弃（`_ = battleSvc`），WebSocket仅echo |
| 🔴 高 | total_pulls存错列 | 存于 `equipments` JSONB而非独立字段 |
| 🔴 高 | 无数据库事务 | 装备/分解/开箱/关卡操作无事务保护，存在并发丢失更新 |
| 🔴 高 | 关卡奖励含金币 | 设计文档明确无金币，但 `CalculateRewards` 返回金币 |
| 🟡 中 | 排行榜分数公式简化 | 缺时间加权（`chapter×10000+level+time` → `chapter×1000+level`） |
| 🟡 中 | 无Redis排行榜元数据 | 设计文档要求存nickname/level/CP于Redis hash |
| 🟡 中 | 技能槽重复装备未检查 | 同一技能可装备到多个槽位 |
| 🟡 中 | 货币流水错误静默丢弃 | `_ = InsertCurrencyLog` 无日志 |
| 🟢 低 | 未使用的错误码 | 10004/10007/10010/10014/40002等定义但从未使用 |
| 🟢 低 | Auth白名单精确匹配 | 尾部斜杠变体可能绕过鉴权 |
| 🟢 低 | 响应缺字段 | progress缺 `next_stage_id`、ShopInfo/ChestInfo缺quality信息 |
| 🟢 低 | healthz无日志 | 无请求日志输出 |

### 数据库Schema对比

| 设计表 | 实现 | 差异 |
|--------|------|------|
| equipment_inventory | characters JSONB | 扁平化到角色行 |
| skill_inventory | characters JSONB | 扁平化到角色行 |
| chest_inventory | characters columns | 简化（chest_count/zone_level） |
| stage_progress | characters columns | 简化（stage_chapter/stage_level） |
| skill_definitions | Go硬编码 | 不在数据库中 |
| stage_configs | Go过程生成 | 不在数据库中 |
| battle_anomalies | ❌ 未实现 | 缺少异常记录表 |

---

## 三、建议优先级

### 立即修复（阻塞性）
1. 修复skills/skill_slots JSONB格式不匹配 — 会导致新角色数据损坏
2. 接入战斗服务（Plan A + Plan B）— 核心防作弊机制缺失
3. 添加数据库事务 — 并发安全

### 短期修复（1-2周）
4. 修复关卡奖励金币问题
5. 添加限流中间件
6. 补充缺失API响应字段
7. 修复前端信号连接泄漏

### 中期优化
8. 排行榜公式对齐设计文档
9. Redis排行榜元数据缓存
10. 补全未使用错误码的逻辑
