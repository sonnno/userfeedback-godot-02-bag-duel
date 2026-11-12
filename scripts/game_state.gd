class_name GameState
extends RefCounted
## 整局运行状态：金币 / 命 / 胜场 / 轮次、背包与暂存区、商店库存、经济规则

const START_GOLD := 15
const START_LIVES := 3
const WINS_NEEDED := 5
const BATTLE_REWARD := 8
const REROLL_COST := 1
const SHOP_SIZE := 5

var gold := START_GOLD
var lives := START_LIVES
var wins := 0
var round := 1
var bag: BagGrid
var staging: BagGrid
var shop: Array[String] = []

func _init() -> void:
	bag = BagGrid.make_bag()
	staging = BagGrid.make_staging()
	roll_shop(true)

# ---------- 商店 ----------

func _random_type() -> String:
	var types := ItemDef.all_types()
	return types[randi() % types.size()]

## 首轮保证至少有一件买得起的武器
func roll_shop(first_round: bool = false) -> void:
	var picks: Array[String] = []
	for i in SHOP_SIZE:
		picks.append(_random_type())
	if first_round:
		var has_affordable_weapon := false
		for t in picks:
			if ItemDef.is_weapon(t) and ItemDef.price(t) <= gold:
				has_affordable_weapon = true
				break
		if not has_affordable_weapon:
			var affordable: Array[String] = []
			for t in ItemDef.WEAPONS:
				if ItemDef.price(t) <= gold:
					affordable.append(t)
			assert(not affordable.is_empty())
			picks[0] = affordable[randi() % affordable.size()]
	shop = picks

func can_reroll() -> bool:
	return gold >= REROLL_COST

func reroll() -> bool:
	if not can_reroll():
		return false
	gold -= REROLL_COST
	roll_shop(false)
	return true

func can_buy(slot: int) -> bool:
	if slot < 0 or slot >= shop.size():
		return false
	return gold >= ItemDef.price(shop[slot])

## 购买：优先放进背包空位，背包满则进暂存区；都放不下则失败
func buy(slot: int) -> Variant:
	if not can_buy(slot):
		return null
	var type := shop[slot]
	var it := ItemInstance.make(type)
	var foot := ItemDef.footprint(type, false)
	var p: Variant = bag.find_empty(foot)
	if p == null:
		p = staging.find_empty(foot)
		if p == null:
			return null
		staging.add_item(it, p, false, "staging")
	else:
		bag.add_item(it, p, false, "bag")
	gold -= ItemDef.price(type)
	shop.remove_at(slot)
	return it

static func sell_value(type: String) -> int:
	return floori(ItemDef.price(type) / 2.0)

func sell(it: ItemInstance) -> int:
	var refund := sell_value(it.type)
	if it.container == "bag":
		bag.remove_item(it)
	elif it.container == "staging":
		staging.remove_item(it)
	else:
		return 0
	gold += refund
	return refund

## 战后结算：金币奖励、胜场/生命判定
func settle_battle(result: String) -> Dictionary:
	gold += BATTLE_REWARD
	var lost_life := false
	var cleared := false
	var defeated := false
	if result == "win":
		wins += 1
		if wins >= WINS_NEEDED:
			cleared = true
	else:
		lives -= 1
		lost_life = true
		if lives <= 0:
			defeated = true
	if not cleared and not defeated:
		round += 1
		roll_shop(false)
	return {
		"lost_life": lost_life, "cleared": cleared, "defeated": defeated,
		"reward": BATTLE_REWARD,
	}

func current_opponent_index() -> int:
	return mini(round - 1, Opponents.list().size() - 1)

func reset() -> void:
	gold = START_GOLD
	lives = START_LIVES
	wins = 0
	round = 1
	bag = BagGrid.make_bag()
	staging = BagGrid.make_staging()
	roll_shop(true)
