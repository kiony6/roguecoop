extends Panel
## 技能树面板：预设选择 + 节点解锁（深色科幻风）

const Skills := preload("res://sim/skills.gd")

var _ctrl: Dictionary = {}


func _ready() -> void:
	position = Vector2(80, 40)
	size = Vector2(1120, 640)
	_setup_style()
	_build_panel()


func _setup_style() -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.04, 0.06, 0.12, 0.95)
	s.border_color = Color(0.2, 0.5, 1.0, 0.6)
	s.border_width_top = 1; s.border_width_bottom = 1
	s.border_width_left = 1; s.border_width_right = 1
	s.corner_radius_top_left = 8; s.corner_radius_top_right = 8
	s.corner_radius_bottom_left = 8; s.corner_radius_bottom_right = 8
	add_theme_stylebox_override("panel", s)


func _btn(text: String, pos: Vector2, size2: Vector2) -> Button:
	var b := Button.new()
	b.text = text; b.position = pos; b.size = size2
	b.add_theme_font_size_override("font_size", 14)
	var sn := StyleBoxFlat.new()
	sn.bg_color = Color(0.08, 0.12, 0.25, 0.9)
	sn.border_color = Color(0.3, 0.6, 1.0, 0.5)
	sn.border_width_top = 1; sn.border_width_bottom = 1
	sn.border_width_left = 1; sn.border_width_right = 1
	sn.corner_radius_top_left = 5; sn.corner_radius_top_right = 5
	sn.corner_radius_bottom_left = 5; sn.corner_radius_bottom_right = 5
	b.add_theme_stylebox_override("normal", sn)
	var sh := sn.duplicate()
	sh.bg_color = Color(0.15, 0.2, 0.4, 0.95)
	sh.border_color = Color(0.5, 0.8, 1.0, 0.8)
	b.add_theme_stylebox_override("hover", sh)
	b.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	return b


func _label(text: String, pos: Vector2, color: Color = Color(0.7, 0.85, 1.0), sz: int = 16) -> Label:
	var l := Label.new()
	l.text = text; l.position = pos
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", sz)
	return l


func _build_panel() -> void:
	# 标题
	add_child(_label("技能树 · 构筑系统", Vector2(20, 15), Color(0.3, 0.7, 1.0), 22))

	# 左侧：预设选择
	var pnl := Panel.new()
	pnl.position = Vector2(20, 55); pnl.size = Vector2(340, 560)
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.06, 0.09, 0.18, 0.9)
	ps.border_color = Color(0.15, 0.3, 0.6, 0.4)
	ps.corner_radius_top_left = 6; ps.corner_radius_top_right = 6
	ps.corner_radius_bottom_left = 6; ps.corner_radius_bottom_right = 6
	ps.border_width_top = 1; ps.border_width_bottom = 1
	ps.border_width_left = 1; ps.border_width_right = 1
	pnl.add_theme_stylebox_override("panel", ps)
	add_child(pnl)
	pnl.add_child(_label("构筑预设", Vector2(15, 10), Color(0.5, 0.8, 1.0), 16))

	var presets := Skills.presets()
	var sc := ScrollContainer.new()
	sc.position = Vector2(10, 40); sc.size = Vector2(320, 470)
	pnl.add_child(sc)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(vb)

	for pdata in presets:
		var pid: String = str(pdata.get("id", ""))
		var pname: String = str(pdata.get("name", ""))
		var pdesc: String = str(pdata.get("desc", ""))

		var card := Panel.new()
		card.custom_minimum_size.y = 65
		var cs := StyleBoxFlat.new()
		cs.bg_color = Color(0.08, 0.12, 0.22, 0.85)
		cs.border_color = Color(0.2, 0.4, 0.8, 0.3)
		cs.corner_radius_top_left = 4; cs.corner_radius_top_right = 4
		cs.corner_radius_bottom_left = 4; cs.corner_radius_bottom_right = 4
		cs.border_width_top = 1; cs.border_width_bottom = 1
		cs.border_width_left = 1; cs.border_width_right = 1
		card.add_theme_stylebox_override("panel", cs)
		vb.add_child(card)

		var tl := Label.new()
		tl.text = pname; tl.position = Vector2(10, 5)
		tl.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
		tl.add_theme_font_size_override("font_size", 15)
		card.add_child(tl)

		var dl := Label.new()
		dl.text = pdesc; dl.position = Vector2(10, 28)
		dl.size = Vector2(240, 32)
		dl.add_theme_color_override("font_color", Color(0.5, 0.6, 0.8))
		dl.add_theme_font_size_override("font_size", 11)
		card.add_child(dl)

		var sb := _btn("选用", Vector2(260, 15), Vector2(55, 35))
		var k := pid
		sb.pressed.connect(_select_preset.bind(k))
		card.add_child(sb)

	# 右侧：节点网格
	add_child(_label("技能节点", Vector2(380, 55), Color(0.5, 0.8, 1.0), 16))
	add_child(_label("技能点: %d" % Global.data.get("skill_points", 0), Vector2(380, 80), Color(1, 0.7, 0.3), 14))

	# 返回+关闭
	var close := _btn("× 关闭", Vector2(1040, 15), Vector2(60, 35))
	close.pressed.connect(_on_close)
	add_child(close)

	# 节点列表
	_refresh_nodes()


