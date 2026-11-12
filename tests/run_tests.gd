extends SceneTree
## 无头逻辑测试：godot --headless --script tests/run_tests.gd
## 覆盖：格子校验 / 联动规则 / 对手构筑合法性 / 战斗结算 / 经济与流程

var failures: Array[String] = []
var checks := 0

func check(cond: bool, name: String) -> void:
	checks += 1
	if cond:
		print("  PASS: ", name)
	else:
		failures.append(name)
		print("  FAIL: ", name)

func _initialize() -> void:
	print("== 行囊决斗 逻辑测试 ==")
	test_footprint_and_grid()
	test_synergies()
	test_opponents()
	test_combat()
	test_economy()
	test_heal_poison_rules()
	print("\n共 %d 项检查，失败 %d 项" % [checks, failures.size()])
	if failures.is_empty():
		print("全部通过 ✅")
		quit(0)
	else:
		for f in failures:
			print("  失败项：", f)
		quit(1)

# ---------- 1. 格子容器 ----------

func test_footprint_and_grid() -> void:
	print("\n[1] 格子容器与放置校验")
	check(ItemDef.footprint(ItemDef.DAGGER, false) == Vector2i(1, 2), "匕首默认 1×2")
	check(ItemDef.footprint(ItemDef.DAGGER, true) == Vector2i(2, 1), "匕首旋转 2×1")
	check(ItemDef.footprint(ItemDef.HEAL, true) == Vector2i(1, 1), "1×1 旋转不变")
	var bag := BagGrid.make_bag()
	check(bag.dims == Vector2i(7, 6), "背包 7×6")
	check(bag.blocked.size() == 4, "右下角禁用格为 2×2=4")
	check(bag.is_blocked(Vector2i(5, 4)) and bag.is_blocked(Vector2i(6, 5)), "禁用格位置正确")
	var sword := ItemInstance.make(ItemDef.SWORD)
	check(bag.add_item(sword, Vector2i(0, 4), false, "bag") == false, "重剑 1×3 放 y=4 竖向越界拒绝")
	check(bag.add_item(sword, Vector2i(5, 3), false, "bag") == false, "重剑压禁用格拒绝")
	check(bag.add_item(sword, Vector2i(0, 0), false, "bag"), "重剑放在 (0,0) 成功")
	var other := ItemInstance.make(ItemDef.DAGGER)
	check(bag.add_item(other, Vector2i(0, 0), false, "bag") == false, "重叠放置拒绝")
	check(bag.can_place_item(other, Vector2i(0, 0), false, other.uid) == false, "占位异常")
	var stone := ItemInstance.make(ItemDef.WHETSTONE)
	check(bag.add_item(stone, Vector2i(2, 0), false, "bag"), "磨刀石空位放置成功")
	var p: Variant = bag.find_empty(Vector2i(2, 3))
	check(p != null, "2×3 弓能找到空位")
	var staging := BagGrid.make_staging()
	check(staging.dims == Vector2i(6, 3), "暂存区 6×3 无禁用格")
	check(staging.blocked.is_empty(), "暂存区无禁用格")

# ---------- 2. 联动 ----------

