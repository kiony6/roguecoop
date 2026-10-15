extends RefCounted
## 主机权威模拟（纯逻辑，不含传输）。由 autoload Net 驱动。
## M3：在 M2 战斗之上叠加每人独立经验与等级+每人独立选卡、倒地/救援/阵亡、Boss 与结算判定。

const Movement := preload("res://sim/movement.gd")
const Combat := preload("res://sim/combat.gd")
const EnemyAI := preload("res://sim/enemy_ai.gd")
const Progression := preload("res://sim/progression.gd")
const Weapons := preload("res://sim/weapons.gd")
const Rooms := preload("res://sim/rooms.gd")
const Waves := preload("res://sim/waves.gd")

var tick := 0
var snapshot_count := 0
var local_move := Vector2.ZERO
var local_buttons := 0
var spawn_interval := Waves.spawn_interval(1)
var wave := 1
var room_walls: Array = []

# —— 队伍成长与结算 ——
var kills := 0
var boss_kills := 0
var elapsed := 0.0
var run_over := false
var won := false
var boss_id := 0
var enemy_fire_enabled := true  # 测试时可关闭敌人远程攻击

var players := {}  # id -> {pos, move, buttons, hp, status, fire_cd, invuln,
# revive_progress, pickups, mods, level, xp}
var enemies := {}  # id -> {pos, hp, kind, touch_cd}
var loot := {}  # id -> {pos, kind, owner, ttl}
var projectiles := {}  # id -> {pos, vel, ttl, dmg, owner}

var _next_id := 1
var _spawn_accum := 0.0
var _next_boss_at := Combat.BOSS_EVERY_KILLS
var _offer := {}  # id -> Array[card_id]，本升级的候选卡
var _offer_sent := {}  # id -> bool，候选是否已下发
var _rng := RandomNumberGenerator.new()


func reset(dedicated: bool = false) -> void:
	tick = 0
	snapshot_count = 0
	local_move = Vector2.ZERO
	local_buttons = 0
	spawn_interval = Waves.spawn_interval(1)
	wave = 1
	room_walls = Rooms.generate(20261015)
	kills = 0
	boss_kills = 0
	elapsed = 0.0
	run_over = false
	won = false
	boss_id = 0
	players = {} if dedicated else {1: _new_player()}
	enemies = {}
	loot = {}
	projectiles = {}
	_next_id = 1
	_spawn_accum = 0.0
	_next_boss_at = Combat.BOSS_EVERY_KILLS
	_offer = {}
	_offer_sent = {}
	_rng.seed = 20261015


func add_player(id: int) -> void:
	players[id] = _new_player()


func remove_player(id: int) -> void:
	players.erase(id)
	_offer.erase(id)
	_offer_sent.erase(id)


func has_player(id: int) -> bool:
	return players.has(id)


func set_remote_input(id: int, move: Vector2, buttons: int) -> void:
	if players.has(id):
		players[id]["move"] = move
		players[id]["buttons"] = buttons


func spawn_enemy(pos: Vector2, kind: int = Combat.ENEMY_KIND_NORMAL) -> int:
	var eid := _alloc_id()
	var full := Waves.enemy_hp(kind, wave)
	enemies[eid] = {
		"pos": pos,
		"hp": full,
		"max_hp": full,
		"kind": kind,
		"touch_cd": 0.0,
	}
	return eid


func spawn_boss() -> int:
	var anchor := _random_player_pos()
	var angle := _rng.randf_range(0.0, TAU)
	var at := anchor + Vector2.RIGHT.rotated(angle) * Combat.SPAWN_RADIUS
	var eid := spawn_enemy(Rooms.clamp_inside(at, Combat.BOSS_RADIUS), Combat.ENEMY_KIND_BOSS)
	boss_id = eid
	return eid


