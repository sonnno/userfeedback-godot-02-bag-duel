class_name BuildStats
extends RefCounted
## 由背包内容计算战斗数值与联动关系（仅边相邻，斜角不算）
## 规则：同一件来源装备对同一件目标装备只生效一次；不同来源可叠加。

# 每件装备实例 uid -> 生效联动说明（给 UI 高亮用）
var links: Dictionary = {}          # uid -> Array[String]
var partner_uids: Dictionary = {}   # uid -> Array[uid]（互相高亮）

# 武器 uid -> { damage, interval, type, ranged }
var weapons: Array[Dictionary] = []
var shield_total := 0
var heal_count := 0
var heal_amount := 20
var poison_sources: Array[Dictionary] = []   # 每个毒瓶一个独立来源

const QUIVER_FACTOR := 0.8
const WHETSTONE_BONUS := 2
const SHIELD_HEAL_BONUS := 10
const BASE_HEAL := 20

func _init(bag: BagGrid) -> void:
	_record_links(bag)
	_evaluate(bag)

# ---------- 相邻判定 ----------

static func edge_adjacent(a: ItemInstance, b: ItemInstance) -> bool:
	if a == b:
		return false
	var ac := a.cells()
	var bc := b.cells()
	for ca in ac:
		for delta in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if bc.has(ca + delta):
				return true
	return false

func _add_link(uid_a: int, uid_b: int, text: String) -> void:
	if not links.has(uid_a):
		links[uid_a] = []
		partner_uids[uid_a] = []
	links[uid_a].append(text)
	partner_uids[uid_a].append(uid_b)

# ---------- 联动记录 ----------

func _record_links(bag: BagGrid) -> void:
	var n := bag.items.size()
	for i in range(n):
		var a: ItemInstance = bag.items[i]
		for j in range(i + 1, n):
			var b: ItemInstance = bag.items[j]
			if not edge_adjacent(a, b):
				continue
			# 磨刀石 <-> 武器
			if a.type == ItemDef.WHETSTONE and ItemDef.is_weapon(b.type):
				_link_whetstone(a, b)
			elif b.type == ItemDef.WHETSTONE and ItemDef.is_weapon(a.type):
				_link_whetstone(b, a)
			# 弓 <-> 箭袋
			elif a.type == ItemDef.BOW and b.type == ItemDef.QUIVER:
				_link_quiver(a, b)
			elif b.type == ItemDef.BOW and a.type == ItemDef.QUIVER:
				_link_quiver(b, a)
			# 治疗瓶 <-> 盾牌
			elif a.type == ItemDef.HEAL and b.type == ItemDef.SHIELD:
				_link_shield_heal(a, b)
			elif b.type == ItemDef.HEAL and a.type == ItemDef.SHIELD:
				_link_shield_heal(b, a)

func _link_whetstone(stone: ItemInstance, weapon: ItemInstance) -> void:
	_add_link(stone.uid, weapon.uid, "磨刀石：%s 伤害 +%d" % [ItemDef.display_name(weapon.type), WHETSTONE_BONUS])
	_add_link(weapon.uid, stone.uid, "磨刀石加成：伤害 +%d" % WHETSTONE_BONUS)

func _link_quiver(bow: ItemInstance, quiver: ItemInstance) -> void:
	_add_link(quiver.uid, bow.uid, "箭袋：弓攻击间隔 ×%.1f" % QUIVER_FACTOR)
	_add_link(bow.uid, quiver.uid, "箭袋加成：间隔 ×%.1f" % QUIVER_FACTOR)

func _link_shield_heal(heal: ItemInstance, shield: ItemInstance) -> void:
	_add_link(shield.uid, heal.uid, "盾牌：治疗瓶回复 +%d" % SHIELD_HEAL_BONUS)
	_add_link(heal.uid, shield.uid, "盾牌加成：回复 +%d" % SHIELD_HEAL_BONUS)

# ---------- 数值结算 ----------

func _evaluate(bag: BagGrid) -> void:
	var whet_count := {}   # 武器 uid -> 相邻磨刀石来源数
	var quiver_count := {} # 弓 uid -> 相邻箭袋来源数
	for it in bag.items:
		match it.type:
			ItemDef.SHIELD:
				shield_total += ItemDef.d(it.type, "shield")
			ItemDef.HEAL:
				heal_count += 1
			ItemDef.POISON:
				poison_sources.append({
					"per_tick": ItemDef.d(it.type, "poison_per_tick"),
					"ticks": ItemDef.d(it.type, "poison_ticks"),
					"period": ItemDef.d(it.type, "poison_period"),
					"uid": it.uid,
				})
	# 由物品对的边相邻关系统计来源数（同来源对同目标天然只算一次）
	for a in bag.items:
		if not ItemDef.is_weapon(a.type):
			continue
		for b in bag.items:
			if a == b or not edge_adjacent(a, b):
				continue
			if b.type == ItemDef.WHETSTONE:
				whet_count[a.uid] = whet_count.get(a.uid, 0) + 1
			elif a.type == ItemDef.BOW and b.type == ItemDef.QUIVER:
				quiver_count[a.uid] = quiver_count.get(a.uid, 0) + 1
	# 治疗瓶与盾牌：每瓶每相邻一面盾牌获得一次回复加成
	heal_amount = BASE_HEAL * heal_count
	for it in bag.items:
		if it.type != ItemDef.HEAL:
			continue
		for other in bag.items:
			if other.type == ItemDef.SHIELD and edge_adjacent(it, other):
				heal_amount += SHIELD_HEAL_BONUS
	# 武器最终数值
	for it in bag.items:
		if not ItemDef.is_weapon(it.type):
			continue
		var damage: int = ItemDef.d(it.type, "damage")
		var interval: float = ItemDef.d(it.type, "interval")
		damage += WHETSTONE_BONUS * whet_count.get(it.uid, 0)
		interval *= pow(QUIVER_FACTOR, quiver_count.get(it.uid, 0))
		weapons.append({
			"uid": it.uid,
			"type": it.type,
			"damage": damage,
			"interval": interval,
			"ranged": ItemDef.d(it.type, "ranged", false),
		})

## 悬停/选中某装备时，返回需要高亮的联动对象 uid 列表
func highlighted_partners(uid: int) -> Array:
	return partner_uids.get(uid, [])

func has_link(uid: int) -> bool:
	return links.has(uid) and not links[uid].is_empty()

func link_texts(uid: int) -> Array:
	return links.get(uid, [])
