extends Panel
## 天赋树面板

var _talent_keys := ["hp", "damage", "speed", "crit", "atk_speed", "regen"]
var _talent_names := {
	"hp": "生命 +10", "damage": "伤害 +5%", "speed": "移速 +5%",
	"crit": "暴击 +3%", "atk_speed": "攻速 +5%", "regen": "回血 +1/级",
}
var _talent_costs := {
	"hp": 50, "damage": 50, "speed": 50, "crit": 80, "atk_speed": 80, "regen": 100,
}

@onready var _tab: Panel = $".."


func _ready() -> void:
	$BackBtn.pressed.connect(_on_back)
	refresh()


func refresh() -> void:
	$ShardLabel.text = "碎片: %d" % Global.data["shards"]
	for c in get_children():
		if c.name in ["ShardLabel", "BackBtn"]:
			continue
		c.queue_free()
	
	for key in _talent_keys:
		var lv := Global.talent_level(key)
		var cost := _talent_costs.get(key, 50) * (1 + lv)
		var hb := HBoxContainer.new()
		hb.position = Vector2(20, 80 + _talent_keys.find(key) * 60)
		hb.size = Vector2(540, 45)
		add_child(hb)
		
		var nl := Label.new()
		nl.text = _talent_names.get(key, key)
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(nl)
		
		var ll := Label.new()
		ll.text = "Lv.%d" % lv
		ll.custom_minimum_size.x = 50
		hb.add_child(ll)
		
		var btn := Button.new()
		var can := lv < 10 and Global.data["shards"] >= cost
		btn.text = "升级(%d碎)" % cost
		btn.disabled = not can
		var k := key
		btn.pressed.connect(_upgrade_talent.bind(k))
		hb.add_child(btn)


func _upgrade_talent(key: String) -> void:
	var lv := Global.talent_level(key)
	var cost := _talent_costs.get(key, 50) * (1 + lv)
	Global.upgrade_talent(key, cost)
	refresh()


func _on_back() -> void:
	visible = false
	_tab.get_node("MenuPanel").visible = true
