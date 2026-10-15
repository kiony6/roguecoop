extends Control
## 主菜单：注册登录 + 天赋树 + 排行榜 + 设置（深色科幻风）

const Protocol := preload("res://net/protocol.gd")

var _username := ""
var _current_level := 0

var _talent_keys := ["hp", "damage", "speed", "crit", "atk_speed", "regen"]
var _talent_names := {
	"hp": "生命 +10", "damage": "伤害 +5%", "speed": "移速 +5%",
	"crit": "暴击 +3%", "atk_speed": "攻速 +5%", "regen": "回血 +1/级",
}
var _talent_costs := {
	"hp": 50, "damage": 50, "speed": 50, "crit": 80, "atk_speed": 80, "regen": 100,
}

var _ctrl: Dictionary = {}


func _ready() -> void:
	_setup_theme()
	_build_login()
	_build_menu()
	_build_levels()
	_build_lobby()
	_build_talent()
	_build_rank()
	_build_settings()
	Net.connected_ok.connect(_on_connected, CONNECT_ONE_SHOT)
	Net.connection_failed.connect(_on_connection_failed)
	_show("login")
	Global.load_data()


# ── 主题 ──
func _setup_theme() -> void:
	ThemeDB.fallback_font_size = 16


func _panel(pos: Vector2, size2: Vector2) -> Panel:
	var p := Panel.new()
	p.position = pos; p.size = size2
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.04, 0.06, 0.12, 0.92)
	s.border_color = Color(0.2, 0.5, 1.0, 0.6)
	s.border_width_top = 1; s.border_width_bottom = 1
	s.border_width_left = 1; s.border_width_right = 1
	s.corner_radius_top_left = 8; s.corner_radius_top_right = 8
	s.corner_radius_bottom_left = 8; s.corner_radius_bottom_right = 8
	p.add_theme_stylebox_override("panel", s)
	return p

func _btn(text: String, pos: Vector2, size2: Vector2) -> Button:
	var b := Button.new()
	b.text = text; b.position = pos; b.size = size2
	b.add_theme_font_size_override("font_size", 15)
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.08, 0.12, 0.25, 0.9)
	s.border_color = Color(0.3, 0.6, 1.0, 0.5)
	s.border_width_top = 1; s.border_width_bottom = 1
	s.border_width_left = 1; s.border_width_right = 1
	s.corner_radius_top_left = 6; s.corner_radius_top_right = 6
	s.corner_radius_bottom_left = 6; s.corner_radius_bottom_right = 6
	b.add_theme_stylebox_override("normal", s)
	var sh := StyleBoxFlat.new()
	sh.bg_color = Color(0.15, 0.2, 0.4, 0.95)
	sh.border_color = Color(0.5, 0.8, 1.0, 0.8)
	sh.border_width_top = 1; sh.border_width_bottom = 1
	sh.border_width_left = 1; sh.border_width_right = 1
	sh.corner_radius_top_left = 6; sh.corner_radius_top_right = 6
	sh.corner_radius_bottom_left = 6; sh.corner_radius_bottom_right = 6
	b.add_theme_stylebox_override("hover", sh)
	b.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	return b

func _label(text: String, pos: Vector2, color: Color = Color(0.7, 0.85, 1.0), size2: int = 16) -> Label:
	var l := Label.new()
	l.text = text; l.position = pos
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", size2)
	return l

func _go_back() -> void: _show("menu")
func _show(page: String) -> void:
	for k in _ctrl:
		if k.begins_with("page_"):
			var p = _ctrl.get(k)
			if p is Control:
				p.visible = k == "page_" + page


# ═══════════════ 登录 / 注册 ═══════════════

