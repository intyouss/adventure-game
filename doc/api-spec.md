# API 接口文档

> 基础地址: `http://{host}:{port}`  
> 所有接口返回统一格式: `{"code": 0, "msg": "ok", "data": ...}`  
> 所有需要鉴权的接口（除 `/api/auth/*` 和 `/healthz`）均需在 Header 中携带 `Authorization: Bearer {access_token}`

---

## 通用说明

### 请求规范
- **Content-Type**: `application/json`
- **认证方式**: JWT Bearer Token，登录成功后获取 `access_token`
- **身份传递**: 鉴权中间件自动从 JWT 中提取 `account_id` 和 `character_id` 注入请求上下文

### 响应格式

```json
{
  "code": 0,        // 0=成功, 负数为通用错误, 其他为业务错误码
  "msg": "ok",      // 错误时包含具体错误描述
  "data": {}        // 成功时携带业务数据
}
```

### 错误码速查

| 错误码 | 含义 |
|--------|------|
| -1 | 服务器内部错误 |
| 10001-10015 | 通用/账号类错误 |
| 30001-30005 | 装备相关错误 |
| 40001-40006 | 技能相关错误 |
| 50001-50003 | 宝箱相关错误 |
| 60001-60002 | 关卡相关错误 |
| 70001-70003 | 战斗相关错误 |

---

## 1. 健康检查

### GET /healthz

> 无需认证

**请求参数**: 无

**响应示例**:
```json
{
  "code": 0,
  "msg": "ok",
  "data": { "status": "healthy" }
}
```

**错误响应**:
```json
{
  "code": -1,
  "msg": "database unavailable"
}
```

---

## 2. 账号认证

### 2.1 POST /api/auth/send_code

> 发送短信/邮箱验证码

**请求体**:
| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| phone | string | 二选一 | 手机号 |
| email | string | 二选一 | 邮箱地址 |

**请求示例**:
```json
{
  "phone": "13800138000"
}
```

**响应**:
```json
{
  "code": 0,
  "msg": "ok",
  "data": null
}
```

**错误码**: `10001`, `10002`, `-1`

---

### 2.2 POST /api/auth/register

> 注册新账号并创建角色

**请求体**:
| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| phone | string | 二选一 | 手机号 |
| email | string | 二选一 | 邮箱地址 |
| password | string | 是 | 密码，6-32字符 |
| code | string | 是 | 短信/邮箱验证码 |
| nickname | string | 否 | 昵称，2-12字符 |

**请求示例**:
```json
{
  "phone": "13800138000",
  "password": "mypassword123",
  "code": "654321",
  "nickname": "勇者"
}
```

**响应**:
```json
{
  "code": 0,
  "msg": "ok",
  "data": {
    "access_token": "eyJhbGciOi...",
    "refresh_token": "r_abc123...",
    "expires_in": 3600,
    "account_id": 1,
    "character_id": 1
  }
}
```

**错误码**: `10004`(密码格式错误), `10005`(已注册), `10006`(验证码错误), `10007`(昵称无效), `10003`, `-1`

---

### 2.3 POST /api/auth/login

> 账号登录

**请求体**:
| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| account | string | 是 | 手机号或邮箱 |
| password | string | 否 | 密码，与验证码二选一 |
| code | string | 否 | 验证码，与密码二选一 |

**请求示例**:
```json
{
  "account": "13800138000",
  "password": "mypassword123"
}
```

**响应**: 同注册接口，返回 `TokenPair`

**错误码**: `10008`(账号不存在), `10009`(密码错误), `10006`(验证码错误), `-1`

---

### 2.4 POST /api/auth/refresh

> 刷新 Access Token

> 无需 JWT 认证

**请求体**:
| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| refresh_token | string | 是 | 之前获取的 refresh_token |

**请求示例**:
```json
{
  "refresh_token": "r_abc123..."
}
```

**响应**: 返回新的 `TokenPair`

**错误码**: `10011`(无效token), `10012`(token过期), `-1`

