extends Control
## 主菜单：全部 UI 用代码生成，不依赖 tscn 解析

const Protocol := preload("res://net/protocol.gd")

var _nickname := ""
var _current_level := 0

# 天赋树数据
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
	# 先建好所有面板，再绑定信号
	_build_login()
	_build_menu()
	_build_levels()
	_build_lobby()
	_build_talent()
	_build_rank()

	Net.connected_ok.connect(_on_connected, CONNECT_ONE_SHOT)
	Net.connection_failed.connect(_on_connection_failed)

	_show("login")
	Global.load_data()


# ── 工具 ──
func _show(page: String) -> void:
	for k in _ctrl:
		if k.begins_with("page_"):
			var p = _ctrl.get(k)
			if p is Control:
				p.visible = k == "page_" + page


func _btn(text: String, pos: Vector2, size2: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = size2
	return b


func _label(text: String, pos: Vector2, color: Color = Color.WHITE, size2: int = 16) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", size2)
	return l


# ── 登录页 ──
func _build_login() -> void:
	var p := Panel.new()
	p.position = Vector2(440, 240)
	p.size = Vector2(400, 220)
	p.name = "page_login"
	add_child(p)

	_label("RogueCoop · 肉鸽联机割草", Vector2(40, 20), Color.CYAN, 22)
	var nl := Label.new()
	nl.text = "输入昵称："
	nl.position = Vector2(40, 100)
	p.add_child(nl)

	var nf := LineEdit.new()
	nf.position = Vector2(40, 135)
	nf.size = Vector2(320, 35)
	nf.placeholder_text = "你的昵称"
	nf.text_submitted.connect(_on_login)
	p.add_child(nf)
	_ctrl["nick_field"] = nf

	var lb := _btn("进入游戏", Vector2(40, 200), Vector2(160, 40))
	lb.pressed.connect(_on_login)
	p.add_child(lb)
	_ctrl["login_panel"] = p


func _on_login() -> void:
	var nick = _ctrl["nick_field"].text.strip_edges()
	if nick.is_empty():
		return
	_nickname = nick
	Global.nickname = nick
	_ctrl["menu_nick"].text = "玩家: %s" % nick
	_ctrl["shard_label"].text = "碎片: %d" % Global.data["shards"]
	_show("menu")


# ── 主菜单 ──
func _build_menu() -> void:
	var p := Panel.new()
	p.position = Vector2(440, 160)
	p.size = Vector2(400, 320)
	p.name = "page_menu"
	p.visible = false
	add_child(p)

	_label("主菜单", Vector2(40, 20), Color.WHITE, 22)
	var nl := Label.new()
	nl.position = Vector2(40, 70)
	nl.size = Vector2(300, 25)
	p.add_child(nl)
	_ctrl["menu_nick"] = nl

	var sl := Label.new()
	sl.position = Vector2(40, 360)
	sl.size = Vector2(300, 25)
	sl.add_theme_color_override("font_color", Color(1, 0.7, 0.3))
	p.add_child(sl)
	_ctrl["shard_label"] = sl

	var items := ["开始游戏", "天赋树", "排行榜", "联机大厅"]
	var funcs := [
		Callable(self, "_show_levels"),
		Callable(self, "_show_talent_panel"),
		Callable(self, "_show_rank_panel"),
		Callable(self, "_show_lobby_panel"),
	]
	for i in items.size():
		var b := Button.new()
		b.text = items[i]
		b.position = Vector2(40, 120 + i * 60)
		b.size = Vector2(260, 45)
		b.pressed.connect(funcs[i])
		p.add_child(b)

	_ctrl["page_menu"] = p


# ── 选关 ──
func _build_levels() -> void:
	var p := Panel.new()
	p.position = Vector2(320, 100)
	p.size = Vector2(640, 580)
	p.name = "page_levels"
	p.visible = false
	add_child(p)

	_label("选择关卡", Vector2(40, 20), Color.WHITE, 24)
	var names := ["数据废墟", "病毒丛林", "故障深渊", "核心风暴", "终焉之地"]
	for i in 5:
		var b := Button.new()
		b.text = "第 %d 关: %s" % [i + 1, names[i]]
		b.position = Vector2(40, 100 + i * 70)
		b.size = Vector2(560, 55)
		b.pressed.connect(_start_level.bind(i))
		p.add_child(b)
	var bk := _btn("返回", Vector2(40, 510), Vector2(200, 45))
	bk.pressed.connect(func(): _show("menu"))
	p.add_child(bk)
	_ctrl["page_levels"] = p


func _show_levels() -> void: _show("levels")
func _start_level(idx: int) -> void:
	_current_level = idx
	Global.current_level = idx
	get_tree().change_scene_to_file("res://scenes/world.tscn")


# ── 联机大厅 ──
func _build_lobby() -> void:
	var p := Panel.new()
	p.position = Vector2(320, 100)
	p.size = Vector2(640, 580)
	p.name = "page_lobby"
	p.visible = false
	add_child(p)

	_label("联机大厅", Vector2(40, 20), Color.WHITE, 24)
	var li := Label.new()
	li.position = Vector2(40, 70)
	li.size = Vector2(560, 25)
	p.add_child(li)
	_ctrl["lobby_info"] = li

	var hb := _btn("建立主机", Vector2(40, 120), Vector2(200, 50))
	hb.pressed.connect(_on_host_pressed)
	p.add_child(hb)

	var ipf := LineEdit.new()
	ipf.position = Vector2(260, 120)
	ipf.size = Vector2(340, 35)
	ipf.text = "127.0.0.1"
	ipf.placeholder_text = "主机 IP"
	p.add_child(ipf)
	_ctrl["lobby_ip"] = ipf

	var jb := _btn("加入房间", Vector2(260, 170), Vector2(200, 50))
	jb.pressed.connect(_on_join_pressed)
	p.add_child(jb)

	var bk := _btn("返回", Vector2(40, 510), Vector2(200, 45))
	bk.pressed.connect(func(): _show("menu"))
	p.add_child(bk)
	_ctrl["page_lobby"] = p


func _show_lobby_panel() -> void:
	_ctrl["lobby_info"].text = ""
	_show("lobby")


func _on_host_pressed() -> void:
	Net.set_websocket(false)
	var err := Net.host_start(Protocol.DEFAULT_PORT)
	if err != OK:
		_ctrl["lobby_info"].text = "建立主机失败：错误码 %d" % err
		return
	get_tree().change_scene_to_file("res://scenes/world.tscn")


func _on_join_pressed() -> void:
	var ip_str: String = _ctrl["lobby_ip"].text.strip_edges()
	if ip_str.is_empty():
		ip_str = "127.0.0.1"
	Net.set_websocket(false)
	var err := Net.client_connect(ip_str, Protocol.DEFAULT_PORT)
	if err != OK:
		_ctrl["lobby_info"].text = "发起连接失败：错误码 %d" % err
		return
	_ctrl["lobby_info"].text = "正在连接 %s:%d…" % [ip_str, Protocol.DEFAULT_PORT]


func _on_connected(_id: int) -> void:
	get_tree().change_scene_to_file("res://scenes/world.tscn")


func _on_connection_failed() -> void:
	_ctrl["lobby_info"].text = "连接失败（主机未开或网络不通）"


# ── 天赋树 ──
func _build_talent() -> void:
	var p := Panel.new()
	p.position = Vector2(340, 80)
	p.size = Vector2(600, 560)
	p.name = "page_talent"
	p.visible = false
	add_child(p)
	_ctrl["page_talent"] = p


func _show_talent_panel() -> void:
	var p = _ctrl["page_talent"]
	_clear_page("page_talent")
	_label("天赋树", Vector2(20, 20), Color(1, 0.7, 0.3), 22)

	var sl := Label.new()
	sl.text = "碎片: %d" % Global.data["shards"]
	sl.position = Vector2(20, 50)
	sl.add_theme_color_override("font_color", Color(1, 0.7, 0.3))
	p.add_child(sl)

	for key in _talent_keys:
		var lv := Global.talent_level(key)
		var cost: int = _talent_costs.get(key, 50) * (1 + lv)
		var y := 90 + _talent_keys.find(key) * 60

		var nl := Label.new()
		nl.text = _talent_names.get(key, key)
		nl.position = Vector2(20, y)
		nl.size = Vector2(300, 40)
		p.add_child(nl)

		var ll := Label.new()
		ll.text = "Lv.%d" % lv
		ll.position = Vector2(330, y)
		ll.size = Vector2(50, 40)
		p.add_child(ll)

		var b := Button.new()
		var can_up: bool = lv < 10 and Global.data["shards"] >= cost
		b.text = "升级(%d碎)" % cost
		b.disabled = not can_up
		b.position = Vector2(400, y)
		b.size = Vector2(160, 40)
		var k: String = key
		b.pressed.connect(_upgrade_talent.bind(k))
		p.add_child(b)

	var back := _btn("返回", Vector2(20, 500), Vector2(160, 40))
	back.pressed.connect(func(): _show("menu"))
	_show("talent")


func _upgrade_talent(key: String) -> void:
	var cost: int = _talent_costs.get(key, 50) * (1 + Global.talent_level(key))
	Global.upgrade_talent(key, cost)
	_show_talent_panel()


# ── 排行榜 ──
func _build_rank() -> void:
	var p := Panel.new()
	p.position = Vector2(340, 80)
	p.size = Vector2(600, 560)
	p.name = "page_rank"
	p.visible = false
	add_child(p)
	_ctrl["page_rank"] = p


func _show_rank_panel() -> void:
	_clear_page("page_rank")
	_label("排行榜", Vector2(20, 20), Color.YELLOW, 22)

	var scores: Array = Global.data["scores"]
	if scores.size() == 0:
		var e := Label.new()
		e.text = "暂无记录"
		e.position = Vector2(20, 60)
		e.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		_ctrl["page_rank"].add_child(e)
	else:
		var header := Label.new()
		header.text = "排名 | 玩家 | 击杀 | 等级"
		header.position = Vector2(20, 60)
		_ctrl["page_rank"].add_child(header)

		for i in mini(20, scores.size()):
			var s: Dictionary = scores[i]
			var row := Label.new()
			row.text = "#%d  %s  击杀 %d  等级 %d" % [i + 1, s.get("name", "?"), s.get("kills", 0), s.get("level", 1)]
			row.position = Vector2(20, 90 + i * 22)
			row.size = Vector2(540, 20)
			_ctrl["page_rank"].add_child(row)

	var back := _btn("返回", Vector2(20, 500), Vector2(160, 40))
	back.pressed.connect(func(): _show("menu"))
	_show("rank")


func _clear_page(page_key: String) -> void:
	var p = _ctrl.get(page_key)
	if p == null:
		return
	for c in p.get_children():
		c.queue_free()