func test_synergies() -> void:
	print("\n[2] 边相邻联动")
	var bag := BagGrid.make_bag()
	# 匕首竖放在 (0,0)-(0,1)，磨刀石放 (1,1) 与其底边相邻
	var dagger := ItemInstance.make(ItemDef.DAGGER)
	bag.add_item(dagger, Vector2i(0, 0), false, "bag")
	var stone := ItemInstance.make(ItemDef.WHETSTONE)
	bag.add_item(stone, Vector2i(1, 1), false, "bag")
	# 斜角磨刀石不应生效
	var stone_far := ItemInstance.make(ItemDef.WHETSTONE)
	bag.add_item(stone_far, Vector2i(2, 2), false, "bag")
	var stats := BuildStats.new(bag)
	var w: Dictionary = stats.weapons[0]
	check(w["damage"] == 6, "磨刀石边相邻：匕首 4+2=6（斜角不生效）")
	# 第二块磨刀石相邻可叠加
	bag.remove_item(stone_far)
	var stone2 := ItemInstance.make(ItemDef.WHETSTONE)
	bag.add_item(stone2, Vector2i(1, 0), false, "bag")
	stats = BuildStats.new(bag)
	w = stats.weapons[0]
	check(w["damage"] == 8, "两块不同磨刀石叠加：4+2+2=8")
	check(stats.highlighted_partners(dagger.uid).size() == 2, "匕首高亮两个联动来源")
	# 弓 + 箭袋（弓横放 3×2，箭袋放在弓右侧相邻）
	var bag2 := BagGrid.make_bag()
	var bow := ItemInstance.make(ItemDef.BOW)
	bag2.add_item(bow, Vector2i(0, 0), true, "bag")
	var quiver := ItemInstance.make(ItemDef.QUIVER)
	bag2.add_item(quiver, Vector2i(3, 0), false, "bag")
	var s2 := BuildStats.new(bag2)
	check(absf(s2.weapons[0]["interval"] - 1.6) < 0.001, "箭袋边相邻：弓间隔 2.0×0.8=1.6")
	# 第二个箭袋贴弓的底边（弓横放在 y0-1，箭袋竖放 y2-3）
	var q2 := ItemInstance.make(ItemDef.QUIVER)
	bag2.add_item(q2, Vector2i(0, 2), false, "bag")
	s2 = BuildStats.new(bag2)
	check(absf(s2.weapons[0]["interval"] - 1.28) < 0.001, "两个箭袋：2.0×0.8²=1.28（实际 %.3f）" % s2.weapons[0]["interval"])
	# 治疗瓶 + 盾牌
	var bag3 := BagGrid.make_bag()
	var heal := ItemInstance.make(ItemDef.HEAL)
	bag3.add_item(heal, Vector2i(0, 0), false, "bag")
	var shield := ItemInstance.make(ItemDef.SHIELD)
	bag3.add_item(shield, Vector2i(1, 0), false, "bag")
	var s3 := BuildStats.new(bag3)
	check(s3.heal_count == 1 and s3.heal_amount == 30, "治疗瓶贴盾牌：20+10=30")
	check(s3.shield_total == 15, "盾牌开场护盾 15")
	var heal2 := ItemInstance.make(ItemDef.HEAL)
	bag3.add_item(heal2, Vector2i(4, 0), false, "bag")
	s3 = BuildStats.new(bag3)
	check(s3.heal_amount == 50, "两瓶（一瓶有加成）：20+30=50")
	# 同来源对同目标只生效一次（长物品贴多个格子）
	var bag4 := BagGrid.make_bag()
	var sword := ItemInstance.make(ItemDef.SWORD)
	bag4.add_item(sword, Vector2i(0, 0), false, "bag")
	var st := ItemInstance.make(ItemDef.WHETSTONE)
	bag4.add_item(st, Vector2i(1, 1), false, "bag")  # 只与重剑中段一格相邻
	var s4 := BuildStats.new(bag4)
	check(s4.weapons[0]["damage"] == 12, "重剑 + 单磨刀石 = 12（同来源一次）")

# ---------- 3. 对手构筑 ----------

func test_opponents() -> void:
	print("\n[3] 离线对手构筑")
	var data := Opponents.list()
	check(data.size() >= 6, "至少 6 套对手（实际 %d）" % data.size())
	var tags: Array[String] = []
	for i in data.size():
		tags.append(data[i]["tag"])
		var bag := Opponents.build_bag(i)   # 内部 assert 放置合法
		var stats := BuildStats.new(bag)
		check(not stats.weapons.is_empty(), "对手 %d 至少有一把武器" % i)
		check(bag.items.size() == data[i]["items"].size(), "对手 %d 装备全部入包" % i)
		# 战斗能在超时前或超时处正常结束
		var player_bag := BagGrid.make_bag()
		var dagger := ItemInstance.make(ItemDef.DAGGER)
		player_bag.add_item(dagger, Vector2i(0, 0), false, "bag")
		var r: Dictionary = BattleSim.run_full(BuildStats.new(player_bag), stats)
		check(["win", "lose", "draw"].has(r["result"]), "对手 %d 战斗可结算：%s (%.1fs)" % [i, r["result"], r["time"]])
	check(tags.has("快攻") and tags.has("护盾") and tags.has("持续伤害"), "覆盖快攻/护盾/持续伤害三类")