func physics_step(delta: float) -> void:
	if run_over:
		return
	tick += 1
	elapsed += delta
	var w := Waves.wave_index(elapsed)
	if w != wave:
		wave = w
		spawn_interval = Waves.spawn_interval(w)
	if players.has(1):
		players[1]["move"] = local_move
		players[1]["buttons"] = local_buttons
	_step_players(delta)
	_step_firing()
	_step_combos(delta)         # 组合技触发
	_step_enemy_firing(delta)   # 敌人远程攻击
	_step_projectiles(delta)
	_step_enemies(delta)
	_step_downed(delta)
	_step_loot(delta)
	_step_spawner(delta)
	_check_run_over()


func meta(id: int) -> Dictionary:
	var p: Dictionary = players[id]
	return {
		"level": int(p["level"]),
		"xp": int(p["xp"]),
		"kills": kills,
		"boss_kills": boss_kills,
		"wave": wave,
		"hp": int(p["hp"]),
		"max_hp": Progression.max_hp(p["mods"]),
		"combos": p.get("combos", []),
	}


func stats(id: int) -> Dictionary:
	var p: Dictionary = players[id]
	return {"kills": kills, "level": int(p["level"]), "boss_kills": boss_kills, "seconds": elapsed}


func player_states() -> Array:
	var out: Array = []
	for id in peer_ids():
		var p: Dictionary = players[id]
		(
			out
			. append(
				{
					"id": id,
					"pos": p["pos"],
					"hp": p["hp"],
					"status": p["status"],
					"revive01": _revive01(p),
					"weapon": p["weapon"],
				}
			)
		)
	return out


func enemy_states() -> Array:
	var out: Array = []
	for id in enemies:
		(
			out
			. append(
				{
					"id": id,
					"pos": enemies[id]["pos"],
					"hp01": _hp01(enemies[id]),
					"kind": enemies[id]["kind"],
				}
			)
		)
	return out


func loot_states() -> Array:
	var out: Array = []
	for id in loot:
		out.append({"id": id, "pos": loot[id]["pos"], "kind": loot[id]["kind"]})
	return out


func projectile_states() -> Array:
	var out: Array = []
	for id in projectiles:
		var pr: Dictionary = projectiles[id]
		out.append({"id": id, "pos": pr["pos"], "dir": pr["dir"], "kind": pr["kind"]})
	return out


func peer_ids() -> PackedInt32Array:
	var ids := PackedInt32Array()
	var keys := players.keys()
	keys.sort()
	for k in keys:
		ids.append(int(k))
	return ids


# ---------------- 成长（每人独立经验与等级 + 每人独立选卡） ----------------


func gain_xp(id: int, amount: int) -> int:
	## M4.4：经验记到拾取者本人（每人独立经验）；跨阈值则只给该玩家发一次候选。
	if amount <= 0 or not players.has(id):
		return 0
	var p: Dictionary = players[id]
	p["xp"] = int(p["xp"]) + amount
	var ups := 0
	while int(p["xp"]) >= Progression.xp_to_next(int(p["level"])):
		p["xp"] = int(p["xp"]) - Progression.xp_to_next(int(p["level"]))
		p["level"] = int(p["level"]) + 1
		ups += 1
	if ups > 0:
		_grant_offer(id)
	return ups


func pending_offer(id: int) -> Array:
	## 取「尚未下发」的候选卡并标记为已下发；无候选或已下发返回空。
	if _offer.has(id) and not _offer_sent.get(id, false):
		_offer_sent[id] = true
		return _offer[id]
	return []


func apply_choice(id: int, card_id: int) -> bool:
	## 校验 card_id 是否在本轮候选内；通过则叠加修饰（只作用于该玩家）。
	if not players.has(id) or not _offer.has(id):
		return false
	if not _offer[id].has(card_id):
		return false
	var card := Progression.card_by_id(card_id)
	if card.is_empty():
		return false
	var p: Dictionary = players[id]
	p["mods"] = Progression.apply_card(p["mods"], card)
	if card.has("max_hp_add"):
		p["hp"] = mini(p["hp"] + int(card["max_hp_add"]), Progression.max_hp(p["mods"]))
	if card.has("weapon_set"):
		p["weapon"] = int(card["weapon_set"])
	if card.has("weapon_add"):
		var wid := int(card["weapon_add"])
		if not (wid in p["weapons"]):
			p["weapons"].append(wid)
			p["weapon"] = wid
	if card.has("combo"):
		var cid: String = str(card["combo"])
		if not (cid in p["combos"]):
			p["combos"].append(cid)
	_offer.erase(id)
	_offer_sent.erase(id)
	return true


