# PVP APL 文件目录

本目录包含 PVP 专用的 APL（技能优先级列表）文件。

## 文件命名规范

PVP APL 文件应遵循以下命名规范：
- `{Class}{Spec}PVP.simc` - 例如：`RogueAssassinationPVP.simc`

## PVP 特定条件

PVP APL 支持以下特定条件：

### 环境条件
- `pvp_mode` - 当前 PVP 模式 ("arena", "battleground", "world_pvp")
- `pvp_mode.arena` - 是否在竞技场
- `pvp_mode.battleground` - 是否在战场
- `pvp_mode.world_pvp` - 是否在野外 PVP

### 敌方状态条件
- `enemy_burst_active` - 敌方是否在爆发
- `threat_level` - 当前威胁等级 (0-100)

### 目标条件
- `target.is_player` - 目标是否为玩家
- `target.is_healer` - 目标是否为治疗职业
- `target.has_defensive` - 目标是否有防守技能激活
- `target.dr_stun` - 目标眩晕 DR 等级 (0-3)
- `target.dr_silence` - 目标沉默 DR 等级 (0-3)

## 示例

```simc
## 当敌方爆发时优先使用防守技能
actions+=/cloak_of_shadows,if=enemy_burst_active&health.pct<70

## 对治疗职业优先使用打断
actions+=/kick,if=target.is_healer&target.casting

## 根据 DR 状态选择控制技能
actions+=/kidney_shot,if=target.dr_stun<3&combo_points>=4
```

## 回退机制

如果当前专精没有对应的 PVP APL 文件，系统将自动回退到默认的 PVE APL。
