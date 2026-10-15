extends Node2D
## 世界场景：按 Net 广播的 world_state 渲染，单人模式本地模拟战斗。

const PlayerScript := preload("res://scripts/player.gd")
const EnemyScript := preload("res://scripts/enemy.gd")
const LootScript := preload("res://scripts/loot.gd")
const ProjectileScript := preload("res://scripts/projectile.gd")
const UpgradeMenu := preload("res://scripts/upgrade_menu.gd")
const RunOverMenu := preload("res://scripts/runover_menu.gd")
const Progression := preload("res://sim/progression.gd")
const Weapons := preload("res://sim/weapons.gd")
const Rooms := preload("res://sim/rooms.gd")
const Combat := preload("res://sim/combat.gd")
const NetHostLogic := preload("res://net/net_host.gd")

# 5 关卡配置（参考 pygame 版 LEVELS）
const LEVEL_CFG: Array = [
	{"name": "数据废墟", "time": 120, "hp": 1.0, "spd": 1.0, "dmg": 1.0, "boss_hp": 500},
	{"name": "病毒丛林", "time": 150, "hp": 1.5, "spd": 1.1, "dmg": 1.3, "boss_hp": 1200},
	{"name": "故障深渊", "time": 180, "hp": 2.2, "spd": 1.2, "dmg": 1.6, "boss_hp": 2500},
	{"name": "核心风暴", "time": 210, "hp": 3.0, "spd": 1.3, "dmg": 2.0, "boss_hp": 4500},
	{"name": "终焉之地", "time": 300, "hp": 4.0, "spd": 1.5, "dmg": 2.5, "boss_hp": 8000},
]

const COLORS: Array[Color] = [
	Color("4aa3ff"),
	Color("ff7a59"),
	Color("ffd93d"),
	Color("7be07b"),
]

var _player_nodes := {}
var _enemy_nodes := {}
var _loot_nodes := {}
var _proj_nodes := {}
var _level := 1
var _xp := 0
var _kills := 0
var _wave := 1
var _local_weapon := 0
var _last_pick := ""
var _hp := 100
var _max_hp := 100
var _combos_str := ""

var _upgrade_menu: Control
var _runover_menu: Control

# 单机模拟后端
var _single_host: NetHostLogic = null
var _single_id: int = 1
var _single_run_over := false

@onready var _info: Label = $Hud/TopBar/Info
@onready var _hp_fill: ColorRect = $Hud/HpBar/HpFill
@onready var _hp_label: Label = $Hud/HpLabel
@onready var _combo_label: Label = $Hud/ComboLabel

func _is_single() -> bool:
	return Net.mode == Net.Mode.NONE

func _host() -> NetHostLogic:
	return _single_host if _is_single() else null


func _ready() -> void:
	# Camera2D 跟随本地玩家
	var cam: Camera2D = $Camera2D
	cam.enabled = true
	cam.zoom = Vector2(1, 1)

	if _is_single():
		_single_host = NetHostLogic.new()
		_single_host.reset()
		var lvl := clampi(Global.current_level, 0, LEVEL_CFG.size() - 1)
		var cfg: Dictionary = LEVEL_CFG[lvl]
		_single_host.spawn_interval = max(0.4, 1.5 - float(lvl) * 0.2)
		_single_host.add_player(_single_id)
		var p: Dictionary = _single_host.players[_single_id]
		p["pos"] = Vector2(640, 360)
		# 应用天赋效果
		p["hp"] += Global.talent_level("hp") * 10
		p["hp"] = maxi(p["hp"], 1)
		p["mods"]["damage_add"] = Global.talent_level("damage") * 2
		p["mods"]["move_speed_scale"] = 1.0 + Global.talent_level("speed") * 0.05
		p["mods"]["crit_chance_add"] = Global.talent_level("crit") * 0.03
		p["mods"]["cooldown_scale"] = maxf(0.5, 1.0 - Global.talent_level("atk_speed") * 0.05)
		p["mods"]["heal_per_level"] = Global.talent_level("regen")
		p["mods"]["max_hp_add"] = Global.talent_level("hp") * 10
		# 初始刷一批敌人让玩家有东西打
		for i in 10:
			var a := randf() * TAU
			var r := randf_range(200, 400)
			var pos := Vector2(640.0, 360.0) + Vector2.RIGHT.rotated(a) * r
			_single_host.spawn_enemy(pos, Combat.ENEMY_KIND_NORMAL)
		# 首次立即渲染，不等物理帧
		_sync_players(_single_host.player_states())
		_sync_enemies(_single_host.enemy_states())
		_sync_loot(_single_host.loot_states())
		# 立即把 camera 对准玩家
		cam.position = Vector2(640, 360)
	else:
		Net.world_state.connect(_on_world_state)
		Net.player_left.connect(_on_player_left)
		Net.room_ready.connect(_on_room_ready)
		if Net.is_host():
			queue_redraw()

	Net.upgrade_offer.connect(_on_upgrade_offer)
	Net.player_upgrade.connect(_on_player_upgrade)
	Net.run_over.connect(_on_run_over)

	_runover_menu = RunOverMenu.new()
	_runover_menu.name = "RunOverMenu"
	$Hud.add_child(_runover_menu)
	_runover_menu.back_requested.connect(_on_back_requested)

	_upgrade_menu = UpgradeMenu.new()
	_upgrade_menu.name = "UpgradeMenu"
	$Hud.add_child(_upgrade_menu)
	_upgrade_menu.picked.connect(_on_upgrade_picked)

	_update_info()


