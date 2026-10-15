extends RefCounted
## 成长系统纯逻辑测试：经验曲线、卡池、修饰叠加、可复现抽卡。

const Harness := preload("res://tools/tests/harness.gd")
const Progression := preload("res://sim/progression.gd")
const Combat := preload("res://sim/combat.gd")
const Weapons := preload("res://sim/weapons.gd")


func run() -> int:
	var t := Harness.new()

	t.eq(Progression.xp_to_next(1), 10, "1→2 级需 10 点经验")
	t.eq(Progression.xp_to_next(2), 18, "2→3 级需 18 点经验")

	var m := Progression.default_modifiers()
	t.eq(m["damage_add"], 0, "默认无额外伤害")

	# 新卡 ID：1 = +4 伤害
	var m2 := Progression.apply_card(m, Progression.card_by_id(1))
	t.eq(m2["damage_add"], 4, "+4 伤害卡")
	t.eq(m["damage_add"], 0, "apply_card 不修改入参")

	var m3 := Progression.apply_card(m2, Progression.card_by_id(1))
	t.eq(m3["damage_add"], 8, "两张伤害卡叠加为 +8")

	# 新卡 ID：7 = 冷却 -8%
	var m4 := Progression.apply_card(Progression.default_modifiers(), Progression.card_by_id(7))
	t.check(absf(m4["cooldown_scale"] - 0.92) < 0.0001, "冷却卡令冷却 ×0.92")

	t.eq(
		Progression.max_hp(Progression.default_modifiers()),
		Combat.PLAYER_MAX_HP,
		"默认最大血量 = PLAYER_MAX_HP"
	)
	# 新卡 ID：2 = 最大 HP +25
	var m5 := Progression.apply_card(Progression.default_modifiers(), Progression.card_by_id(2))
	t.eq(Progression.max_hp(m5), Combat.PLAYER_MAX_HP + 25, "最大 HP +25 卡")

	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var choices := Progression.draw_choices(rng, 3)
	t.eq(choices.size(), 3, "抽 3 张候选")
	var uniq := {}
	for c in choices:
		uniq[c] = true
	t.eq(uniq.size(), 3, "三张候选互不相同")

	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 7
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 7
	t.eq(Progression.draw_choices(rng_a, 3), Progression.draw_choices(rng_b, 3), "同种子抽卡可复现")

	t.check(Progression.card_by_id(999).is_empty(), "未知卡 id 返回空字典")

	# 新卡 ID：8 = 新武器: 霰弹枪（weapon_add 字段）
	t.check(Progression.card_by_id(8).has("weapon_add"), "武器卡带 weapon_add 字段")

	return t.report("Progression")