func _grant_offer(id: int) -> void:
	if not players.has(id) or players[id]["status"] == Combat.PLAYER_DEAD:
		return
	_offer[id] = Progression.draw_choices(_rng, 3)
	_offer_sent[id] = false


# ---------------- 内部步进 ----------------


func _step_players(delta: float) -> void:
	for id in players:
		var p: Dictionary = players[id]
		p["fire_cd"] = maxf(0.0, p["fire_cd"] - delta)
		if p["status"] != Combat.PLAYER_ALIVE:
			continue
		p["pos"] = Movement.step(p["pos"], p["move"], delta, Movement.SPEED, room_walls)


func _step_firing() -> void:
	## M4.4：武器自动攻击——无需按键，最近敌人进入该武器有效射程即开火。
	var targets := _enemy_positions()
	for id in players:
		var p: Dictionary = players[id]
		if p["status"] != Combat.PLAYER_ALIVE:
			continue
		if p["fire_cd"] > 0.0:
			continue
		var nearest := INF
		for t in targets:
			nearest = minf(nearest, p["pos"].distance_to(t["pos"]))
		if nearest > Weapons.reach(int(p["weapon"])):
			continue
		var dir := Combat.aim_dir(p["pos"], targets)
		if dir == Vector2.ZERO:
			continue
		p["fire_cd"] = Weapons.cooldown(p["weapon"], p["mods"])
		_spawn_projectiles(p["pos"], dir, p["weapon"], p["mods"], id)


func _step_projectiles(delta: float) -> void:
	var expired: Array = []
	var killed: Array = []
	# 黑洞吸附：先计算所有黑洞对敌人物体的拉力
	var blackholes: Array = []
	for pid in projectiles:
		var pr: Dictionary = projectiles[pid]
		if pr.get("pull_radius", 0.0) > 0.0:
			blackholes.append(pr)
	for bh in blackholes:
		for eid in enemies:
			var e: Dictionary = enemies[eid]
			var d: float = bh["pos"].distance_to(e["pos"])
			if d < bh["pull_radius"] and d > 5.0:
				var pull_dir: Vector2 = (bh["pos"] - e["pos"]).normalized()
				var force: float = (1.0 - d / bh["pull_radius"]) * 300.0 * delta
				e["pos"] += pull_dir * force
				e["hp"] -= int(bh["dmg"]) * delta
	for pid in projectiles:
		var pr: Dictionary = projectiles[pid]
		if pr.get("pull_radius", 0.0) > 0.0:
			pr["ttl"] -= delta
			if pr["ttl"] <= 0.0:
				expired.append(pid)
			continue
		pr["pos"] = pr["pos"] + pr["vel"] * delta
		pr["ttl"] -= delta
		if pr["ttl"] <= 0.0:
			expired.append(pid)
			continue
		var from_enemy: bool = pr.get("from_enemy", false)
		# 玩家子弹打敌人
		if not from_enemy:
			for eid in enemies:
				var e: Dictionary = enemies[eid]
				var radius := Combat.enemy_radius(e["kind"])
				var proj_r := Weapons.radius(pr["kind"])
				var hit := Combat.circle_hit(pr["pos"], proj_r, e["pos"], radius)
				if not hit:
					continue
				e["hp"] -= int(pr["dmg"])
				expired.append(pid)
				if pr.get("freeze", 0.0) > 0.0:
					e["freeze_time"] = pr["freeze"]
				if e["hp"] <= 0:
					killed.append([eid, int(pr.get("owner", 0))])
				break
		# 敌人子弹打玩家
		else:
			for id in players:
				var p: Dictionary = players[id]
				if p["status"] != Combat.PLAYER_ALIVE:
					continue
				if p["invuln"] > 0.0:
					continue
				var hit := Combat.circle_hit(pr["pos"], 6.0, p["pos"], Combat.PLAYER_RADIUS)
				if not hit:
					continue
				p["hp"] = maxi(0, p["hp"] - int(pr["dmg"]))
				expired.append(pid)
				if p["hp"] <= 0:
					p["status"] = Combat.PLAYER_DOWNED
					p["revive_progress"] = 0.0
				break
	for pid in expired:
		projectiles.erase(pid)
	for k in killed:
		_kill_enemy(int(k[0]), int(k[1]))


