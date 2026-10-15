extends Control
## 主菜单总控：登录 → 主菜单 → 选关 / 联机大厅

const Protocol := preload("res://net/protocol.gd")

var _nickname := ""
var _selected_level := 0

@onready var _login_panel: Panel = $LoginPanel
@onready var _menu_panel: Panel = $MenuPanel
@onready var _level_panel: Panel = $LevelPanel
@onready var _lobby_panel: Panel = $LobbyPanel

@onready var _nick_field: LineEdit = $LoginPanel/NickField
@onready var _nick_display: Label = $MenuPanel/NickDisplay
@onready var _lobby_info: Label = $LobbyPanel/LobbyInfo
@onready var _lobby_ip: LineEdit = $LobbyPanel/LobbyIpField


func _ready() -> void:
	# 登录
	$LoginPanel/LoginBtn.pressed.connect(_on_login)
	_nick_field.text_submitted.connect(func(_t): _on_login())

	# 主菜单
	$MenuPanel/StartBtn.pressed.connect(_show_level_select)
	$MenuPanel/LobbyBtn.pressed.connect(_show_lobby)

	# 选关
	for i in 5:
		var btn := Button.new()
		btn.name = "LevelBtn%d" % i
		btn.custom_minimum_size = Vector2(560, 50)
		var names := ["数据废墟", "病毒丛林", "故障深渊", "核心风暴", "终焉之地"]
		btn.text = "第 %d 关: %s" % [i + 1, names[i]]
		btn.pressed.connect(_on_level_selected.bind(i))
		$LevelPanel.add_child(btn)

	# 大厅
	$LobbyPanel/LobbyHostBtn.pressed.connect(_on_host_pressed)
	$LobbyPanel/LobbyJoinBtn.pressed.connect(_on_join_pressed)
	$LobbyPanel/LobbyBackBtn.pressed.connect(_show_menu)

	Net.connected_ok.connect(_on_connected, CONNECT_ONE_SHOT)
	Net.connection_failed.connect(_on_connection_failed)

	_show_login()


func _show_login() -> void:
	_login_panel.visible = true
	_menu_panel.visible = false
	_level_panel.visible = false
	_lobby_panel.visible = false


func _show_menu() -> void:
	_login_panel.visible = false
	_menu_panel.visible = true
	_level_panel.visible = false
	_lobby_panel.visible = false


func _show_level_select() -> void:
	_menu_panel.visible = false
	_level_panel.visible = true
	_lobby_panel.visible = false


func _show_lobby() -> void:
	_menu_panel.visible = false
	_lobby_panel.visible = true
	_lobby_info.text = ""


func _on_login() -> void:
	var nick := _nick_field.text.strip_edges()
	if nick.is_empty():
		return
	_nickname = nick
	_nick_display.text = "玩家: %s" % _nickname
	_show_menu()


func _on_level_selected(idx: int) -> void:
	_selected_level = idx
	Global.current_level = idx
	get_tree().change_scene_to_file("res://scenes/world.tscn")


func _on_host_pressed() -> void:
	Net.set_websocket(false)
	var err := Net.host_start(Protocol.DEFAULT_PORT)
	if err != OK:
		_lobby_info.text = "建立主机失败：错误码 %d" % err
		return
	get_tree().change_scene_to_file("res://scenes/world.tscn")


func _on_join_pressed() -> void:
	var ip := _lobby_ip.text.strip_edges()
	if ip.is_empty():
		ip = "127.0.0.1"
	var port := Protocol.DEFAULT_PORT
	Net.set_websocket(false)
	var err := Net.client_connect(ip, port)
	if err != OK:
		_lobby_info.text = "发起连接失败：错误码 %d" % err
		return
	_lobby_info.text = "正在连接 %s:%d（UDP）…" % [ip, port]


func _on_connected(_local_id: int) -> void:
	get_tree().change_scene_to_file("res://scenes/world.tscn")


func _on_connection_failed() -> void:
	_lobby_info.text = "连接失败（主机未开或网络不通）"