func _build_login() -> void:
	var p := _panel(Vector2(420, 180), Vector2(440, 360))
	p.name = "page_login"; add_child(p); _ctrl["page_login"] = p
	_label("RogueCoop · 生存代码", Vector2(60, 30), Color(0.3, 0.7, 1.0), 24)
	_label("账号", Vector2(60, 100), Color(0.6, 0.8, 1.0), 14)

	var uf := LineEdit.new()
	uf.position = Vector2(60, 125); uf.size = Vector2(320, 35); uf.placeholder_text = "输入账号"
	uf.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	uf.add_theme_color_override("background_color", Color(0.06, 0.1, 0.2))
	uf.add_theme_constant_override("caret_width", 1)
	p.add_child(uf); _ctrl["login_user"] = uf

	_label("密码", Vector2(60, 170), Color(0.6, 0.8, 1.0), 14)
	var pf := LineEdit.new()
	pf.position = Vector2(60, 195); pf.size = Vector2(320, 35); pf.placeholder_text = "输入密码"
	pf.secret = true
	pf.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	pf.add_theme_color_override("background_color", Color(0.06, 0.1, 0.2))
	p.add_child(pf); _ctrl["login_pass"] = pf

	var lb := _btn("登  录", Vector2(60, 250), Vector2(150, 42))
	lb.pressed.connect(_do_login); p.add_child(lb)
	var rb := _btn("注  册", Vector2(230, 250), Vector2(150, 42))
	rb.pressed.connect(_do_register); p.add_child(rb)

	var msg := Label.new()
	msg.position = Vector2(60, 310); msg.size = Vector2(320, 30)
	msg.add_theme_color_override("font_color", Color(1, 0.6, 0.2))
	msg.add_theme_font_size_override("font_size", 14)
	p.add_child(msg); _ctrl["login_msg"] = msg


func _do_register() -> void:
	var u: String = _ctrl["login_user"].text.strip_edges()
	var pw: String = _ctrl["login_pass"].text.strip_edges()
	if u.is_empty() or pw.is_empty():
		_ctrl["login_msg"].text = "账号和密码不能为空"; return
	if not Global.register(u, pw):
		_ctrl["login_msg"].text = "注册失败（账号可能已存在）"; return
	_ctrl["login_msg"].text = "注册成功，请登录"


func _do_login() -> void:
	var u: String = _ctrl["login_user"].text.strip_edges()
	var pw: String = _ctrl["login_pass"].text.strip_edges()
	if u.is_empty() or pw.is_empty():
		_ctrl["login_msg"].text = "账号和密码不能为空"; return
	if not Global.login(u, pw):
		_ctrl["login_msg"].text = "账号或密码错误"; return
	_username = u; Global.nickname = u
	_ctrl["menu_nick"].text = "玩家: %s" % u
	_ctrl["shard_label"].text = "碎片: %d" % Global.data["shards"]
	_show("menu")


func _on_connected(_id: int) -> void: get_tree().change_scene_to_file("res://scenes/world.tscn")
func _on_connection_failed() -> void: _ctrl["lobby_info"].text = "连接失败"


# ═══════════════ 主菜单 ═══════════════

func _build_menu() -> void:
	var p := _panel(Vector2(440, 140), Vector2(400, 420))
	p.name = "page_menu"; p.visible = false; add_child(p); _ctrl["page_menu"] = p
	_label("主菜单", Vector2(40, 20), Color(0.3, 0.7, 1.0), 22)
	var nl := Label.new()
	nl.position = Vector2(40, 60); nl.size = Vector2(300, 25)
	nl.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	p.add_child(nl); _ctrl["menu_nick"] = nl
	var sl := Label.new()
	sl.position = Vector2(40, 90); sl.size = Vector2(300, 25)
	sl.add_theme_color_override("font_color", Color(1, 0.7, 0.3))
	p.add_child(sl); _ctrl["shard_label"] = sl

	var items := ["开始游戏", "天赋树", "排行榜", "联机大厅", "设置"]
	var funcs := [
		Callable(self, "_show_levels"),
		Callable(self, "_show_talent_panel"),
		Callable(self, "_show_rank_panel"),
		Callable(self, "_show_lobby_panel"),
		Callable(self, "_show_settings_panel"),
	]
	for i in items.size():
		var b := _btn(items[i], Vector2(40, 130 + i * 52), Vector2(300, 44))
		b.pressed.connect(funcs[i]); p.add_child(b)