func _step_enemies(delta: float) -> void:
	var targets := _alive_targets()
	for eid in enemies:
		var e: Dictionary = enemies[eid]
		var kind: int = e["kind"]
		var dir := EnemyAI.chase_dir(e["pos"], targets)
		e["pos"] = EnemyAI.step(e["pos"], dir, delta, Waves.enemy_speed(kind, wave))
		e["touch_cd"] = maxf(0.0, e["touch_cd"] - delta)
		e["fire_cd"] = maxf(0.0, e.get("fire_cd", 0.0) - delta)
		if e["touch_cd"] > 0.0:
			continue
		var radius := Combat.enemy_radius(kind)
		for id in players:
			var p: Dictionary = players[id]
			if p["status"] != Combat.PLAYER_ALIVE:
				continue
			if p["invuln"] > 0.0:
				continue
			var touching := Combat.circle_hit(e["pos"], radius, p["pos"], Combat.PLAYER_RADIUS)
			if not touching:
				continue
			p["hp"] = maxi(0, p["hp"] - Combat.enemy_touch_damage(kind))
			e["touch_cd"] = Combat.enemy_touch_interval(kind)
			if p["hp"] <= 0:
				p["status"] = Combat.PLAYER_DOWNED
				p["revive_progress"] = 0.0
			break


func _step_combos(delta: float) -> void:
	"""组合技触发逻辑：遍历所有玩家的 active combos，释放特效"""
	for id in players:
		var p: Dictionary = players[id]
		if p["status"] != Combat.PLAYER_ALIVE:
			continue
		var combos: Array = p.get("combos", [])
		for cid in combos:
			if cid == Weapons.COMBO_BLACKHOLE:
				p["combo_timer_blackhole"] = p.get("combo_timer_blackhole", 10.0) - delta
				if p["combo_timer_blackhole"] <= 0.0:
					p["combo_timer_blackhole"] = 10.0
					var tgt: Variant = _nearest_enemy_fast(p["pos"])
					if tgt != null:
						var bh_pos: Vector2 = (tgt as Dictionary)["pos"]
						var bh := _alloc_id()
						projectiles[bh] = {
							"pos": bh_pos,
							"vel": Vector2.ZERO,
							"ttl": 3.0,
							"dmg": 5,
							"dir": Vector2.ZERO,
							"kind": Weapons.KIND_MINE,
							"owner": id,
							"pull_radius": 150.0,
						}
			elif cid == Weapons.COMBO_METEOR_SHOWER:
				p["combo_timer_meteor"] = p.get("combo_timer_meteor", 5.0) - delta
				if p["combo_timer_meteor"] <= 0.0:
					p["combo_timer_meteor"] = 5.0
					for _i in 3:
						var tgt := _random_player_pos()
						var off := Vector2(_rng.randf_range(-300, 300), _rng.randf_range(-500, -200))
						var start := tgt + off
						var meteor := _alloc_id()
						projectiles[meteor] = {
							"pos": start,
							"vel": Vector2(0, 600),
							"ttl": 2.0,
							"dmg": 80,
							"dir": Vector2(0, 1),
							"kind": Weapons.KIND_MISSILE,
							"owner": id,
							"meteor": true,
						}
			elif cid == Weapons.COMBO_TIME_WARP:
				p["combo_timer_timewarp"] = p.get("combo_timer_timewarp", 15.0) - delta
				# 时间凝滞：本版本内通过减速敌人实现
				# 暂不实现全局 time_scale（会扰乱 dt）
			elif cid == Weapons.COMBO_ICE_STORM:
				p["combo_timer_icestorm"] = p.get("combo_timer_icestorm", 6.0) - delta
				if p["combo_timer_icestorm"] <= 0.0:
					p["combo_timer_icestorm"] = 6.0
					# 冰风暴：向周围 360 度射 16 颗冰弹
					var dir := Vector2.RIGHT
					for a in range(16):
						var d := dir.rotated(float(a) * TAU / 16.0)
						var pid := _alloc_id()
						projectiles[pid] = {
							"pos": p["pos"],
							"vel": d * Weapons.speed(Weapons.KIND_FROST),
							"ttl": 0.8,
							"dmg": Weapons.damage(Weapons.KIND_FROST, p["mods"]) * 2,
							"dir": d,
							"kind": Weapons.KIND_FROST,
							"owner": id,
						}
			elif cid == Weapons.COMBO_JUDGMENT:
				p["combo_timer_judgment"] = p.get("combo_timer_judgment", 8.0) - delta
				if p["combo_timer_judgment"] <= 0.0:
					p["combo_timer_judgment"] = 8.0
					# 天罚：对所有敌人造成伤害
					for eid in enemies:
						enemies[eid]["hp"] -= 50