---

## 3. 角色

### 3.1 GET /api/character

> 获取当前角色信息

**请求参数**: 无

**响应**:
```json
{
  "code": 0,
  "msg": "ok",
  "data": {
    "id": 1,
    "account_id": 1,
    "class": "warrior",
    "nickname": "勇者",
    "level": 5,
    "exp": 450,
    "exp_to_next": 200,
    "gold": 1000,
    "skill_tickets": 10,
    "stats": {
      "atk": 25,
      "def": 10,
      "hp": 200,
      "crit_rate": 0.05,
      "crit_dmg": 1.5,
      "atk_speed": 1.0
    },
    "cp": 135.0
  }
}
```

**字段说明**:
| 字段 | 类型 | 说明 |
|------|------|------|
| id | int64 | 角色ID |
| class | string | 职业（当前仅 warrior） |
| level | int | 等级 |
| exp | int64 | 当前经验值 |
| exp_to_next | int64 | 距离下一级所需经验 |
| gold | int64 | 金币数量 |
| skill_tickets | int64 | 技能券数量 |
| stats.atk | int | 物理攻击力 |
| stats.def | int | 物理防御力 |
| stats.hp | int | 生命值 |
| stats.crit_rate | float | 暴击率 |
| stats.crit_dmg | float | 暴击伤害倍率 |
| stats.atk_speed | float | 攻击速度 |
| cp | float | 战斗力 |

---

### 3.2 POST /api/character/add_exp

> 增加角色经验值

**请求体**:
| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| exp | int64 | 是 | 增加的经验值 |

**请求示例**:
```json
{
  "exp": 500
}
```

**响应**: 返回更新后的 `CharacterResponse`

---

## 4. 装备

### 4.1 GET /api/equipment/inventory

> 获取装备背包和已装备列表

**请求参数**: 无

**响应**:
```json
{
  "code": 0,
  "msg": "ok",
  "data": {
    "items": [
      {
        "uid": "e-001",
        "name": "铁剑",
        "slot": "weapon",
        "quality": 2,
        "level": 1,
        "stats": { "atk": 15, "def": 0, "hp": 0, "crit_rate": 0, "crit_dmg": 0, "atk_speed": 0 }
      }
    ],
    "equipped": {
      "weapon": { "uid": "e-001", ... },
      "helmet": null,
      "armor": null,
      "boots": null,
      "accessory": null
    }
  }
}
```

---

### 4.2 POST /api/equipment/equip

> 装备物品

**请求体**:
| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| item_uid | string | 是 | 装备唯一ID |
| slot | string | 是 | 目标槽位: weapon/helmet/armor/boots/accessory |

**请求示例**:
```json
{
  "item_uid": "e-001",
  "slot": "weapon"
}
```

**响应**: `data` 为 null

**错误码**: `30001`(装备不存在), `30002`(槽位不匹配), `30003`(槽位已占用)

---

### 4.3 POST /api/equipment/unequip

> 卸下装备

**请求体**:
| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| slot | string | 是 | 槽位: weapon/helmet/armor/boots/accessory |

**响应**: `data` 为 null

---

### 4.4 POST /api/equipment/decompose

> 分解装备获得经验和金币

**请求体**:
| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| item_uids | string[] | 是 | 待分解的装备UID列表 |

**请求示例**:
```json
{
  "item_uids": ["e-001", "e-002"]
}
```

**响应**:
```json
{
  "code": 0,
  "msg": "ok",
  "data": {
    "exp_gained": 120,
    "gold_gained": 50
  }
}
```

**错误码**: `30001`(装备不存在于背包)

---

## 5. 技能

### 5.1 GET /api/skill/list

> 获取所有已拥有技能

**请求参数**: 无

**响应**:
```json
{
  "code": 0,
  "msg": "ok",
  "data": {
    "skills": [
      {
        "id": "s-fireball",
        "name": "火球术",
        "quality": 1,
        "level": 3,
        "cards": 5,
        "coeff": 1.32
      }
    ]
  }
}
```

