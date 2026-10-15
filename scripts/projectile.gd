extends Node2D
## 弹丸表现节点（M4）。弹丸速度快，客户端用「最近权威位置 + 方向」航位推算，
## 避免插值带来的明显滞后；主机直连权威位置。

const Weapons := preload("res://sim/weapons.gd")

var proj_id := 0
var kind := 0

var _auth := Vector2.ZERO
var _dir := Vector2.RIGHT
var _recv_ms := 0.0
var _has_auth := false


func setup(id: int, k: int) -> void:
	proj_id = id
	kind = k
	z_index = -2
	queue_redraw()


func push_authoritative(pos: Vector2, dir: Vector2, k: int) -> void:
	_auth = pos
	if dir.length() > 0.0001:
		_dir = dir
	kind = k
	_recv_ms = float(Time.get_ticks_msec())
	if not _has_auth:
		_has_auth = true
		position = pos
	queue_redraw()


func _physics_process(_delta: float) -> void:
	if not _has_auth:
		return
	# M4.5：本局结算后权威位置被冻结，若继续航位推算，
	# 每帧自推进都会被下一帧快照拽回，表现为弹丸抽搐
	if Net.is_run_over():
		position = _auth
		return
	if Net.is_client():
		var dt := (float(Time.get_ticks_msec()) - _recv_ms) / 1000.0
		position = _auth + _dir.normalized() * Weapons.speed(kind) * dt
	else:
		position = _auth


func _draw() -> void:
	var r := Weapons.radius(kind)
	var col := Color("a8e0ff")
	match kind:
		Weapons.KIND_PISTOL: col = Color("ffffaa")
		Weapons.KIND_RIFLE: col = Color("ffd0f0")
		Weapons.KIND_SHOTGUN: col = Color("ffe9a8")
		Weapons.KIND_RING: col = Color("88ffff")
		Weapons.KIND_LASER: col = Color("f0abfc")
		Weapons.KIND_MISSILE: col = Color("ffb080")
		Weapons.KIND_MINE: col = Color("c084fc")
		Weapons.KIND_FROST: col = Color("88ddff")
		Weapons.KIND_LIGHTNING: col = Color("fde047")
		Weapons.KIND_SPIKES: col = Color("ff6060")
	draw_circle(Vector2.ZERO, r, col)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 16, col.darkened(0.4), 1.5)
