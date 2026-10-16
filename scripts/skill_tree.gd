extends Panel
## 技能树面板：预设推荐 + 节点解锁（深色科幻风）

const Skills := preload("res://sim/skills.gd")

var _ctrl: Dictionary = {}


func _ready() -> void:
	position = Vector2(60, 30)
	size = Vector2(1160, 660)
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
	b.add_theme_font_size_override("font_size", 13)
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


func _scroll_panel(x: float, y: float, w: float, h: float, label2: String) -> VBoxContainer:
	var p := Panel.new()
	p.position = Vector2(x, y); p.size = Vector2(w, h)
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.06, 0.09, 0.18, 0.9)
	ps.border_color = Color(0.15, 0.3, 0.6, 0.4)
	ps.corner_radius_top_left = 6; ps.corner_radius_top_right = 6
	ps.corner_radius_bottom_left = 6; ps.corner_radius_bottom_right = 6
	ps.border_width_top = 1; ps.border_width_bottom = 1
	ps.border_width_left = 1; ps.border_width_right = 1
	p.add_theme_stylebox_override("panel", ps)
	add_child(p)
	p.add_child(_label(label2, Vector2(12, 8), Color(0.5, 0.8, 1.0), 15))
	var sc := ScrollContainer.new()
	sc.position = Vector2(5, 32); sc.size = Vector2(w - 10, h - 38)
	p.add_child(sc)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(vb)
	return vb


func _build_panel() -> void:
	# 标题
	add_child(_label("技能树 · 构筑系统", Vector2(20, 12), Color(0.3, 0.7, 1.0), 24))

	# 技能点 + 关闭 顶栏
	var sp_lbl := Label.new()
	sp_lbl.name = "sp_label"
	sp_lbl.position = Vector2(380, 18)
	sp_lbl.add_theme_color_override("font_color", Color(1, 0.7, 0.3))
	sp_lbl.add_theme_font_size_override("font_size", 18)
	add_child(sp_lbl)

	var close := _btn("✕ 关闭", Vector2(1050, 12), Vector2(80, 32))
	close.pressed.connect(_on_close)
	add_child(close)

	# 左侧：推荐构筑
	var vb := _scroll_panel(15, 48, 345, 590, "推荐构筑")
	var presets := Skills.presets()
	for pdata in presets:
		var pid: String = str(pdata.get("id", ""))
		var pname: String = str(pdata.get("name", ""))
		var pdesc: String = str(pdata.get("desc", ""))
		var pnodes: Array = pdata.get("nodes", [])

		var card := Panel.new()
		card.custom_minimum_size.y = 58
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
		tl.text = pname; tl.position = Vector2(8, 4)
		tl.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
		tl.add_theme_font_size_override("font_size", 14)
		card.add_child(tl)

		var cost_sum := 0
		for nid in pnodes:
			var nd := Skills.by_id(int(nid))
			if not nd.is_empty():
				cost_sum += int(nd.get("cost", 1))

		var dl := Label.new()
		dl.text = pdesc; dl.position = Vector2(8, 25); dl.size = Vector2(200, 30)
		dl.add_theme_color_override("font_color", Color(0.45, 0.55, 0.75))
		dl.add_theme_font_size_override("font_size", 10)
		card.add_child(dl)

		var sb := _btn("推荐(%d点)" % cost_sum, Vector2(265, 12), Vector2(68, 35))
		sb.add_theme_font_size_override("font_size", 11)
		var k := pid
		sb.pressed.connect(_select_preset.bind(k))
		card.add_child(sb)

	# 右侧：节点网格（用 ScrollContainer 防止溢出）
	var right_panel := Panel.new()
	right_panel.position = Vector2(375, 48); right_panel.size = Vector2(765, 590)
	var rps := StyleBoxFlat.new()
	rps.bg_color = Color(0.06, 0.09, 0.18, 0.9)
	rps.border_color = Color(0.15, 0.3, 0.6, 0.4)
	rps.corner_radius_top_left = 6; rps.corner_radius_top_right = 6
	rps.corner_radius_bottom_left = 6; rps.corner_radius_bottom_right = 6
	rps.border_width_top = 1; rps.border_width_bottom = 1
	rps.border_width_left = 1; rps.border_width_right = 1
	right_panel.add_theme_stylebox_override("panel", rps)
	add_child(right_panel)
	right_panel.add_child(_label("技能节点", Vector2(12, 8), Color(0.5, 0.8, 1.0), 15))

	var sc2 := ScrollContainer.new()
	sc2.position = Vector2(5, 32); sc2.size = Vector2(755, 548)
	right_panel.add_child(sc2)
	var vb2 := VBoxContainer.new()
	vb2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc2.add_child(vb2)
	_ctrl["node_grid"] = vb2

	_refresh_nodes()