**字段说明**:
| 字段 | 类型 | 说明 |
|------|------|------|
| id | string | 技能ID |
| name | string | 技能名称 |
| quality | int | 品质，1-5（普通→传说） |
| level | int | 技能等级 |
| cards | int | 持有重复卡片数（用于升级） |
| coeff | float | 技能伤害系数 |

---

### 5.2 GET /api/skill/slots

> 获取技能槽位装备情况

**请求参数**: 无

**响应**:
```json
{
  "code": 0,
  "msg": "ok",
  "data": {
    "equipped": ["s-fireball", null, "s-iceshard", null]
  }
}
```

> `equipped` 为长度为4的数组，`null` 表示空槽位

---

### 5.3 GET /api/skill/shop_info

> 获取技能商店当前状态

**请求参数**: 无

**响应**:
```json
{
  "code": 0,
  "msg": "ok",
  "data": {
    "shop_level": 3,
    "total_pulls": 450,
    "pulls_to_next": 19,
    "active_qualities": [1, 2, 3],
    "probabilities": {
      "quality_1": 47.06,
      "quality_2": 32.94,
      "quality_3": 20.0
    }
  }
}
```

**字段说明**:
| 字段 | 类型 | 说明 |
|------|------|------|
| shop_level | int | 当前商店等级，1-28 |
| total_pulls | int | 累计抽取次数 |
| pulls_to_next | int | 距离下一商店等级还需的抽取次数 |
| active_qualities | int[] | 当前可抽取的品质范围 |
| probabilities | object | 各品质的抽取概率(%) |

---

### 5.4 POST /api/skill/gacha

> 技能抽取（单抽/十连/五十连/百连）

**请求体**:
| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| count | int | 是 | 抽取次数，1-100 |

**请求示例**:
```json
{
  "count": 10
}
```

**响应**:
```json
{
  "code": 0,
  "msg": "ok",
  "data": {
    "results": [
      {
        "id": "s-fireball",
        "name": "火球术",
        "quality": 1,
        "level": 1,
        "cards": 1,
        "coeff": 1.2
      },
      {
        "id": "s-meteor",
        "name": "陨石术",
        "quality": 3,
        "level": 1,
        "cards": 1,
        "coeff": 2.0
      }
    ],
    "skill_tickets_remaining": 90
  }
}
```

**错误码**: `40001`(技能券不足), `40002`(count范围错误)

---

### 5.5 POST /api/skill/equip

> 装备技能到槽位

**请求体**:
| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| skill_id | string | 是 | 技能ID |
| slot | int | 是 | 槽位索引，0-3 |

**请求示例**:
```json
{
  "skill_id": "s-fireball",
  "slot": 0
}
```

**响应**: `data` 为 null

**错误码**: `40004`(槽位已占用/同一技能已在其他槽位)

---

### 5.6 POST /api/skill/upgrade

> 升级单个技能（消耗重复卡片）

**请求体**:
| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| skill_id | string | 是 | 技能ID |

**请求示例**:
```json
{
  "skill_id": "s-fireball"
}
```

**响应**: 返回升级后的 `Skill` 对象

**错误码**: `40003`(技能不存在), `40005`(卡片不足), `40006`(已达最高等级30)

---

### 5.7 POST /api/skill/upgrade_all

> 一键升级所有可升级技能

**请求参数**: 无（空body `{}`）

**响应**:
```json
{
  "code": 0,
  "msg": "ok",
  "data": {
    "skills": {
      "s-fireball": {
        "id": "s-fireball",
        "name": "火球术",
        "quality": 1,
        "level": 5,
        "cards": 0,
        "coeff": 1.44
      }
    }
  }
}
```

---

## 6. 宝箱

### 6.1 GET /api/chest/info

> 获取宝箱区域状态

**请求参数**: 无

**响应**:
```json
{
  "code": 0,
  "msg": "ok",
  "data": {
    "chest_count": 10,
    "zone_level": 3,
    "upgrade_cost": 500
  }
}
```