func _physics_process(_delta: float) -> void:
	_update_info()

	# 单机模式：本地跑 host 模拟 + 直接用渲染数据喂自己
	if _is_single():
		if _single_run_over:
			return
		var h := _single_host
		# 读取本地输入
		var move := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		var buttons := 0
		if Input.is_action_pressed("fire"):
			buttons |= 1
		h.set_remote_input(_single_id, move, buttons)
		# 物理步进（1/60 秒）
		h.physics_step(_delta)
		# 检查游戏是否结束
		if h.run_over:
			_single_run_over = true
			_on_run_over(h.won, h.stats(_single_id))
			return
		# 如果有待处理的升级
		var offers := h.pending_offer(_single_id)
		if offers.size() > 0:
			_on_upgrade_offer(offers)
		# 渲染世界
		_sync_players(h.player_states())
		_sync_enemies(h.enemy_states())
		_sync_loot(h.loot_states())
		_sync_projectiles(h.projectile_states())
		# 强制同步玩家节点位置到 host 模拟位置（单机模式下 Net 不会触发 push_authoritative）
		if _single_host and _single_host.players.has(_single_id):
			var ppos: Vector2 = _single_host.players[_single_id]["pos"]
			var pnode: Node2D = _player_nodes.get(_single_id)
			if pnode != null:
				pnode.position = ppos
		# 更新 HUD 数据
		var m := h.meta(_single_id)
		_level = int(m.get("level", 1))
		_xp = int(m.get("xp", 0))
		_kills = int(m.get("kills", 0))
		_wave = int(m.get("wave", 1))
		_hp = int(m.get("hp", 100))
		_max_hp = int(m.get("max_hp", 100))
		_combos_str = ""
		var combos_raw: Array = m.get("combos", [])
		if combos_raw.size() > 0:
			var names: Array = []
			for cid in combos_raw:
				for c in Weapons.COMBOS:
					if c["id"] == cid:
						names.append(c["name"])
						break
			_combos_str = "组合: " + ", ".join(names)


func _draw() -> void:
	for w in Net.room_walls():
		var r: Rect2 = w
		draw_rect(r, Color("2a3550"), true)
		draw_rect(r, Color("3d4d70"), false, 2.0)
	draw_rect(Rooms.arena_rect(), Color("5566aa"), false, 4.0)


func _on_room_ready() -> void:
	queue_redraw()


func _on_world_state(
	_tick: int, meta: Dictionary, players: Array, enemies: Array, loot: Array, projectiles: Array
) -> void:
	_level = int(meta.get("level", 1))
	_xp = int(meta.get("xp", 0))
	_kills = int(meta.get("kills", 0))
	_wave = int(meta.get("wave", 1))
	_hp = int(meta.get("hp", 100))
	_max_hp = int(meta.get("max_hp", 100))
	var combos_raw: Array = meta.get("combos", [])
	_combos_str = ""
	if combos_raw.size() > 0:
		var names: Array = []
		for cid in combos_raw:
			for c in Weapons.COMBOS:
				if c["id"] == cid:
					names.append(c["name"])
					break
		_combos_str = "组合: " + ", ".join(names)
	_sync_players(players)
	_sync_enemies(enemies)
	_sync_loot(loot)
	_sync_projectiles(projectiles)


func _sync_players(players: Array) -> void:
	for p in players:
		var id: int = p["id"]
		var node: Node2D = _player_nodes.get(id)
		if node == null:
			node = _spawn_player(id)
		if id == Net.local_id:
			_local_weapon = int(p.get("weapon", 0))
		node.push_authoritative(
			p["pos"],
			int(p.get("hp", 100)),
			int(p.get("status", 0)),
			int(p.get("revive01", 0)),
			int(p.get("weapon", 0))
		)

	# 单机模式：从 _single_host 直接同步玩家位置，不走 Net 信号
	if _is_single() and _single_host != null:
		for pid in _single_host.players:
			var p: Dictionary = _single_host.players[pid]
			var node: Node2D = _player_nodes.get(pid)
			if node == null:
				node = _spawn_player(pid)
			node.position = p["pos"]
			node.hp = int(p.get("hp", 100))
			node.status = int(p.get("status", 0))
			node.weapon = int(p.get("weapon", 0))