# ---------- 4. 战斗结算 ----------

func test_combat() -> void:
	print("\n[4] 战斗模拟")
	# 空背包 vs 空背包 -> 60 秒平局
	var empty := BuildStats.new(BagGrid.make_bag())
	var r := BattleSim.run_full(empty, BuildStats.new(BagGrid.make_bag()))
	check(r["result"] == "draw" and r["reason"] == "timeout", "空手对局 60 秒平局")
	# 一把匕首 100 血 / 4 伤每秒 -> 25 次攻击约 25 秒击杀
	var bag := BagGrid.make_bag()
	var dagger := ItemInstance.make(ItemDef.DAGGER)
	bag.add_item(dagger, Vector2i(0, 0), false, "bag")
	r = BattleSim.run_full(BuildStats.new(bag), empty)
	check(r["result"] == "win" and r["enemy_hp"] == 0, "单匕首战胜空手")
	check(r["time"] <= 26.0, "单匕首约 25 秒结束（实际 %.1f）" % r["time"])
	# 护盾吸收
	var shield_bag := BagGrid.make_bag()
	var sh := ItemInstance.make(ItemDef.SHIELD)
	shield_bag.add_item(sh, Vector2i(0, 0), false, "bag")
	var sim := BattleSim.new(BuildStats.new(bag), BuildStats.new(shield_bag))
	var saw_shield := false
	while not sim.finished:
		for ev in sim.advance(0.1):
			if ev["kind"] == "shield":
				saw_shield = true
	check(saw_shield, "护盾吸收事件出现")
	# 匕首总伤害 100：15 点被护盾吸收，85 点打到生命；敌人阵亡时生命为 0、护盾耗尽
	check(sim.enemy.shield == 0 and sim.enemy.hp == 0 and not sim.enemy.alive, "15 点护盾先被打穿，随后 85 点伤害击倒对手")
	# 再验证单次受击的吸收顺序：4 点伤害打在 15 护盾上不掉血
	var probe := Combatant.new(BuildStats.new(shield_bag), "probe")
	var hit: Dictionary = probe.take_damage(4)
	check(hit["shield_absorbed"] == 4 and hit["hp_lost"] == 0 and probe.hp == 100 and probe.shield == 11, "伤害先由护盾吸收")
	# 同帧双亡 -> 平局：构造两边同时被最后一击（两边都一把匕首、同间隔、无盾）
	var b1 := BagGrid.make_bag()
	b1.add_item(ItemInstance.make(ItemDef.DAGGER), Vector2i(0, 0), false, "bag")
	var b2 := BagGrid.make_bag()
	b2.add_item(ItemInstance.make(ItemDef.DAGGER), Vector2i(0, 0), false, "bag")
	var sim2 := BattleSim.new(BuildStats.new(b1), BuildStats.new(b2))
	# 两边完全对称，最终应同时倒下判平局
	while not sim2.finished:
		sim2.advance(0.1)
	check(sim2.result == "draw" and sim2.reason == "death", "对称匕首同帧双亡判平局")

# ---------- 5. 治疗与毒规则 ----------