---

### 6.2 POST /api/chest/open

> 开启宝箱获取装备

**请求体**:
| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| count | int | 否 | 开箱数量，默认1 |

**请求示例**:
```json
{
  "count": 5
}
```

**响应**:
```json
{
  "code": 0,
  "msg": "ok",
  "data": {
    "results": [
      {
        "uid": "e-003",
        "name": "铁剑",
        "slot": "weapon",
        "quality": 2,
        "level": 1,
        "stats": { "atk": 15, "def": 0, "hp": 0, "crit_rate": 0, "crit_dmg": 0, "atk_speed": 0 }
      }
    ],
    "chests_remaining": 5
  }
}
```

**错误码**: `50001`(宝箱数量不足)

---

### 6.3 POST /api/chest/upgrade_zone

> 升级宝箱区域（提升产出品质）

**请求参数**: 无（空body `{}`）

**响应**:
```json
{
  "code": 0,
  "msg": "ok",
  "data": {
    "new_zone_level": 4,
    "gold_remaining": 200
  }
}
```

**错误码**: `50002`(金币不足), `50003`(已达最高等级)

---

## 7. 关卡

### 7.1 GET /api/stage/config?chapter=1

> 获取指定章节所有关卡配置

**请求参数**:
| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| chapter | int | 否 | 章节编号，默认1 |

**响应**: 返回 `StageConfig[]` 数组（10个关卡）

```json
{
  "code": 0,
  "msg": "ok",
  "data": [
    {
      "stage_id": "1-1",
      "chapter": 1,
      "level": 1,
      "waves": [
        {
          "is_boss": false,
          "monsters": [
            { "count": 3, "hp": 30, "atk": 5, "def": 2 }
          ]
        },
        {
          "is_boss": true,
          "monsters": [
            { "count": 1, "hp": 150, "atk": 10, "def": 2 }
          ]
        }
      ]
    }
  ]
}
```

**字段说明**:
| 字段 | 类型 | 说明 |
|------|------|------|
| waves | array | 5波怪物配置，第5波为Boss |
| waves[].is_boss | bool | 是否为Boss波 |
| monsters[].count | int | 怪物数量 |
| monsters[].hp | int | 怪物生命值 |
| monsters[].atk | int | 怪物攻击力 |
| monsters[].def | int | 怪物防御力 |

---

### 7.2 GET /api/stage/start?stage_id=1-3

> 获取单个关卡的战斗配置（需已解锁）

**请求参数**:
| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| stage_id | string | 否 | 关卡ID，格式 "章节-关卡"，如 "1-3"，默认 "1-1" |

**响应**: 返回单个 `StageConfig` 对象

**错误码**: `60001`(关卡不存在), `60002`(关卡未解锁)

---

### 7.3 GET /api/stage/progress

> 获取当前关卡进度

**请求参数**: 无

**响应**:
```json
{
  "code": 0,
  "msg": "ok",
  "data": {
    "chapter": 2,
    "level": 5,
    "next_stage_id": "2-6"
  }
}
```

---

### 7.4 POST /api/stage/complete

> 提交关卡通关，领取奖励并推进进度

**请求体**:
| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| stage_id | string | 是 | 通关的关卡ID |

**请求示例**:
```json
{
  "stage_id": "2-5"
}
```

**响应**:
```json
{
  "code": 0,
  "msg": "ok",
  "data": {
    "gold": 100,
    "skill_tickets": 2,
    "chests": 3
  }
}
```

---

## 8. 排行榜

### 8.1 GET /api/leaderboard?page=1&size=50&chapter=0

> 获取排行榜

**请求参数**:
| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| page | int | 否 | 页码，默认1 |
| size | int | 否 | 每页数量，默认50 |
| chapter | int | 否 | 章节筛选，0=全部，默认0 |