func _step_enemy_firing(delta: float) -> void:
	"""敌人远程攻击：普通敌人在一定概率下向最近的玩家发射子弹"""
	if not enemy_fire_enabled:
		return
	var targets := _alive_targets()
	for eid in enemies:
		var e: Dictionary = enemies[eid]
		e["fire_cd"] = maxf(0.0, e.get("fire_cd", 0.0) - delta)
		if e["fire_cd"] > 0.0:
			continue
		if targets.is_empty():
			continue
		var kind: int = e["kind"]
		# Boss 和普通敌人的射击频率不同
		var cd := 2.5 if kind == Combat.ENEMY_KIND_BOSS else 4.0
		e["fire_cd"] = cd
		var dir := EnemyAI.chase_dir(e["pos"], targets)
		if dir == Vector2.ZERO:
			continue
		# Boss 射 6 颗扇形弹幕，普通敌人射 1 颗
		var n := 6 if kind == Combat.ENEMY_KIND_BOSS else 1
		var spread := 0.3
		for i in n:
			var off := (float(i) - float(n - 1) * 0.5) * spread
			var d := dir.rotated(off)
			var pid := _alloc_id()
			projectiles[pid] = {
				"pos": e["pos"],
				"vel": d * 200.0,
				"ttl": 3.0,
				"dmg": 15 if kind == Combat.ENEMY_KIND_BOSS else 8,
				"dir": d,
				"kind": Weapons.KIND_PISTOL,
				"owner": 0,
				"from_enemy": true,
			}


func _step_downed(delta: float) -> void:
	## M4.3：不再有流血永久阵亡——倒地者只要附近有存活队友即可被救起，可无限次。
	for id in players:
		var p: Dictionary = players[id]
		if p["invuln"] > 0.0:
			p["invuln"] = maxf(0.0, p["invuln"] - delta)
		if p["status"] != Combat.PLAYER_DOWNED:
			continue
		if _count_helpers(id) > 0:
			p["revive_progress"] += delta
			if p["revive_progress"] >= Combat.REVIVE_HOLD:
				p["status"] = Combat.PLAYER_ALIVE
				p["hp"] = Combat.REVIVE_HP
				p["invuln"] = Combat.REVIVE_INVULN
				p["revive_progress"] = 0.0
		else:
			p["revive_progress"] = maxf(0.0, p["revive_progress"] - delta * 2.0)