func _refresh_nodes() -> void:
	var vb = _ctrl.get("node_grid")
	if vb == null:
		return
	for c in vb.get_children():
		c.queue_free()

	var unlocked: Array = Global.data.get("unlocked_skills", [])
	var pts: int = Global.data.get("skill_points", 0)
	var nodes := Skills.all()
	var sp_lbl := get_node_or_null("sp_label")
	if sp_lbl != null:
		sp_lbl.text = "技能点: %d" % pts

	var hb: HBoxContainer = HBoxContainer.new()
	vb.add_child(hb)
	var count_in_row := 0
	var row_width := 0

	for i in nodes.size():
		var node: Dictionary = nodes[i]
		var nid := int(node.get("id", 0))
		var is_unlocked := unlocked.has(nid)
		var can_unlock := Skills.can_unlock(unlocked, nid, pts)
		var cost := int(node.get("cost", 1))

		# 每行放 3 个
		if count_in_row >= 3:
			hb = HBoxContainer.new()
			vb.add_child(hb)
			count_in_row = 0

		var card := Panel.new()
		card.custom_minimum_size = Vector2(245, 72)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		count_in_row += 1

		var bg := Color(0.06, 0.09, 0.18, 0.85)
		if is_unlocked:
			bg = Color(0.08, 0.18, 0.3, 0.85)
		elif can_unlock:
			bg = Color(0.1, 0.2, 0.35, 0.85)

		var cs := StyleBoxFlat.new()
		cs.bg_color = bg
		cs.border_color = Color(0.1, 0.4, 0.9, 0.3) if can_unlock or is_unlocked else Color(0.05, 0.15, 0.3, 0.2)
		cs.corner_radius_top_left = 4; cs.corner_radius_top_right = 4
		cs.corner_radius_bottom_left = 4; cs.corner_radius_bottom_right = 4
		cs.border_width_top = 1; cs.border_width_bottom = 1
		cs.border_width_left = 1; cs.border_width_right = 1
		card.add_theme_stylebox_override("panel", cs)
		hb.add_child(card)

		var tl := Label.new()
		tl.text = str(node.get("name", "?")) + (" ✓" if is_unlocked else "")
		tl.position = Vector2(8, 3)
		tl.add_theme_color_override("font_color",
			Color(0.7, 0.85, 1.0) if is_unlocked else (Color(0.6, 0.7, 0.85) if can_unlock else Color(0.4, 0.45, 0.6)))
		tl.add_theme_font_size_override("font_size", 12)
		card.add_child(tl)

		var dl := Label.new()
		dl.text = str(node.get("desc", ""))
		dl.position = Vector2(8, 20); dl.size = Vector2(230, 30)
		dl.add_theme_color_override("font_color", Color(0.4, 0.5, 0.7))
		dl.add_theme_font_size_override("font_size", 10)
		card.add_child(dl)

		if not is_unlocked and can_unlock:
			var ub := _btn("解锁(%d)" % cost, Vector2(130, 46), Vector2(108, 22))
			ub.add_theme_font_size_override("font_size", 10)
			var k := nid
			ub.pressed.connect(_unlock_node.bind(k))
			card.add_child(ub)
		elif is_unlocked:
			var ul := Label.new()
			ul.text = "已解锁"; ul.position = Vector2(130, 46)
			ul.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))
			ul.add_theme_font_size_override("font_size", 11)
			card.add_child(ul)


func _select_preset(preset_id: String) -> void:
	"""
	预设推荐：逐节点检查 can_unlock，技能点够就逐个解锁。
	不再用 grant 批量注入，避免绕过前置门槛把所有触发挂钩都解锁。
	"""
	var pdata := Skills.preset(preset_id)
	if pdata.is_empty():
		return
	var ids: Array = pdata.get("nodes", [])
	var unlocked: Array = Global.data.get("unlocked_skills", [])
	var pts: int = Global.data.get("skill_points", 0)
	var cost_sum := 0
	var actual_unlock := 0

	# 一轮尝试：最多循环 5 轮解决依赖顺序问题
	for _round in 5:
		var changed := false
		for nid in ids:
			if int(nid) in unlocked:
				continue
			var node := Skills.by_id(int(nid))
			if node.is_empty():
				continue
			var cost := int(node.get("cost", 1))
			if Skills.can_unlock(unlocked, int(nid), pts):
				unlocked.append(int(nid))
				pts -= cost
				cost_sum += cost
				actual_unlock += 1
				changed = true
		if not changed:
			break

	Global.data["unlocked_skills"] = unlocked
	Global.data["skill_points"] = pts
	Global.save_data()

	if actual_unlock > 0:
		_ctrl.get("node_grid")
	_refresh_nodes()


func _unlock_node(node_id: int) -> void:
	var unlocked: Array = Global.data.get("unlocked_skills", [])
	var node := Skills.by_id(node_id)
	if node.is_empty():
		return
	var cost := int(node.get("cost", 1))
	var pts: int = Global.data.get("skill_points", 0)
	if pts < cost:
		return
	if unlocked.has(node_id):
		return
	if not Skills.can_unlock(unlocked, node_id, pts):
		return
	unlocked.append(node_id)
	pts -= cost
	Global.data["unlocked_skills"] = unlocked
	Global.data["skill_points"] = pts
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
