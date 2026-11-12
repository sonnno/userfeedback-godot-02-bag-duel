class_name ItemDef
extends RefCounted
## 装备静态数据表

const DAGGER := "dagger"        # 匕首 1×2
const SWORD := "sword"          # 重剑 1×3
const SHIELD := "shield"        # 盾牌 2×2
const BOW := "bow"              # 弓 2×3
const QUIVER := "quiver"        # 箭袋 1×2
const HEAL := "heal"            # 治疗瓶 1×1
const POISON := "poison"        # 毒瓶 1×1
const WHETSTONE := "whetstone"  # 磨刀石 1×1

const WEAPONS := [DAGGER, SWORD, BOW]

# 类型 -> 静态属性
static var defs := {
	DAGGER: {
		"name": "匕首", "icon": "匕", "size": Vector2i(1, 2), "price": 3,
		"color": Color("e06b5a"),
		"damage": 4, "interval": 1.0, "ranged": false,
		"effect": "每 1.0 秒造成 4 点近战伤害",
		"link": "与磨刀石边相邻：伤害 +2",
	},
	SWORD: {
		"name": "重剑", "icon": "剑", "size": Vector2i(1, 3), "price": 6,
		"color": Color("d98f3b"),
		"damage": 10, "interval": 2.4, "ranged": false,
		"effect": "每 2.4 秒造成 10 点近战伤害",
		"link": "与磨刀石边相邻：伤害 +2",
	},
	SHIELD: {
		"name": "盾牌", "icon": "盾", "size": Vector2i(2, 2), "price": 5,
		"color": Color("4f8edb"),
		"shield": 15,
		"effect": "开场获得 15 点护盾",
		"link": "与治疗瓶边相邻：治疗瓶回复量 +10",
	},
	BOW: {
		"name": "弓", "icon": "弓", "size": Vector2i(2, 3), "price": 7,
		"color": Color("57b27a"),
		"damage": 6, "interval": 2.0, "ranged": true,
		"effect": "每 2.0 秒造成 6 点远程伤害",
		"link": "与箭袋边相邻：攻击间隔 ×0.8",
	},
	QUIVER: {
		"name": "箭袋", "icon": "矢", "size": Vector2i(1, 2), "price": 3,
		"color": Color("7fae5a"),
		"effect": "本身不攻击，用于强化弓",
		"link": "与弓边相邻：弓的攻击间隔 ×0.8",
	},
	HEAL: {
		"name": "治疗瓶", "icon": "愈", "size": Vector2i(1, 1), "price": 4,
		"color": Color("e57fb0"),
		"heal": 20,
		"effect": "生命首次低于 50% 时回复 20 点（每瓶一次）",
		"link": "与盾牌边相邻：回复量 +10",
	},
	POISON: {
		"name": "毒瓶", "icon": "毒", "size": Vector2i(1, 1), "price": 4,
		"color": Color("9b6bd6"),
		"poison_per_tick": 2, "poison_ticks": 5, "poison_period": 1.0,
		"effect": "开场使对手中毒：每秒 2 点、持续 5 秒（穿盾）",
		"link": "无联动，效果可与其他毒瓶叠加（分别计时）",
	},
	WHETSTONE: {
		"name": "磨刀石", "icon": "磨", "size": Vector2i(1, 1), "price": 3,
		"color": Color("9aa7b5"),
		"effect": "本身不攻击，用于强化武器",
		"link": "与匕首/重剑/弓边相邻：该武器伤害 +2",
	},
}

static func all_types() -> Array:
	return [DAGGER, SWORD, SHIELD, BOW, QUIVER, HEAL, POISON, WHETSTONE]

static func d(type: String, key: String, default = null):
	var entry: Dictionary = defs[type]
	return entry.get(key, default)

static func display_name(type: String) -> String:
	return d(type, "name")

static func price(type: String) -> int:
	return d(type, "price")

static func base_size(type: String) -> Vector2i:
	return d(type, "size")

static func is_weapon(type: String) -> bool:
	return WEAPONS.has(type)

## 当前旋转态下的占格（宽, 高）
static func footprint(type: String, rotated: bool) -> Vector2i:
	var s: Vector2i = base_size(type)
	if rotated:
		return Vector2i(s.y, s.x)
	return s

static func description(type: String) -> String:
	var s: Vector2i = base_size(type)
	var foot := "%d×%d  价格 %d 金币\n%s" % [s.x, s.y, price(type), d(type, "effect")]
	var link: String = d(type, "link")
	if link != "":
		foot += "\n联动：" + link
	return foot