func test_heal_poison_rules() -> void:
	print("\n[5] 治疗瓶 / 毒瓶规则")
	var c := Combatant.new(BuildStats.new(BagGrid.make_bag()), "t")
	check(c.try_heal() == 0, "无治疗瓶时不回复")
	var bag := BagGrid.make_bag()
	bag.add_item(ItemInstance.make(ItemDef.HEAL), Vector2i(0, 0), false, "bag")
	c = Combatant.new(BuildStats.new(bag), "t")
	check(c.try_heal() == 0, "满血时不触发治疗")
	c.hp = 49
	check(c.try_heal() == 20, "首次低于半血回复 20")
	check(c.hp == 69 and c.heal_used, "回复后血量正确并标记已用")
	check(c.try_heal() == 0, "治疗只触发一次")
	# 毒穿盾
	var c2 := Combatant.new(BuildStats.new(BagGrid.make_bag()), "t2")
	c2.shield = 30
	var dmg := c2.take_poison(2)
	check(dmg == 2 and c2.shield == 30 and c2.hp == 98, "毒伤穿盾直接扣血")
	# 多毒源独立计时
	var poison_bag := BagGrid.make_bag()
	poison_bag.add_item(ItemInstance.make(ItemDef.POISON), Vector2i(0, 0), false, "bag")
	poison_bag.add_item(ItemInstance.make(ItemDef.POISON), Vector2i(1, 0), false, "bag")
	var ps := BuildStats.new(poison_bag)
	check(ps.poison_sources.size() == 2, "两个毒瓶 = 两个独立来源")
	var target := Combatant.new(BuildStats.new(BagGrid.make_bag()), "target")
	var attacker := Combatant.new(ps, "atk")
	# 5 秒内每个来源各 5 跳，每跳 2 -> 共 20 伤害
	var sim := BattleSim.new(ps, BuildStats.new(BagGrid.make_bag()))
	while not sim.finished:
		sim.advance(0.1)
	check(sim.enemy.hp == 80, "双毒瓶 5 秒共造成 20 点穿盾伤害（实际剩 %d）" % sim.enemy.hp)

# ---------- 6. 经济与整局流程 ----------

func test_economy() -> void:
	print("\n[6] 经济与游戏流程")
	var gs := GameState.new()
	check(gs.gold == 15 and gs.lives == 3 and gs.wins == 0, "初始 15 金 / 3 命 / 0 胜")
	check(gs.shop.size() == 5, "商店 5 件装备")
	var affordable_weapon := false
	for t in gs.shop:
		if ItemDef.is_weapon(t) and ItemDef.price(t) <= 15:
			affordable_weapon = true
	check(affordable_weapon, "首轮至少一件买得起的武器")
	var gold_before := gs.gold
	var slot := -1
	for i in gs.shop.size():
		if gs.gold >= ItemDef.price(gs.shop[i]):
			slot = i
			break
	var type := gs.shop[slot]
	var it: ItemInstance = gs.buy(slot)
	check(it != null and gs.gold == gold_before - ItemDef.price(type), "购买扣金币且装备入包/暂存")
	check(gs.shop.size() == 4, "购买后货架剩 4 件")
	var refund := gs.sell(it)
	check(refund == floori(ItemDef.price(type) / 2.0), "出售返还半价向下取整")
	check(gs.gold == gold_before - ItemDef.price(type) + refund, "出售后金币正确")
	var g0 := gs.gold
	check(gs.reroll() and gs.gold == g0 - 1 and gs.shop.size() == 5, "刷新花 1 金币并补满 5 件")
	# 金币不足时刷新失败
	gs.gold = 0
	check(gs.reroll() == false and gs.can_buy(0) == false, "0 金时刷新/购买均失败")
	# 结算流程
	gs.gold = 10
	var info := gs.settle_battle("win")
	check(gs.gold == 18 and gs.wins == 1 and gs.lives == 3 and gs.round == 2, "胜利 +8 金、胜场+1、进下一轮")
	info = gs.settle_battle("lose")
	check(gs.lives == 2 and gs.wins == 1, "失败扣 1 命")
	info = gs.settle_battle("draw")
	check(gs.lives == 1, "平局扣 1 命")
	# 5 胜通关
	gs.wins = 4
	info = gs.settle_battle("win")
	check(info["cleared"] and gs.wins == 5, "累计 5 胜通关")
	# 命尽失败
	var gs2 := GameState.new()
	gs2.lives = 1
	info = gs2.settle_battle("lose")
	check(info["defeated"] and gs2.lives == 0, "命耗尽失败")
	# 重开
	gs.reset()
	check(gs.gold == 15 and gs.lives == 3 and gs.wins == 0 and gs.round == 1, "reset 回到初始状态")
