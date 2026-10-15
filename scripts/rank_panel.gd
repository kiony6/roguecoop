extends Control
## 排行榜面板

@onready var _list: VBoxContainer = $VBoxContainer


func _ready() -> void:
	$BackBtn.pressed.connect(_on_back)
	refresh()


func refresh() -> void:
	# 清空旧列表（保留前两个子节点：标题和返回按钮）
	for c in _list.get_children():
		if c.name != "Title" and c.name != "BackBtn":
			c.queue_free()
	
	var scores: Array = Global.data["scores"]
	if scores.size() == 0:
		var empty := Label.new()
		empty.text = "暂无记录"
		empty.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		_list.add_child(empty)
		return
	
	for i in mini(20, scores.size()):
		var s: Dictionary = scores[i]
		var hb := HBoxContainer.new()
		
		var rank := Label.new()
		rank.text = "#%d" % (i + 1)
		rank.custom_minimum_size.x = 40
		hb.add_child(rank)
		
		var name_label := Label.new()
		name_label.text = str(s.get("name", "无名"))
		name_label.size_flags_horizontal = SIZE_EXPAND
		hb.add_child(name_label)
		
		var kills := Label.new()
		kills.text = "击杀 %d" % int(s.get("kills", 0))
		kills.custom_minimum_size.x = 100
		hb.add_child(kills)
		
		var level := Label.new()
		level.text = "等级 %d" % int(s.get("level", 1))
		level.custom_minimum_size.x = 80
		hb.add_child(level)
		
		_list.add_child(hb)


func _on_back() -> void:
	visible = false
	get_parent().get_node("MenuPanel").visible = true
