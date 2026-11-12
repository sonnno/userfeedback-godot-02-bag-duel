class_name Opponents
extends RefCounted
## 7 套离线对手构筑：快攻 / 毒蚀 / 弓手 / 均衡 / 护盾 / 重剑 / 混合消耗
## 坐标均在 7×6 背包内，右下角 (5..6,4..5) 为禁用格。

static func list() -> Array:
	return [
		{
			"name": "快攻手", "tag": "快攻",
			"desc": "三把匕首高频快攻，搭配磨刀石强化伤害。",
			"items": [
				{"type": ItemDef.DAGGER, "pos": Vector2i(0, 0), "rotated": false},
				{"type": ItemDef.DAGGER, "pos": Vector2i(1, 0), "rotated": false},
				{"type": ItemDef.DAGGER, "pos": Vector2i(2, 0), "rotated": false},
				{"type": ItemDef.WHETSTONE, "pos": Vector2i(0, 2), "rotated": false},
				{"type": ItemDef.WHETSTONE, "pos": Vector2i(1, 2), "rotated": false},
				{"type": ItemDef.WHETSTONE, "pos": Vector2i(2, 2), "rotated": false},
				{"type": ItemDef.HEAL, "pos": Vector2i(4, 0), "rotated": false},
			],
		},
		{
			"name": "毒蚀术士", "tag": "持续伤害",
			"desc": "四瓶毒开场压血，匕首补伤害，毒伤穿盾。",
			"items": [
				{"type": ItemDef.POISON, "pos": Vector2i(0, 0), "rotated": false},
				{"type": ItemDef.POISON, "pos": Vector2i(1, 0), "rotated": false},
				{"type": ItemDef.POISON, "pos": Vector2i(2, 0), "rotated": false},
				{"type": ItemDef.POISON, "pos": Vector2i(3, 0), "rotated": false},
				{"type": ItemDef.DAGGER, "pos": Vector2i(0, 2), "rotated": false},
				{"type": ItemDef.DAGGER, "pos": Vector2i(1, 2), "rotated": false},
				{"type": ItemDef.SHIELD, "pos": Vector2i(3, 2), "rotated": false},
				{"type": ItemDef.HEAL, "pos": Vector2i(3, 4), "rotated": false},
			],
		},
		{
			"name": "游骑弓手", "tag": "远程",
			"desc": "双弓远程输出，箭袋缩短间隔，磨刀石增伤。",
			"items": [
				{"type": ItemDef.BOW, "pos": Vector2i(0, 0), "rotated": false},
				{"type": ItemDef.QUIVER, "pos": Vector2i(2, 0), "rotated": false},
				{"type": ItemDef.WHETSTONE, "pos": Vector2i(3, 0), "rotated": false},
				{"type": ItemDef.BOW, "pos": Vector2i(4, 0), "rotated": false},
				{"type": ItemDef.QUIVER, "pos": Vector2i(0, 3), "rotated": false},
				{"type": ItemDef.HEAL, "pos": Vector2i(1, 3), "rotated": false},
				{"type": ItemDef.POISON, "pos": Vector2i(2, 3), "rotated": false},
				{"type": ItemDef.WHETSTONE, "pos": Vector2i(3, 3), "rotated": false},
			],
		},
		{
			"name": "均衡斗士", "tag": "均衡",
			"desc": "远近搭配、攻防兼备，治疗瓶与盾牌联动。",
			"items": [
				{"type": ItemDef.DAGGER, "pos": Vector2i(0, 0), "rotated": false},
				{"type": ItemDef.BOW, "pos": Vector2i(1, 0), "rotated": false},
				{"type": ItemDef.QUIVER, "pos": Vector2i(3, 0), "rotated": false},
				{"type": ItemDef.SHIELD, "pos": Vector2i(4, 2), "rotated": false},
				{"type": ItemDef.HEAL, "pos": Vector2i(4, 4), "rotated": false},
				{"type": ItemDef.WHETSTONE, "pos": Vector2i(0, 2), "rotated": false},
				{"type": ItemDef.POISON, "pos": Vector2i(0, 3), "rotated": false},
				{"type": ItemDef.HEAL, "pos": Vector2i(1, 3), "rotated": false},
			],
		},
		{
			"name": "铁壁守卫", "tag": "护盾",
			"desc": "双盾开场叠甲，治疗瓶贴着盾牌获得额外回复。",
			"items": [
				{"type": ItemDef.SHIELD, "pos": Vector2i(0, 0), "rotated": false},
				{"type": ItemDef.SHIELD, "pos": Vector2i(2, 0), "rotated": false},
				{"type": ItemDef.HEAL, "pos": Vector2i(0, 2), "rotated": false},
				{"type": ItemDef.HEAL, "pos": Vector2i(1, 2), "rotated": false},
				{"type": ItemDef.SWORD, "pos": Vector2i(4, 0), "rotated": false},
				{"type": ItemDef.WHETSTONE, "pos": Vector2i(4, 3), "rotated": false},
				{"type": ItemDef.HEAL, "pos": Vector2i(2, 2), "rotated": false},
				{"type": ItemDef.POISON, "pos": Vector2i(3, 2), "rotated": false},
			],
		},
		{
			"name": "重剑豪", "tag": "爆发",
			"desc": "双把重剑蓄力重击，磨刀石把伤害堆到极致。",
			"items": [
				{"type": ItemDef.SWORD, "pos": Vector2i(0, 0), "rotated": false},
				{"type": ItemDef.SWORD, "pos": Vector2i(1, 0), "rotated": false},
				{"type": ItemDef.WHETSTONE, "pos": Vector2i(0, 3), "rotated": false},
				{"type": ItemDef.WHETSTONE, "pos": Vector2i(1, 3), "rotated": false},
				{"type": ItemDef.HEAL, "pos": Vector2i(3, 0), "rotated": false},
				{"type": ItemDef.SHIELD, "pos": Vector2i(3, 2), "rotated": false},
				{"type": ItemDef.POISON, "pos": Vector2i(3, 4), "rotated": false},
			],
		},
		{
			"name": "消耗大师", "tag": "混合",
			"desc": "毒、盾、弓、治疗一应俱全，擅长把对手拖入消耗战。",
			"items": [
				{"type": ItemDef.BOW, "pos": Vector2i(0, 0), "rotated": false},
				{"type": ItemDef.QUIVER, "pos": Vector2i(2, 0), "rotated": false},
				{"type": ItemDef.SHIELD, "pos": Vector2i(3, 0), "rotated": false},
				{"type": ItemDef.POISON, "pos": Vector2i(0, 3), "rotated": false},
				{"type": ItemDef.POISON, "pos": Vector2i(1, 3), "rotated": false},
				{"type": ItemDef.HEAL, "pos": Vector2i(3, 2), "rotated": false},
				{"type": ItemDef.HEAL, "pos": Vector2i(0, 4), "rotated": false},
				{"type": ItemDef.WHETSTONE, "pos": Vector2i(2, 3), "rotated": false},
				{"type": ItemDef.DAGGER, "pos": Vector2i(5, 0), "rotated": false},
			],
		},
	]

## 依据对手数据构造背包（测试/预览/战斗共用）
static func build_bag(idx: int) -> BagGrid:
	var data: Dictionary = list()[idx]
	var bag := BagGrid.make_bag()
	for entry in data["items"]:
		var it := ItemInstance.make(entry["type"])
		var ok := bag.add_item(it, entry["pos"], entry["rotated"], "bag")
		assert(ok, "对手 %d 的装备放置非法：%s" % [idx, entry])
	return bag