func _show_levels() -> void: _show("levels")
func _start_level(idx: int) -> void: _current_level = idx; Global.current_level = idx; get_tree().change_scene_to_file("res://scenes/world.tscn")


# ═══════════════ 选关（含返回） ═══════════════

func _build_levels() -> void:
	var p := _panel(Vector2(320, 100), Vector2(640, 580))
	p.name = "page_levels"; p.visible = false; add_child(p); _ctrl["page_levels"] = p
	_label("选择关卡", Vector2(40, 20), Color(0.3, 0.7, 1.0), 24)
	var names := ["数据废墟", "病毒丛林", "故障深渊", "核心风暴", "终焉之地"]
	var descs := ["难度 ★☆☆☆☆\n初始关卡，适合新手热身", "难度 ★★☆☆☆\n敌人增强，掉落更多碎片",
		"难度 ★★★☆☆\nBoss 出现，考验装备", "难度 ★★★★☆\n密集弹幕，需要组合技", "难度 ★★★★★\n最终挑战，生存极限"]
	for i in 5:
		var b := _btn(names[i], Vector2(40, 100 + i * 85), Vector2(400, 70))
		var d := Label.new()
		d.text = descs[i]; d.position = Vector2(460, 105 + i * 85); d.size = Vector2(160, 60)
		d.add_theme_color_override("font_color", Color(0.5, 0.6, 0.8))
		d.add_theme_font_size_override("font_size", 11)
		p.add_child(b); p.add_child(d)
		b.pressed.connect(_start_level.bind(i))
	var bk := _btn("← 返回", Vector2(40, 510), Vector2(160, 45))
	bk.pressed.connect(_go_back); p.add_child(bk)


# ═══════════════ 联机大厅（含返回） ═══════════════

func _build_lobby() -> void:
	var p := _panel(Vector2(320, 100), Vector2(640, 580))
	p.name = "page_lobby"; p.visible = false; add_child(p); _ctrl["page_lobby"] = p
	_label("联机大厅", Vector2(40, 20), Color(0.3, 0.7, 1.0), 24)
	var li := Label.new()
	li.position = Vector2(40, 65); li.size = Vector2(560, 25)
	li.add_theme_color_override("font_color", Color(1, 0.6, 0.2))
	p.add_child(li); _ctrl["lobby_info"] = li
	var hb := _btn("建立主机", Vector2(40, 110), Vector2(200, 50))
	hb.pressed.connect(_on_host_pressed); p.add_child(hb)
	var ipf := LineEdit.new()
	ipf.position = Vector2(260, 115); ipf.size = Vector2(340, 35)
	ipf.text = "127.0.0.1"; ipf.placeholder_text = "主机 IP"
	ipf.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	ipf.add_theme_color_override("background_color", Color(0.06, 0.1, 0.2))
	p.add_child(ipf); _ctrl["lobby_ip"] = ipf
	var jb := _btn("加入房间", Vector2(260, 165), Vector2(200, 50))
	jb.pressed.connect(_on_join_pressed); p.add_child(jb)

	_label("房主输入 127.0.0.1，队友输入房主公网 IP", Vector2(40, 230), Color(0.4, 0.5, 0.7), 11)
	var bk := _btn("← 返回", Vector2(40, 510), Vector2(160, 45))
	bk.pressed.connect(_go_back); p.add_child(bk)