func _step_loot(delta: float) -> void:
	var removed: Array = []
	for lid in loot:
		var l: Dictionary = loot[lid]
		var ttl := float(l.get("ttl", Combat.LOOT_TTL)) - delta
		if ttl <= 0.0:
			removed.append(lid)
			continue
		l["ttl"] = ttl
		# M4.4：碎片归属击杀者；击杀者不在场/已倒地则回退到最近的存活玩家
		var owner := int(l.get("owner", 0))
		var target := 0
		if owner != 0 and players.has(owner) and players[owner]["status"] == Combat.PLAYER_ALIVE:
			target = owner
		else:
			target = _nearest_alive_player_id(l["pos"])
		if target == 0:
			continue
		var p: Dictionary = players[target]
		var to_player: Vector2 = p["pos"] - l["pos"]
		var d := to_player.length()
		var pickup_r := Combat.PICKUP_RADIUS * float(p["mods"].get("pickup_radius_scale", 1.0))
		if d <= pickup_r:
			p["pickups"] += 1
			gain_xp(target, Combat.loot_xp(int(l["kind"])))
			var heal := int(p["mods"].get("lifesteal_add", 0))
			if heal > 0:
				p["hp"] = mini(p["hp"] + heal, Progression.max_hp(p["mods"]))
			removed.append(lid)
		else:
			# M4.4：取消磁吸半径上限——碎片从任意距离飞向归属玩家
			var magnet := Combat.LOOT_MAGNET_SPEED * float(p["mods"].get("magnet_radius_scale", 1.0))
			l["pos"] = l["pos"] + to_player.normalized() * magnet * delta
	for lid in removed:
		loot.erase(lid)


func _step_spawner(delta: float) -> void:
	if players.is_empty():
		return  # 专用服务器在无人接入前不刷怪，避免敌人空堆在原点
	_spawn_accum += delta
	if _spawn_accum >= spawn_interval and enemies.size() < Waves.max_enemies(wave):
		_spawn_accum = 0.0
		_spawn_normal()
	if kills >= _next_boss_at and boss_id == 0 and not players.is_empty():
		spawn_boss()
		_next_boss_at += Combat.BOSS_EVERY_KILLS


# ---------------- 内部辅助 ----------------


func _spawn_normal() -> void:
	var anchor := _random_player_pos()
	var angle := _rng.randf_range(0.0, TAU)
	var at := anchor + Vector2.RIGHT.rotated(angle) * Combat.SPAWN_RADIUS
	spawn_enemy(Rooms.clamp_inside(at, Combat.ENEMY_RADIUS))


func _spawn_projectiles(
	pos: Vector2, dir: Vector2, weapon: int, mods: Dictionary, owner: int
) -> void:
	var n := Weapons.projectile_count(weapon, mods)
	var dmg := Weapons.damage(weapon, mods)
	var spread := Weapons.spread(weapon)
	var speed := Weapons.speed(weapon)
	var ttl := Weapons.ttl(weapon)
	for i in n:
		if projectiles.size() >= Weapons.MAX_PROJECTILES:
			break
		var off := (float(i) - float(n - 1) * 0.5) * spread
		var d := dir.rotated(off)
		var pid := _alloc_id()
		projectiles[pid] = {
			"pos": pos,
			"vel": d * speed,
			"ttl": ttl,
			"dmg": dmg,
			"dir": d,
			"kind": weapon,
			"owner": owner,
		}


func _kill_enemy(eid: int, owner: int = 0) -> void:
	if not enemies.has(eid):
		return
	var e: Dictionary = enemies[eid]
	var pos: Vector2 = e["pos"]
	var kind: int = e["kind"]
	enemies.erase(eid)
	if eid == boss_id:
		boss_id = 0
		boss_kills += 1
	kills += 1
	var loot_kind := Combat.LOOT_KIND_BIG if kind == Combat.ENEMY_KIND_BOSS else Combat.LOOT_KIND_XP
	_add_loot(pos, loot_kind, owner)


