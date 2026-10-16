extends Node
## 全局游戏状态，autoload 名为 Global。含账号/存档/设置。

var current_level := 0
var nickname := ""

var data := {
	"shards": 0,
	"scores": [],
	"talents": {"hp": 0, "damage": 0, "speed": 0, "crit": 0, "atk_speed": 0, "regen": 0},
	"accounts": {},
	"unlocked_skills": [],
	"skill_points": 0,
}

const SAVE_PATH := "user://save_roguecoop.json"


func _ready() -> void: load_data()


func load_data() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null: return
	var raw: String = file.get_as_text()
	var parsed = JSON.parse_string(raw)
	if typeof(parsed) == TYPE_DICTIONARY:
		_merge(data, parsed as Dictionary)
	file.close()


func save_data() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null: return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()


func reset_all() -> void:
	data["shards"] = 0
	data["scores"] = []
	for k in data["talents"]:
		data["talents"][k] = 0
	save_data()


func _merge(t: Dictionary, s: Dictionary) -> void:
	for k in s:
		if k in t and t[k] is Dictionary and s[k] is Dictionary:
			_merge(t[k], s[k])
		elif k in t:
			t[k] = s[k]


func add_score(entry: Dictionary) -> void:
	data["scores"].append(entry)
	data["scores"].sort_custom(func(a, b): return int(a.get("kills", 0)) > int(b.get("kills", 0)))
	if data["scores"].size() > 100: data["scores"] = data["scores"].slice(0, 100)
	save_data()


func add_shards(amount: int) -> void:
	data["shards"] += amount
	save_data()


func talent_level(key: String) -> int:
	return int(data["talents"].get(key, 0))


func upgrade_talent(key: String, cost: int) -> bool:
	if data["shards"] < cost: return false
	if key not in data["talents"]: return false
	if data["talents"][key] >= 10: return false
	data["shards"] -= cost
	data["talents"][key] = int(data["talents"][key]) + 1
	save_data()
	return true


# ── 注册 / 登录（本地存档） ──
func hash_pw(pw: String) -> String:
	return pw.sha256_text()


func register(user: String, pw: String) -> bool:
	if not data.has("accounts"): data["accounts"] = {}
	if data["accounts"].has(user): return false
	data["accounts"][user] = hash_pw(pw)
	save_data()
	return true


func login(user: String, pw: String) -> bool:
	if not data.has("accounts"): data["accounts"] = {}
	if not data["accounts"].has(user): return false
	return data["accounts"][user] == hash_pw(pw)