func _show_lobby_panel() -> void: _ctrl["lobby_info"].text = ""; _show("lobby")
func _on_host_pressed() -> void:
	Net.set_websocket(false)
	var err := Net.host_start(Protocol.DEFAULT_PORT)
	if err != OK: _ctrl["lobby_info"].text = "建立主机失败"; return
	get_tree().change_scene_to_file("res://scenes/world.tscn")
func _on_join_pressed() -> void:
	var ip_str: String = _ctrl["lobby_ip"].text.strip_edges()
	if ip_str.is_empty(): ip_str = "127.0.0.1"
	Net.set_websocket(false)
	var err := Net.client_connect(ip_str, Protocol.DEFAULT_PORT)
	if err != OK: _ctrl["lobby_info"].text = "发起连接失败"; return
	_ctrl["lobby_info"].text = "正在连接 %s:%d…" % [ip_str, Protocol.DEFAULT_PORT]


# ═══════════════ 天赋树（含返回） ═══════════════

func _build_talent() -> void:
	var p := _panel(Vector2(340, 80), Vector2(600, 560))
	p.name = "page_talent"; p.visible = false; add_child(p); _ctrl["page_talent"] = p

func _show_talent_panel() -> void:
	var p = _ctrl["page_talent"]; _clear_page(p)
	_label("天赋树", Vector2(20, 20), Color(0.3, 0.7, 1.0), 24)
	var sl := Label.new()
	sl.text = "碎片: %d" % Global.data["shards"]; sl.position = Vector2(20, 55)
	sl.add_theme_color_override("font_color", Color(1, 0.7, 0.3))
	sl.add_theme_font_size_override("font_size", 16); p.add_child(sl)
	for key in _talent_keys:
		var lv := Global.talent_level(key)
		var cost: int = _talent_costs.get(key, 50) * (1 + lv); var y := 90 + _talent_keys.find(key) * 65
		var nl := Label.new()
		nl.text = _talent_names.get(key, key); nl.position = Vector2(20, y)
		nl.size = Vector2(300, 40); nl.add_theme_font_size_override("font_size", 15); p.add_child(nl)
		var ll := Label.new()
		ll.text = "Lv.%d  " % lv; ll.position = Vector2(320, y); ll.size = Vector2(50, 40)
		ll.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0)); p.add_child(ll)
		var b := _btn("升级(%d碎)" % cost, Vector2(400, y), Vector2(160, 40))
		var can_up: bool = lv < 10 and Global.data["shards"] >= cost; b.disabled = not can_up
		var k: String = key
		b.pressed.connect(_upgrade_talent.bind(k)); p.add_child(b)
	var back := _btn("← 返回", Vector2(20, 500), Vector2(160, 45))
	back.pressed.connect(_go_back); _show("talent")

func _upgrade_talent(key: String) -> void:
	var cost: int = _talent_costs.get(key, 50) * (1 + Global.talent_level(key))
	Global.upgrade_talent(key, cost); _show_talent_panel()


# ═══════════════ 排行榜（含返回） ═══════════════

func _build_rank() -> void:
	var p := _panel(Vector2(340, 80), Vector2(600, 560))
	p.name = "page_rank"; p.visible = false; add_child(p); _ctrl["page_rank"] = p

func _show_rank_panel() -> void:
	var p = _ctrl["page_rank"]; _clear_page(p)
	_label("排行榜", Vector2(20, 20), Color(1, 0.7, 0.3), 24)
	var scores: Array = Global.data["scores"]
	if scores.size() == 0:
		var e := Label.new()
		e.text = "暂无记录，先去打一局吧！"; e.position = Vector2(20, 65)
		e.add_theme_color_override("font_color", Color(0.5, 0.6, 0.8))
		e.add_theme_font_size_override("font_size", 14); p.add_child(e)
	else:
		var hdr := Label.new()
		hdr.text = "排  名      玩  家           击  杀     等  级"
		hdr.position = Vector2(20, 65); hdr.size = Vector2(540, 25)
		hdr.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
		p.add_child(hdr)
		for i in mini(20, scores.size()):
			var s: Dictionary = scores[i]
			var row := Label.new()
			var top := i == 0
			var col := Color(1, 0.7, 0.3) if top else Color(0.7, 0.85, 1.0)
			var medal: String = ["🥇", "🥈", "🥉"][i] if i < 3 else "#%d" % (i + 1)
			row.text = "%s      %-12s     %-6d    Lv.%d" % [medal, s.get("name", "?"), s.get("kills", 0), s.get("level", 1)]
			row.position = Vector2(20, 95 + i * 22); row.size = Vector2(540, 20)
			row.add_theme_color_override("font_color", col)
			row.add_theme_font_size_override("font_size", 13); p.add_child(row)
	var back := _btn("← 返回", Vector2(20, 500), Vector2(160, 45))
	back.pressed.connect(_go_back); _show("rank")


