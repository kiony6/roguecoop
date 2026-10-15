extends RefCounted
## 武器纯逻辑：全 9 种武器 + 22 组合技。
## 全部静态纯函数，无实例状态。

const KIND_PISTOL := 0
const KIND_RIFLE := 1
const KIND_SHOTGUN := 2
const KIND_RING := 3
const KIND_LASER := 4
const KIND_MISSILE := 5
const KIND_MINE := 6
const KIND_FROST := 7
const KIND_LIGHTNING := 8
const KIND_SPIKES := 9

const MAX_PROJECTILES := 128

const KINDS: Array = [
	{"id": 0,  "name": "手枪",   "cooldown": 0.4,  "damage": 12, "projectiles": 1, "spread": 0.0,  "speed": 500.0, "ttl": 1.5, "radius": 8.0,  "tracked": false, "big": false, "freeze": 0.0},
	{"id": 1,  "name": "步枪",   "cooldown": 0.22, "damage": 9,  "projectiles": 1, "spread": 0.03, "speed": 760.0, "ttl": 1.2, "radius": 6.0,  "tracked": false, "big": false, "freeze": 0.0},
	{"id": 2,  "name": "霰弹枪", "cooldown": 0.9,  "damage": 8,  "projectiles": 5, "spread": 0.35, "speed": 400.0, "ttl": 0.6, "radius": 7.0,  "tracked": false, "big": false, "freeze": 0.0},
	{"id": 3,  "name": "环形炮", "cooldown": 1.2,  "damage": 6,  "projectiles": 8, "spread": 0.79, "speed": 200.0, "ttl": 1.0, "radius": 5.0,  "tracked": false, "big": false, "freeze": 0.0},
	{"id": 4,  "name": "激光束", "cooldown": 2.0,  "damage": 30, "projectiles": 1, "spread": 0.0,  "speed": 800.0, "ttl": 0.4, "radius": 10.0, "tracked": false, "big": true,  "freeze": 0.0},
	{"id": 5,  "name": "导弹",   "cooldown": 2.5,  "damage": 25, "projectiles": 1, "spread": 0.0,  "speed": 300.0, "ttl": 2.0, "radius": 10.0, "tracked": true,  "big": true,  "freeze": 0.0},
	{"id": 6,  "name": "地雷",   "cooldown": 3.0,  "damage": 40, "projectiles": 1, "spread": 0.0,  "speed": 0.0,   "ttl": 30.0,"radius": 14.0, "tracked": false, "big": true,  "freeze": 0.0},
	{"id": 7,  "name": "冰霜",   "cooldown": 0.8,  "damage": 5,  "projectiles": 1, "spread": 0.05, "speed": 350.0, "ttl": 1.2, "radius": 7.0,  "tracked": false, "big": false, "freeze": 1.5},
	{"id": 8,  "name": "闪电链", "cooldown": 0.7,  "damage": 15, "projectiles": 1, "spread": 0.02, "speed": 600.0, "ttl": 0.8, "radius": 6.0,  "tracked": false, "big": false, "freeze": 0.0},
	{"id": 9,  "name": "旋转尖刺","cooldown": 0.5,  "damage": 8,  "projectiles": 3, "spread": 0.5,  "speed": 360.0, "ttl": 0.7, "radius": 6.0,  "tracked": false, "big": false, "freeze": 0.0},
]

# ── 22 组合技 ──
const COMBO_NONE := ""
const COMBO_TWIN_PISTOL := "twin_pistol"
const COMBO_RAPID_FIRE := "rapid_fire"
const COMBO_TRACK_MISSILE := "track_missile"
const COMBO_FROST_NOVA := "frost_nova"
const COMBO_THUNDER_RING := "thunder_ring"
const COMBO_TRI_LASER := "tri_laser"
const COMBO_MINE_FIELD := "mine_field"
const COMBO_CONDUCTOR := "conductor"
const COMBO_ICE_STORM := "ice_storm"
const COMBO_METEOR_SHOWER := "meteor_shower"
const COMBO_BLACKHOLE := "blackhole"
const COMBO_TIME_WARP := "time_warp"
const COMBO_FROST_MINE := "frost_mine"
const COMBO_PIERCING := "piercing"
const COMBO_EXPLOSIVE := "explosive"
const COMBO_SPIN_FROST := "spin_frost"
const COMBO_THUNDER_STORM := "thunder_storm"
const COMBO_WHIRLWIND := "whirlwind"
const COMBO_LASER_RAIN := "laser_rain"
const COMBO_OVERCLOCK := "overclock"
const COMBO_ABSOLUTE_ZERO := "absolute_zero"
const COMBO_JUDGMENT := "judgment"