func _refresh_nodes() -> void:
	# 清除旧节点
	for c in get_children():
		if c.name.begins_with("node_"):
			c.queue_free()

	var unlocked: Array = Global.data.get("unlocked_skills", [])
	var nodes := Skills.all()
	var start_y := 105
	var col_w := 220
	var cols := 3
	for i in nodes.size():
		var node: Dictionary = nodes[i]
		var nid := int(node.get("id", 0))
		var col := i % cols
		var row := i / cols
		var x := 380 + col * (col_w + 15)
		var y := start_y + row * 80

		var card := Panel.new()
		card.name = "node_%d" % nid
		card.position = Vector2(x, y)
		card.size = Vector2(col_w, 72)

		var is_unlocked := unlocked.has(nid)
		var can_unlock := Skills.can_unlock(unlocked, nid, Global.data.get("skill_points", 0))

		var bg := Color(0.06, 0.09, 0.18, 0.85) if not is_unlocked else Color(0.08, 0.18, 0.3, 0.85)
		if not is_unlocked and can_unlock:
			bg = Color(0.1, 0.2, 0.35, 0.85)
		var cs := StyleBoxFlat.new()
		cs.bg_color = bg
		cs.border_color = Color(0.1, 0.4, 0.9, 0.3)
		cs.corner_radius_top_left = 4; cs.corner_radius_top_right = 4
		cs.corner_radius_bottom_left = 4; cs.corner_radius_bottom_right = 4
		cs.border_width_top = 1; cs.border_width_bottom = 1
		card.add_theme_stylebox_override("panel", cs)
		add_child(card)

		var tl := Label.new()
		tl.text = str(node.get("name", "?"))
		tl.position = Vector2(8, 3)
		tl.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0) if is_unlocked else Color(0.5, 0.55, 0.7))
		tl.add_theme_font_size_override("font_size", 13)
		card.add_child(tl)

		var dl := Label.new()
		dl.text = str(node.get("desc", ""))
		dl.position = Vector2(8, 22); dl.size = Vector2(200, 30)
		dl.add_theme_color_override("font_color", Color(0.4, 0.5, 0.7))
		dl.add_theme_font_size_override("font_size", 10)
		card.add_child(dl)

		if not is_unlocked and can_unlock:
			var ub := _btn("解锁(%d技能点)" % node.get("cost", 1), Vector2(10, 50), Vector2(200, 20))
			ub.add_theme_font_size_override("font_size", 10)
			var k := nid
			ub.pressed.connect(_unlock_node.bind(k))
			card.add_child(ub)
		elif is_unlocked:
			var ul := Label.new()
			ul.text = "✓ 已解锁"; ul.position = Vector2(10, 50)
			ul.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))
			ul.add_theme_font_size_override("font_size", 11)
			card.add_child(ul)


func _select_preset(preset_id: String) -> void:
	var pdata := Skills.preset(preset_id)
	if pdata.is_empty():
		return
	var ids: Array = pdata.get("nodes", [])
	var unlocked: Array = Skills.grant(Global.data.get("unlocked_skills", []), ids)
	Global.data["unlocked_skills"] = unlocked
	Global.save_data()
	_refresh_nodes()


func _unlock_node(node_id: int) -> void:
	var unlocked: Array = Global.data.get("unlocked_skills", [])
	var node := Skills.by_id(node_id)
	if node.is_empty():
		return
	var cost := int(node.get("cost", 1))
	if Global.data.get("skill_points", 0) < cost:
		return
	if unlocked.has(node_id):
		return
	unlocked.append(node_id)
	Global.data["unlocked_skills"] = unlocked
	Global.data["skill_points"] = int(Global.data.get("skill_points", 0)) - cost
	Global.save_data()
	_refresh_nodes()


func refresh() -> void:
	_refresh_nodes()


func _on_close() -> void:
	visible = false
	if get_parent():
		var mp = get_parent().get_node_or_null("page_menu")
		if mp:
			mp.visible = true