**响应**:
```json
{
  "code": 0,
  "msg": "ok",
  "data": {
    "rankings": [
      {
        "rank": 1,
        "character_id": 1,
        "nickname": "勇者",
        "level": 50,
        "cp": 5000.0,
        "stage_chapter": 5,
        "stage_level": 8
      }
    ],
    "total": 100,
    "page": 1,
    "size": 50
  }
}
```

---

### 8.2 GET /api/leaderboard/my_rank

> 获取当前角色的排行榜信息

**请求参数**: 无

**响应**: 返回单个排名条目 `RankEntry`

```json
{
  "code": 0,
  "msg": "ok",
  "data": {
    "rank": 42,
    "character_id": 1,
    "nickname": "勇者",
    "level": 15,
    "cp": 1500.0,
    "stage_chapter": 2,
    "stage_level": 5
  }
}
```

---

## 9. 战斗 WebSocket

### WS /ws/battle

> WebSocket 实时战斗协议  
> 连接时需携带 JWT: `ws://host:port/ws/battle?token={access_token}` 或在 Header 中携带 `Authorization: Bearer {token}`

### 客户端 → 服务端消息

#### 请求关卡配置
```json
{
  "type": "request_stage_config",
  "payload": {
    "stage_id": "1-3"
  }
}
```

#### 提交战斗结果
```json
{
  "type": "battle_summary",
  "payload": {
    "stage_id": "1-3",
    "waves_cleared": 5,
    "total_damage": 1200,
    "total_time_ms": 45000,
    "skills_used": ["s-fireball", "s-iceshard"],
    "character_level": 5,
    "character_stats": {
      "atk": 25, "def": 10, "hp": 200,
      "crit_rate": 0.05, "crit_dmg": 1.5, "atk_speed": 1.0
    }
  }
}
```

| 字段 | 类型 | 说明 |
|------|------|------|
| stage_id | string | 关卡ID |
| waves_cleared | int | 清除的波数 (1-5) |
| total_damage | float | 总造成伤害 |
| total_time_ms | int | 战斗耗时(毫秒) |
| skills_used | string[] | 使用的技能ID列表 |
| character_level | int | 角色等级 |
| character_stats | object | 角色当前属性 |

### 服务端 → 客户端消息

#### 关卡配置下发
```json
{
  "type": "stage_config",
  "payload": { "stage_id": "1-3", "chapter": 1, "level": 3, "waves": [...] }
}
```

#### Plan A 快速验证结果
```json
{
  "type": "plan_a_result",
  "payload": {
    "passed": true,
    "reason": ""
  }
}
```

#### Plan B 服务端模拟结果
```json
{
  "type": "plan_b_result",
  "payload": {
    "passed": true,
    "simulated_dps": 1500.0,
    "expected_damage": 1200.0,
    "rewards": {
      "gold": 100,
      "skill_tickets": 2,
      "chests": 3
    }
  }
}
```

#### 战斗结算（Plan B 通过后）
```json
{
  "type": "battle_settled",
  "payload": {
    "stage_id": "1-3",
    "chapter": 1,
    "level": 3,
    "passed": true,
    "rewards": {
      "gold": 100,
      "skill_tickets": 2,
      "chests": 3
    }
  }
}
```

---

## 附录 A: 技能品质对照

| 品质值 | 名称 | 颜色提示 |
|--------|------|----------|
| 1 | 普通 | 白色 |
| 2 | 优秀 | 绿色 |
| 3 | 稀有 | 蓝色 |
| 4 | 精良 | 紫色 |
| 5 | 传说 | 金色 |

## 附录 B: 商店等级表

| 商店等级 | 累计抽取需求 | 可抽取品质 |
|----------|-------------|------------|
| 1-4 | 0-374 | 普通(70%) + 优秀(30%) |
| 5-8 | 375-584 | +稀有(15%) |
| 9-12 | 585-914 | +精良(10%) |
| 13-28 | 915+ | +传说(10-20%) |

> 商店等级升级公式: `累计抽取 ≥ 300 × 1.25^(N-1)` 时达到等级 N