# ═══════════════ 设置（含返回） ═══════════════

func _build_settings() -> void:
	var p := _panel(Vector2(340, 100), Vector2(600, 500))
	p.name = "page_settings"; p.visible = false; add_child(p); _ctrl["page_settings"] = p

func _show_settings_panel() -> void:
	var p = _ctrl["page_settings"]; _clear_page(p)
	_label("设  置", Vector2(20, 20), Color(0.3, 0.7, 1.0), 24)

	var nl := Label.new()
	nl.text = "当前昵称: %s" % Global.nickname; nl.position = Vector2(20, 70); nl.size = Vector2(300, 25)
	nl.add_theme_font_size_override("font_size", 15); p.add_child(nl)
	var nf := LineEdit.new()
	nf.text = Global.nickname; nf.position = Vector2(20, 100); nf.size = Vector2(300, 35)
	nf.placeholder_text = "输入新昵称"
	nf.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	nf.add_theme_color_override("background_color", Color(0.06, 0.1, 0.2))
	p.add_child(nf)
	var nb := _btn("修改昵称", Vector2(340, 100), Vector2(160, 35))
	nb.pressed.connect(func():
		var nn: String = nf.text.strip_edges()
		if not nn.is_empty(): Global.nickname = nn; nl.text = "当前昵称: %s" % nn
	); p.add_child(nb)

	var sl := Label.new()
	sl.text = "碎片余额: %d" % Global.data["shards"]; sl.position = Vector2(20, 160); sl.size = Vector2(300, 25)
	sl.add_theme_color_override("font_color", Color(1, 0.7, 0.3)); sl.add_theme_font_size_override("font_size", 15); p.add_child(sl)

	var al := Label.new()
	al.text = "账号: " + (_username if not _username.is_empty() else "未登录")
	al.position = Vector2(20, 200); al.size = Vector2(300, 25)
	al.add_theme_font_size_override("font_size", 14); p.add_child(al)

	# 存档操作
	_label("存档管理", Vector2(20, 260), Color(0.5, 0.8, 1.0), 18)
	var reset_btn := _btn("⚠ 重置全部存档", Vector2(20, 290), Vector2(240, 45))
	reset_btn.pressed.connect(func():
		Global.reset_all(); sl.text = "碎片余额: %d" % Global.data["shards"]
		_ctrl["shard_label"].text = "碎片: %d" % Global.data["shards"]
	); p.add_child(reset_btn)

	var about := Label.new()
	about.text = "RogueCoop v1.0\n肉鸽联机合作割草 · Godot 4.7"
	about.position = Vector2(20, 370); about.size = Vector2(300, 40)
	about.add_theme_color_override("font_color", Color(0.35, 0.4, 0.55))
	about.add_theme_font_size_override("font_size", 11); p.add_child(about)

	var back := _btn("← 返回主菜单", Vector2(20, 440), Vector2(200, 45))
	back.pressed.connect(_go_back); _show("settings")


# ── 工具 ──
func _clear_page(p: Panel) -> void:
	for c in p.get_children(): c.queue_free()
