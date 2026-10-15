extends RefCounted
## 成长系统：每人独立经验/等级 → 各自升级抽卡。主机唯一裁决。
## 全部静态纯函数，无实例状态。

const Combat := preload("res://sim/combat.gd")
const Weapons := preload("res://sim/weapons.gd")

## 卡池：共 30 张升级卡。
## id 1-7 属性叠加卡，8-16 新武器卡，17-22 组合技触发卡，23-30 被动特效卡。
const CARDS: Array = [
	# ── 属性卡（id 1-7） ──
	{"id": 1,  "name": "+4 伤害",       "damage_add": 4},
	{"id": 2,  "name": "最大 HP +25",   "max_hp_add": 25},
	{"id": 3,  "name": "移速 +10%",     "move_speed_scale": 1.1},
	{"id": 4,  "name": "暴击率 +5%",    "crit_chance_add": 0.05},
	{"id": 5,  "name": "暴击伤害 +20%", "crit_mul_scale": 1.2},
	{"id": 6,  "name": "吸血 +2",       "lifesteal_add": 2},
	{"id": 7,  "name": "冷却 -8%",      "cooldown_scale": 0.92},

	# ── 新武器卡（id 8-16） ──
	{"id": 8,  "name": "新武器: 霰弹枪",  "weapon_add": Weapons.KIND_SHOTGUN},
	{"id": 9,  "name": "新武器: 环形炮",  "weapon_add": Weapons.KIND_RING},
	{"id": 10, "name": "新武器: 激光束",  "weapon_add": Weapons.KIND_LASER},
	{"id": 11, "name": "新武器: 导弹",    "weapon_add": Weapons.KIND_MISSILE},
	{"id": 12, "name": "新武器: 地雷",    "weapon_add": Weapons.KIND_MINE},
	{"id": 13, "name": "新武器: 冰霜",    "weapon_add": Weapons.KIND_FROST},
	{"id": 14, "name": "新武器: 闪电链",  "weapon_add": Weapons.KIND_LIGHTNING},
	{"id": 15, "name": "新武器: 旋转尖刺","weapon_add": Weapons.KIND_SPIKES},
	{"id": 16, "name": "新武器: 步枪",    "weapon_add": Weapons.KIND_RIFLE},

	# ── 组合技触发卡（id 17-22，需先持有相关武器） ──
	{"id": 17, "name": "黑洞",          "combo": Weapons.COMBO_BLACKHOLE},
	{"id": 18, "name": "陨石雨",        "combo": Weapons.COMBO_METEOR_SHOWER},
	{"id": 19, "name": "冰风暴",        "combo": Weapons.COMBO_ICE_STORM},
	{"id": 20, "name": "雷霆风暴",      "combo": Weapons.COMBO_THUNDER_STORM},
	{"id": 21, "name": "风火轮",        "combo": Weapons.COMBO_WHIRLWIND},
	{"id": 22, "name": "天罚",          "combo": Weapons.COMBO_JUDGMENT},

	# ── 被动特效卡（id 23-30） ──
	{"id": 23, "name": "穿透弹",        "combo": Weapons.COMBO_PIERCING},
	{"id": 24, "name": "爆破弹",        "combo": Weapons.COMBO_EXPLOSIVE},
	{"id": 25, "name": "时间凝滞",      "combo": Weapons.COMBO_TIME_WARP},
	{"id": 26, "name": "绝对零度",      "combo": Weapons.COMBO_ABSOLUTE_ZERO},
	{"id": 27, "name": "散射 +1",       "extra_projectiles": 1},
	{"id": 28, "name": "磁力范围 +30%", "magnet_radius_scale": 1.3},
	{"id": 29, "name": "拾取范围 +20%", "pickup_radius_scale": 1.2},
	{"id": 30, "name": "回春 +3 HP/级", "heal_per_level": 3},
]


static func xp_to_next(level: int) -> int:
	return 10 + (maxi(level, 1) - 1) * 8


static func default_modifiers() -> Dictionary:
	return {
		"damage_add": 0,
		"cooldown_scale": 1.0,
		"max_hp_add": 0,
		"extra_projectiles": 0,
		"lifesteal_add": 0,
		"move_speed_scale": 1.0,
		"crit_chance_add": 0.0,
		"crit_mul_scale": 1.0,
		"magnet_radius_scale": 1.0,
		"pickup_radius_scale": 1.0,
		"pickup_add": 0,
		"heal_per_level": 0,
	}


static func card_by_id(id: int) -> Dictionary:
	for c in CARDS:
		if c["id"] == id:
			return c
	return {}


static func apply_card(mods: Dictionary, card: Dictionary) -> Dictionary:
	var out := mods.duplicate()
	for k in card.keys():
		if k == "id" or k == "name" or k == "weapon_add" or k == "combo":
			continue
		if k == "cooldown_scale" or k == "move_speed_scale" or k == "crit_mul_scale" \
		or k == "magnet_radius_scale" or k == "pickup_radius_scale":
			out[k] = float(out.get(k, 1.0)) * float(card[k])
		else:
			out[k] = int(out.get(k, 0)) + int(card[k])
	return out


static func draw_choices(rng: RandomNumberGenerator, count: int = 3) -> Array:
	var idx: Array = []
	for i in CARDS.size():
		idx.append(i)
	for i in range(idx.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = idx[i]
		idx[i] = idx[j]
		idx[j] = tmp
	var out: Array = []
	for i in mini(count, idx.size()):
		out.append(int(CARDS[idx[i]]["id"]))
	return out


static func max_hp(mods: Dictionary) -> int:
	return Combat.PLAYER_MAX_HP + int(mods.get("max_hp_add", 0))