const COMBOS: Array = [
	{"id": COMBO_TWIN_PISTOL,  "name": "双持手枪",   "req": [KIND_PISTOL, KIND_SHOTGUN]},
	{"id": COMBO_RAPID_FIRE,   "name": "急速射击",    "req": [KIND_PISTOL, KIND_FROST]},
	{"id": COMBO_TRACK_MISSILE,"name": "追踪导弹",    "req": [KIND_PISTOL, KIND_MISSILE]},
	{"id": COMBO_FROST_NOVA,   "name": "冰霜新星",    "req": [KIND_FROST, KIND_RING]},
	{"id": COMBO_THUNDER_RING, "name": "雷霆之环",    "req": [KIND_LIGHTNING, KIND_RING]},
	{"id": COMBO_TRI_LASER,    "name": "三重激光",    "req": [KIND_LASER, KIND_SPIKES]},
	{"id": COMBO_MINE_FIELD,   "name": "地雷阵",      "req": [KIND_MINE, KIND_FROST]},
	{"id": COMBO_CONDUCTOR,    "name": "传导弹",      "req": [KIND_LIGHTNING, KIND_MISSILE]},
	{"id": COMBO_ICE_STORM,    "name": "冰风暴",      "req": [KIND_FROST, KIND_SHOTGUN]},
	{"id": COMBO_METEOR_SHOWER,"name": "陨石雨",      "req": [KIND_MISSILE, KIND_LIGHTNING]},
	{"id": COMBO_BLACKHOLE,    "name": "黑洞",        "req": [KIND_LASER, KIND_MINE]},
	{"id": COMBO_TIME_WARP,    "name": "时间凝滞",    "req": [KIND_LASER, KIND_LIGHTNING]},
	{"id": COMBO_FROST_MINE,   "name": "冰冻地雷",    "req": [KIND_FROST, KIND_MINE]},
	{"id": COMBO_PIERCING,     "name": "穿透弹",      "req": [KIND_PISTOL, KIND_LASER]},
	{"id": COMBO_EXPLOSIVE,    "name": "爆破弹",      "req": [KIND_SHOTGUN, KIND_MISSILE]},
	{"id": COMBO_SPIN_FROST,   "name": "冰霜旋转",    "req": [KIND_SPIKES, KIND_FROST]},
	{"id": COMBO_THUNDER_STORM,"name": "雷霆风暴",    "req": [KIND_LIGHTNING, KIND_SHOTGUN]},
	{"id": COMBO_WHIRLWIND,    "name": "风火轮",      "req": [KIND_RING, KIND_LASER, KIND_LIGHTNING]},
	{"id": COMBO_LASER_RAIN,   "name": "激光雨",      "req": [KIND_LASER, KIND_LIGHTNING, KIND_RING]},
	{"id": COMBO_OVERCLOCK,    "name": "超频秒杀",    "req": [KIND_PISTOL, KIND_SHOTGUN, KIND_MISSILE]},
	{"id": COMBO_ABSOLUTE_ZERO,"name": "绝对零度",    "req": [KIND_FROST, KIND_MINE, KIND_SPIKES]},
	{"id": COMBO_JUDGMENT,     "name": "天罚",        "req": [KIND_LIGHTNING, KIND_MISSILE, KIND_FROST]},
]


static func default_id() -> int:
	return KIND_PISTOL


static func count() -> int:
	return KINDS.size()


static func by_id(id: int) -> Dictionary:
	for w in KINDS:
		if w["id"] == id:
			return w
	return KINDS[0]


static func name_of(id: int) -> String:
	return str(by_id(id)["name"])


static func cooldown(id: int, mods: Dictionary) -> float:
	return float(by_id(id)["cooldown"]) * float(mods.get("cooldown_scale", 1.0))


static func damage(id: int, mods: Dictionary) -> int:
	return int(by_id(id)["damage"]) + int(mods.get("damage_add", 0))


static func projectile_count(id: int, mods: Dictionary) -> int:
	return int(by_id(id)["projectiles"]) + int(mods.get("extra_projectiles", 0))


static func spread(id: int) -> float:
	return float(by_id(id)["spread"])


static func speed(id: int) -> float:
	return float(by_id(id)["speed"])


static func ttl(id: int) -> float:
	return float(by_id(id)["ttl"])


static func radius(id: int) -> float:
	return float(by_id(id)["radius"])


static func reach(id: int) -> float:
	return speed(id) * ttl(id)


static func is_tracked(id: int) -> bool:
	return bool(by_id(id).get("tracked", false))


static func is_big(id: int) -> bool:
	return bool(by_id(id).get("big", false))


static func freeze_time(id: int) -> float:
	return float(by_id(id).get("freeze", 0.0))


static func has_combo(weapons: Array, combo_id: String) -> bool:
	for c in COMBOS:
		if c["id"] == combo_id:
			for req in c["req"]:
				if not (req in weapons):
					return false
			return true
	return false


static func active_combos(weapons: Array) -> Array:
	var out: Array = []
	for c in COMBOS:
		var ok := true
		for req in c["req"]:
			if not (req in weapons):
				ok = false
				break
		if ok:
			out.append(c["id"])
	return out