func _add_loot(pos: Vector2, kind: int, owner: int = 0) -> void:
	## 有界掉落：先按硬上限淘汰最旧（实体 id 单调递增 → 最小 id 即最旧），再带 TTL 入池。
	while loot.size() >= Combat.MAX_LOOT:
		var keys := loot.keys()
		keys.sort()
		loot.erase(int(keys[0]))
	var lid := _alloc_id()
	loot[lid] = {"pos": pos, "kind": kind, "owner": owner, "ttl": Combat.LOOT_TTL}


func _check_run_over() -> void:
	## M4.3：失败条件放宽为「场上无任何 PLAYER_ALIVE」——全员倒地/阵亡且无人可施救即当帧判负。
	if run_over:
		return
	var any_alive := false
	for id in players:
		if players[id]["status"] == Combat.PLAYER_ALIVE:
			any_alive = true
			break
	if not any_alive and not players.is_empty():
		run_over = true
		won = false
		return
	if boss_id == 0 and boss_kills >= Combat.WIN_BOSS_KILLS:
		run_over = true
		won = true


func _enemy_positions() -> Array:
	var out: Array = []
	for id in enemies:
		out.append({"pos": enemies[id]["pos"]})
	return out


func _alive_targets() -> Array:
	var out: Array = []
	for id in players:
		if players[id]["status"] == Combat.PLAYER_ALIVE:
			out.append({"pos": players[id]["pos"]})
	return out


func _count_helpers(id: int) -> int:
	var n := 0
	var pos: Vector2 = players[id]["pos"]
	for other in players:
		if other == id:
			continue
		var p: Dictionary = players[other]
		if p["status"] != Combat.PLAYER_ALIVE:
			continue
		if pos.distance_to(p["pos"]) <= Combat.REVIVE_RADIUS:
			n += 1
	return n


func _revive01(p: Dictionary) -> int:
	return clampi(roundi(float(p["revive_progress"]) / Combat.REVIVE_HOLD * 255.0), 0, 255)


func _hp01(e: Dictionary) -> int:
	## 血条比例，分母与主机权威血量同源（生成时定档），避免与波次放大后的绝对值错配。
	var full := maxi(1, int(e.get("max_hp", 1)))
	return clampi(roundi(float(e["hp"]) / float(full) * 255.0), 0, 255)


func _nearest_alive_player_id(pos: Vector2) -> int:
	var best := 0
	var best_d := INF
	for id in players:
		if players[id]["status"] != Combat.PLAYER_ALIVE:
			continue
		var d: float = players[id]["pos"].distance_to(pos)
		if d < best_d:
			best_d = d
			best = id
	return best


func _nearest_enemy_fast(pos: Vector2) -> Variant:
	"""返回最近的敌人字典，用于组合技定位黑洞位置"""
	var best: Variant = null
	var best_d := INF
	for eid in enemies:
		var e: Dictionary = enemies[eid]
		if e["hp"] <= 0:
			continue
		var d: float = pos.distance_to(e["pos"])
		if d < best_d:
			best_d = d
			best = e
	return best


func _random_player_pos() -> Vector2:
	var ids := players.keys()
	if ids.is_empty():
		return Vector2.ZERO
	return players[ids[_rng.randi_range(0, ids.size() - 1)]]["pos"]


func _alloc_id() -> int:
	_next_id += 1
	return _next_id


func _new_player() -> Dictionary:
	return {
		"pos": Vector2.ZERO,
		"move": Vector2.ZERO,
		"buttons": 0,
		"hp": Combat.PLAYER_MAX_HP,
		"status": Combat.PLAYER_ALIVE,
		"fire_cd": 0.0,
		"invuln": 0.0,
		"revive_progress": 0.0,
		"pickups": 0,
		"weapon": Weapons.default_id(),
		"weapons": [Weapons.default_id()],
		"combos": [],
		"mods": Progression.default_modifiers(),
		"level": 1,
		"xp": 0,
	}
