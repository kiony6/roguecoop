extends Node
## 局域网房间匹配：UDP 广播发现，房间号配对，不需要输入 IP

signal room_created(code: String)
signal room_joined(host_ip: String, port: int)
signal match_error(msg: String)

const BROADCAST_PORT := 25601
const GAME_PORT := 25600
const ROOM_CODE_LENGTH := 4

var _udp := PacketPeerUDP.new()
var _is_host := false
var _room_code := ""
var _host_ip := ""
var _scanning := false


func create_room() -> void:
	# 生成 4 位随机房间号
	_room_code = ""
	for i in ROOM_CODE_LENGTH:
		_room_code += str(randi() % 10)
	_is_host = true
	# 起 ENet 主机
	Net.set_websocket(false)
	var err := Net.host_start(GAME_PORT)
	if err != OK:
		match_error.emit("建立主机失败：错误码 %d" % err)
		return
	# 开始在广播端口上响应查询
	_udp.close()
	_udp.bind(BROADCAST_PORT)
	room_created.emit(_room_code)


func join_room(code: String) -> void:
	if code.length() != ROOM_CODE_LENGTH:
		match_error.emit("房间号必须是 %d 位数字" % ROOM_CODE_LENGTH)
		return
	_room_code = code
	_is_host = false
	_scanning = true
	# 广播查询：搜索局域网内的主机
	_udp.close()
	_udp.set_broadcast_enabled(true)
	_udp.bind(BROADCAST_PORT + 1)
	# 发 3 次广播搜索
	for i in 3:
		var query := "ROGUE_FIND " + _room_code
		_udp.put_var(query.to_utf8_buffer())
		_udp.set_destination_address("255.255.255.255", BROADCAST_PORT)
		await get_tree().create_timer(0.3).timeout


func _process(_delta: float) -> void:
	if not _scanning and not _is_host:
		return
	while _udp.get_available_packet_count() > 0:
		var data: PackedByteArray = _udp.get_packet()
		var ip: String = _udp.get_packet_ip()
		var text: String = data.get_string_from_utf8()
		_handle_packet(text, ip)


func _handle_packet(text: String, ip: String) -> void:
	if _is_host and text.begins_with("ROGUE_FIND "):
		var code := text.substr(11).strip_edges()
		if code == _room_code:
			# 回复主机信息
			var reply := "ROGUE_HOST " + _room_code
			_udp.set_destination_address(ip, BROADCAST_PORT + 1)
			_udp.put_var(reply.to_utf8_buffer())
	elif not _is_host and _scanning and text.begins_with("ROGUE_HOST "):
		var code := text.substr(11).strip_edges()
		if code == _room_code:
			_host_ip = ip
			_scanning = false
			_udp.close()
			# 连上主机
			var err := Net.client_connect(_host_ip, GAME_PORT)
			if err != OK:
				match_error.emit("连接失败")
				return
			room_joined.emit(_host_ip, GAME_PORT)


func stop() -> void:
	_scanning = false
	_udp.close()
