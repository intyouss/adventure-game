# 修复归档报告（第三轮：低优先级）

> 日期: 2026-06-07

---

## 本轮已修复 (4/4)

### 🟢 低: Auth白名单精确匹配 → 前缀匹配

**文件:** `server/internal/middleware/auth.go`

`c.Request.URL.Path` → `strings.TrimRight(path, "/")` 处理尾部斜杠变体（如 `/healthz/`）

---

### 🟢 低: 未使用的错误码 → 已使用

**文件:**
- `server/internal/handler/account_handler.go` — `ErrInvalidPassword` (10004) 密码6-32位校验 + `ErrNicknameInvalid` (10007) 昵称2-12位校验
- `server/internal/handler/skill_handler.go` — `ErrInvalidCount` (40002) 抽卡次数1-10校验
- `server/internal/handler/stage_handler.go` — `ErrStageNotFound` (60001) 区分未解锁/未找到

---

### 🟢 低: 响应缺字段 → 已补充

**文件:**
- `server/internal/service/stage_svc.go` — `GetProgress()` 新增 `next_stage_id`
- `server/internal/service/skill_svc.go` — `ShopInfo()` 新增 `active_qualities` + `probabilities`
- `server/internal/service/chest_svc.go` — `GetChestInfo()` 新增 `active_qualities`

---

### 🟢 低: healthz无日志 → 已添加

**文件:** `server/cmd/server/main.go`

DB/Redis ping 失败记录 `slog.Warn`。

---

## 构建状态

- Go server: ✅ `go build ./cmd/server/` 通过

## 三轮修复总计

| 轮次 | 修复数 | 严重度覆盖 |
|:----:|:------:|-----------|
| R1 | 4 | 致命 3 + 高 1 |
| R2 | 6 | 高 2 + 中 4 |
| R3 | 4 | 低 4 |
| **合计** | **14** | **全部严重度** |
