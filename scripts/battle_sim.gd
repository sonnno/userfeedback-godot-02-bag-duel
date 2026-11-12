class_name BattleSim
extends RefCounted
## 自动战斗模拟器（固定步长、无随机），可逐帧驱动供 UI 播放，也可一次跑完供测试。

const TIMEOUT := 60.0

var player: Combatant
var enemy: Combatant
var time := 0.0
var finished := false
var result := ""        # "win" | "lose" | "draw"
var reason := ""        # "death" | "timeout"
var step := 0

func _init(stats_player: BuildStats, stats_enemy: BuildStats) -> void:
	player = Combatant.new(stats_player, "玩家")
	enemy = Combatant.new(stats_enemy, "对手")

## 推进 dt 秒，返回本段时间产生的事件数组
## 事件：{ time, side: player|enemy|system, kind, text, amount }
func advance(dt: float) -> Array:
	var events: Array = []
	if finished:
		return events
	time += dt
	step += 1
	# 1) 中毒结算（每个来源独立计时，穿盾）
	_tick_poisons(player, enemy, dt, events)
	_tick_poisons(enemy, player, dt, events)
	# 2) 治疗判定（毒伤可能已压到半血以下）
	_try_heal_side(player, "player", events)
	_try_heal_side(enemy, "enemy", events)
	# 3) 武器攻击（双方同帧攻击，伤害全部结算后再判死亡，同帧双亡为平局）
	_fire_weapons(player, enemy, "player", dt, events)
	_fire_weapons(enemy, player, "enemy", dt, events)
	# 4) 攻击后治疗判定
	_try_heal_side(player, "player", events)
	_try_heal_side(enemy, "enemy", events)
	# 5) 死亡 / 超时判定
	if not player.alive and not enemy.alive:
		_finish("draw", "death", events)
	elif not enemy.alive:
		_finish("win", "death", events)
	elif not player.alive:
		_finish("lose", "death", events)
	elif time >= TIMEOUT:
		_finish("draw", "timeout", events)
	return events

func _finish(r: String, why: String, events: Array) -> void:
	finished = true
	result = r
	reason = why
	var text := ""
	match r:
		"win": text = "对手倒下，你赢了！"
		"lose": text = "你倒下了……"
		_:
			text = "60 秒未分胜负，平局。" if why == "timeout" else "双方同时倒下，平局。"
	events.append({"time": time, "side": "system", "kind": "info", "text": text, "amount": 0})

func _tick_poisons(owner: Combatant, target: Combatant, dt: float, events: Array) -> void:
	for src in owner.poisons:
		if src["ticks_left"] <= 0:
			continue
		src["time_to_next"] -= dt
		if src["time_to_next"] <= 0.0:
			src["time_to_next"] += src["period"]
			src["ticks_left"] -= 1
			var dmg: int = target.take_poison(src["per_tick"])
			var side := "enemy" if owner == player else "player"
			events.append({
				"time": time, "side": side, "kind": "poison",
				"text": "%s 受到 %d 点毒伤（穿盾）" % [target.display_name, dmg],
				"amount": dmg, "uid": src["uid"],
			})

func _fire_weapons(attacker: Combatant, target: Combatant, side: String, dt: float, events: Array) -> void:
	for w in attacker.weapons:
		w["time_left"] -= dt
		if w["time_left"] <= 0.0:
			w["time_left"] += w["interval"]
			var r: Dictionary = target.take_damage(w["damage"])
			var wname := ItemDef.display_name(w["type"])
			var range_tag := "远程" if w["ranged"] else "近战"
			if r["shield_absorbed"] > 0 and r["hp_lost"] > 0:
				events.append({"time": time, "side": side, "kind": "shield",
					"text": "%s %s命中：护盾吸收 %d，%s 损失 %d" % [wname, range_tag, r["shield_absorbed"], target.display_name, r["hp_lost"]],
					"amount": w["damage"], "uid": w["uid"]})
			elif r["shield_absorbed"] > 0:
				events.append({"time": time, "side": side, "kind": "shield",
					"text": "%s %s命中：护盾吸收 %d" % [wname, range_tag, r["shield_absorbed"]],
					"amount": w["damage"], "uid": w["uid"]})
			else:
				events.append({"time": time, "side": side, "kind": "hit",
					"text": "%s %s命中 %s，造成 %d 点伤害" % [wname, range_tag, target.display_name, r["hp_lost"]],
					"amount": w["damage"], "uid": w["uid"]})

func _try_heal_side(c: Combatant, side: String, events: Array) -> void:
	var healed := c.try_heal()
	if healed > 0:
		events.append({"time": time, "side": side, "kind": "heal",
			"text": "%s 生命低于一半，治疗瓶回复 %d" % [c.display_name, healed],
			"amount": healed})

## 一次跑完（测试用），固定 0.1s 步长
static func run_full(stats_player: BuildStats, stats_enemy: BuildStats) -> Dictionary:
	var sim := BattleSim.new(stats_player, stats_enemy)
	var all_events: Array = []
	while not sim.finished:
		all_events.append_array(sim.advance(0.1))
	return {
		"result": sim.result, "reason": sim.reason, "time": sim.time,
		"events": all_events,
		"player_hp": sim.player.hp, "enemy_hp": sim.enemy.hp,
	}
