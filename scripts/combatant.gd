class_name Combatant
extends RefCounted
## 战斗单位：生命 / 护盾 / 武器冷却 / 治疗触发 / 中毒独立计时

var display_name := ""
var stats: BuildStats
var max_hp := 100
var hp := 100
var shield := 0
var alive := true

# 武器冷却条目：{ uid, type, damage, interval, time_left, ranged }
var weapons: Array[Dictionary] = []
# 中毒来源条目：{ uid, per_tick, ticks_left, time_to_next, period }
var poisons: Array[Dictionary] = []

var heal_amount := 0
var heal_used := false

func _init(p_stats: BuildStats, p_name: String) -> void:
	stats = p_stats
	display_name = p_name
	shield = p_stats.shield_total
	heal_amount = p_stats.heal_amount
	for w in p_stats.weapons:
		weapons.append({
			"uid": w["uid"], "type": w["type"], "damage": w["damage"],
			"interval": w["interval"], "ranged": w["ranged"],
			"time_left": w["interval"],
		})
	for p in p_stats.poison_sources:
		poisons.append({
			"uid": p["uid"], "per_tick": p["per_tick"],
			"ticks_left": p["ticks"], "period": p["period"],
			"time_to_next": p["period"],
		})

## 武器/护盾伤害：护盾先吸收，返回 {shield_absorbed, hp_lost}
func take_damage(amount: int) -> Dictionary:
	if not alive:
		return {"shield_absorbed": 0, "hp_lost": 0}
	var absorbed := mini(shield, amount)
	shield -= absorbed
	var lost := amount - absorbed
	hp = maxi(0, hp - lost)
	if hp <= 0:
		alive = false
	return {"shield_absorbed": absorbed, "hp_lost": lost}

## 毒伤穿盾，直接扣生命
func take_poison(amount: int) -> int:
	if not alive:
		return 0
	hp = maxi(0, hp - amount)
	if hp <= 0:
		alive = false
	return amount

## 生命首次低于一半时回复一次（所有未用治疗瓶同时触发）
func try_heal() -> int:
	if heal_used or heal_amount <= 0 or not alive:
		return 0
	if hp * 2 < max_hp:
		heal_used = true
		var before := hp
		hp = mini(max_hp, hp + heal_amount)
		return hp - before
	return 0

func push_poison(source: Dictionary) -> void:
	poisons.append({
		"uid": source["uid"], "per_tick": source["per_tick"],
		"ticks_left": source["ticks"], "period": source["period"],
		"time_to_next": source["period"],
	})