func _sync_enemies(enemies: Array) -> void:
	var alive := {}
	for e in enemies:
		var id: int = e["id"]
		alive[id] = true
		var node: Node2D = _enemy_nodes.get(id)
		if node == null:
			node = _spawn_enemy(id)
		node.push_authoritative(e["pos"], int(e.get("hp01", 255)), int(e.get("kind", 0)))
	for id in _enemy_nodes.keys():
		if not alive.has(id):
			_enemy_nodes[id].queue_free()
			_enemy_nodes.erase(id)


func _sync_loot(loot: Array) -> void:
	var alive := {}
	for l in loot:
		var id: int = l["id"]
		alive[id] = true
		var node: Node2D = _loot_nodes.get(id)
		if node == null:
			node = _spawn_loot(id, int(l.get("kind", 0)))
		node.push_authoritative(l["pos"])
	for id in _loot_nodes.keys():
		if not alive.has(id):
			_loot_nodes[id].queue_free()
			_loot_nodes.erase(id)


func _sync_projectiles(projectiles: Array) -> void:
	var alive := {}
	for pj in projectiles:
		var id: int = pj["id"]
		alive[id] = true
		var node: Node2D = _proj_nodes.get(id)
		if node == null:
			node = _spawn_projectile(id, int(pj.get("kind", 0)))
		node.push_authoritative(pj["pos"], pj["dir"], int(pj.get("kind", 0)))
	for id in _proj_nodes.keys():
		if not alive.has(id):
			_proj_nodes[id].queue_free()
			_proj_nodes.erase(id)


func _on_player_left(id: int) -> void:
	var node: Node2D = _player_nodes.get(id)
	if node != null:
		node.queue_free()
		_player_nodes.erase(id)


func _spawn_player(id: int) -> Node2D:
	var node := PlayerScript.new()
	node.name = "Player%d" % id
	node.setup(id, id == Net.local_id, COLORS[(id - 1) % COLORS.size()])
	add_child(node)
	_player_nodes[id] = node
	return node


func _spawn_enemy(id: int) -> Node2D:
	var node := EnemyScript.new()
	node.name = "Enemy%d" % id
	node.setup(id)
	add_child(node)
	_enemy_nodes[id] = node
	return node


func _spawn_loot(id: int, kind: int) -> Node2D:
	var node := LootScript.new()
	node.name = "Loot%d" % id
	node.setup(id, kind)
	add_child(node)
	_loot_nodes[id] = node
	return node


func _spawn_projectile(id: int, kind: int) -> Node2D:
	var node := ProjectileScript.new()
	node.name = "Proj%d" % id
	node.setup(id, kind)
	add_child(node)
	_proj_nodes[id] = node
	return node


# ---------------- 升级与结算 ----------------


func _on_upgrade_offer(choices: PackedInt32Array) -> void:
	if _upgrade_menu != null:
		_upgrade_menu.open(choices)


func _on_upgrade_picked(card_id: int) -> void:
	if _is_single():
		_single_host.apply_choice(_single_id, card_id)
	else:
		Net.send_upgrade_pick(card_id)


func _on_player_upgrade(player_id: int, card_id: int) -> void:
	var card := Progression.card_by_id(card_id)
	_last_pick = "%d 号获得 %s" % [player_id, str(card.get("name", "?"))]


func _on_run_over(won: bool, stats: Dictionary) -> void:
	# M4.4：结算面板弹出时收起尚未选完的升级卡片，避免两层 UI 叠显
	if _upgrade_menu != null:
		_upgrade_menu.visible = false
	if _runover_menu != null:
		_runover_menu.show_result(won, stats)
	# 记录排行榜
	Global.add_score({
		"name": Global.nickname if not Global.nickname.is_empty() else "无名",
		"level": int(stats.get("level", 1)),
		"kills": int(stats.get("kills", 0)),
		"boss_kills": int(stats.get("boss_kills", 0)),
		"wave": _wave,
	})
	# 奖励碎片
	var reward := int(stats.get("kills", 0)) * 2 + (50 if won else 10)
	Global.add_shards(reward)


func _on_back_requested() -> void:
	if Net.is_client():
		Net.client_disconnect()
	elif Net.is_host():
		Net.host_stop()
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _update_info() -> void:
	var role := "未连接"
	if Net.is_host():
		role = "主机 id=%d" % Net.local_id
	elif Net.is_client():
		role = "客户端 id=%d" % Net.local_id
	var pick := "" if _last_pick.is_empty() else " | %s" % _last_pick
	var wpn := " | 武器 %s" % Weapons.name_of(_local_weapon)
	_info.text = (
		"%s | 关卡 %d | 波次 %d | 击杀 %d | 在线 %d | 敌人 %d%s%s"
		% [
			role,
			_level,
			_wave,
			_kills,
			_player_nodes.size(),
			_enemy_nodes.size(),
			wpn,
			pick,
		]
	)
	# 血量条
	if _max_hp > 0:
		var ratio := float(_hp) / float(_max_hp)
		_hp_fill.size.x = 300.0 * clamp(ratio, 0.0, 1.0)
		_hp_label.text = "HP: %d / %d" % [_hp, _max_hp]
	# 组合技显示
	_combo_label.text = _combos_str
