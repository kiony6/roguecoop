extends Node
## 全局游戏状态和存档，autoload 名为 Global

var current_level := 0
var nickname := ""

# ── 存档数据 ──
var data := {
	"shards": 0,      # 碎片（天赋币）
	"scores": [],     # 排行榜 [{name, level, kills, time, wave}]
	# 天赋等级（0=未解锁，最高叠加）
	"talents": {
		"hp": 0, "damage": 0, "speed": 0, "crit": 0,
		"atk_speed": 0, "regen": 0, "unlocked": 0,
	},
}

const SAVE_PATH := "user://save_roguecoop.json"


func _ready() -> void:
	load_data()


func load_data() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var raw: String = file.get_as_text()
	var parsed = JSON.parse_string(raw)
	if typeof(parsed) == TYPE_DICTIONARY:
		_merge(data, parsed as Dictionary)
	file.close()


func save_data() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()


func _merge(target: Dictionary, source: Dictionary) -> void:
	for k in source:
		if k in target:
			if target[k] is Dictionary and source[k] is Dictionary:
				_merge(target[k], source[k])
			else:
				target[k] = source[k]


func add_score(entry: Dictionary) -> void:
	data["scores"].append(entry)
	data["scores"].sort_custom(
		func(a, b): return int(a.get("kills", 0)) > int(b.get("kills", 0))
	)
	if data["scores"].size() > 100:
		data["scores"] = data["scores"].slice(0, 100)
	save_data()


func add_shards(amount: int) -> void:
	data["shards"] += amount
	save_data()


func talent_level(key: String) -> int:
	return int(data["talents"].get(key, 0))


func upgrade_talent(key: String, cost: int) -> bool:
	if data["shards"] < cost:
		return false
	if key not in data["talents"]:
		return false
	if data["talents"][key] >= 10:
		return false
	data["shards"] -= cost
	data["talents"][key] = int(data["talents"][key]) + 1
	save_data()
	return true
