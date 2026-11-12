class_name BattleScreen
extends Control
## 自动战斗播放：双方生命/护盾条、装备冷却、事件日志、1×/2× 速度、暂停、飘字反馈

signal finished(result: String, detail: Dictionary)

const SIM_DT := 0.1

var state: GameState
var sim: BattleSim
var speed_idx := 0
var speeds := [1.0, 2.0]
var paused := false
var _accum := 0.0

var _hp_bar: ProgressBar
var _en_hp_bar: ProgressBar
var _hp_label: Label
var _en_hp_label: Label
var _p_panel: PanelContainer
var _e_panel: PanelContainer
var _p_icons: HBoxContainer
var _e_icons: HBoxContainer
var _p_effects: Label
var _e_effects: Label
var _log: RichTextLabel
var _timer_label: Label
var _speed_btn: Button
var _pause_overlay: Control
var _end_overlay: Control
var _float_layer: Control
var _cooldown_views: Dictionary = {}   # (side,uid) -> ItemView
var _ended := false

func _init(p_state: GameState) -> void:
	state = p_state
	var p_stats := BuildStats.new(state.bag)
	var e_bag := Opponents.build_bag(state.current_opponent_index())
	var e_stats := BuildStats.new(e_bag)
	sim = BattleSim.new(p_stats, e_stats)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	set_process(true)

# ---------------- UI ----------------

func _build_ui() -> void:
	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		root.add_theme_constant_override(m, 14)
	add_child(root)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	root.add_child(vb)

	# 顶部
	var top := HBoxContainer.new()
	vb.add_child(top)
	var title := Label.new()
	var opp: Dictionary = Opponents.list()[state.current_opponent_index()]
	title.text = "第 %d 场 · 对手：%s（%s）" % [state.round, opp["name"], opp["tag"]]
	title.add_theme_font_size_override("font_size", 20)
	top.add_child(title)
	_timer_label = Label.new()
	_timer_label.text = "时间 0.0s"
	_timer_label.add_theme_font_size_override("font_size", 20)
	_timer_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(_timer_label)
	_speed_btn = Button.new()
	_speed_btn.text = "速度 1×（空格）"
	_speed_btn.custom_minimum_size.x = 150
	_speed_btn.pressed.connect(toggle_speed)
	top.add_child(_speed_btn)
	var pause_btn := Button.new()
	pause_btn.text = "暂停（Esc）"
	pause_btn.custom_minimum_size.x = 110
	pause_btn.pressed.connect(toggle_pause)
	top.add_child(pause_btn)

	# 双方面板
	var panels := HBoxContainer.new()
	panels.add_theme_constant_override("separation", 14)
	panels.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(panels)
	_p_icons = HBoxContainer.new()
	_p_icons.add_theme_constant_override("separation", 6)
	_e_icons = HBoxContainer.new()
	_e_icons.add_theme_constant_override("separation", 6)
	_p_effects = Label.new()
	_e_effects = Label.new()
	_p_effects.add_theme_font_size_override("font_size", 13)
	_e_effects.add_theme_font_size_override("font_size", 13)
	_p_effects.custom_minimum_size.y = 44
	_e_effects.custom_minimum_size.y = 44
	_p_effects.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_e_effects.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_p_panel = _make_combatant_panel("玩家", true, _p_icons, _p_effects)
	_e_panel = _make_combatant_panel(opp["name"], false, _e_icons, _e_effects)
	panels.add_child(_p_panel)
	panels.add_child(_e_panel)

	# 日志
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.custom_minimum_size.y = 170
	_log.scroll_following = true
	vb.add_child(_log)
	_add_log("[color=#9aa7b5]战斗开始！装备已锁定，自动战斗中……[/color]")

	_float_layer = Control.new()
	_float_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_float_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_float_layer)

	_pause_overlay = _make_overlay("已暂停", ["继续", "返回主菜单（放弃本场）"])
	_end_overlay = _make_overlay("", ["确定"])
	_end_overlay.visible = false

func _make_combatant_panel(cname: String, is_player: bool, icons: HBoxContainer, effects: Label) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.18, 0.19, 0.24)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", sb)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)
	var name_label := Label.new()
	name_label.text = cname
	name_label.add_theme_font_size_override("font_size", 18)
	vb.add_child(name_label)
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = 100
	bar.value = 100
	bar.custom_minimum_size.y = 30
	bar.show_percentage = false
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.1, 0.1, 0.13)
	bar_bg.set_corner_radius_all(5)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color("4fae62") if is_player else Color("d65f52")
	bar_fill.set_corner_radius_all(5)
	bar.add_theme_stylebox_override("background", bar_bg)
	bar.add_theme_stylebox_override("fill", bar_fill)
	vb.add_child(bar)
	var hp_label := Label.new()
	hp_label.text = "生命 100/100 · 护盾 0"
	hp_label.add_theme_font_size_override("font_size", 14)
	vb.add_child(hp_label)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 86
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	icons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(icons)
	vb.add_child(effects)
	if is_player:
		_hp_bar = bar
		_hp_label = hp_label
	else:
		_en_hp_bar = bar
		_en_hp_label = hp_label
	# 填充装备图标（武器显示冷却，其它显示静态效果）
	var c: Combatant = sim.player if is_player else sim.enemy
	_populate_icons(c, "player" if is_player else "enemy", icons)
	return panel

func _populate_icons(c: Combatant, side: String, icons: HBoxContainer) -> void:
	# 武器
	for w in c.weapons:
		var v := ItemView.make(w["type"], w["uid"], Vector2(58, 58))
		v.set_cooldown(1.0)
		icons.add_child(v)
		_cooldown_views[side + ":" + str(w["uid"])] = v
	# 其它装备（从 stats 反查类型）
	for src in c.stats.poison_sources:
		icons.add_child(ItemView.make(ItemDef.POISON, src["uid"], Vector2(58, 58)))
	if c.stats.shield_total > 0:
		icons.add_child(ItemView.make(ItemDef.SHIELD, -1, Vector2(58, 58)))
	for i in c.stats.heal_count:
		icons.add_child(ItemView.make(ItemDef.HEAL, 1000 + i, Vector2(58, 58)))

func _make_overlay(otext: String, buttons: Array) -> Control:
	var layer := ColorRect.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.color = Color(0, 0, 0, 0.62)
	add_child(layer)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.add_theme_constant_override("separation", 16)
	layer.add_child(box)
	var l := Label.new()
	l.name = "Headline"
	l.text = otext
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 30)
	box.add_child(l)
	for btext in buttons:
		var b := Button.new()
		b.text = btext
		b.custom_minimum_size = Vector2(260, 46)
		b.add_theme_font_size_override("font_size", 17)
		box.add_child(b)
		if btext == "继续":
			b.pressed.connect(toggle_pause)
		elif btext.begins_with("返回主菜单"):
			b.pressed.connect(_abandon_to_menu)
		elif btext == "确定":
			b.pressed.connect(_confirm_end)
	layer.visible = false
	return layer

# ---------------- 模拟驱动 ----------------

func _process(delta: float) -> void:
	if paused or _ended:
		return
	_accum += delta * speeds[speed_idx]
	while _accum >= SIM_DT and not sim.finished:
		_accum -= SIM_DT
		var events := sim.advance(SIM_DT)
		for ev in events:
			_handle_event(ev)
	_refresh_panel()
	if sim.finished and not _ended:
		_ended = true
		_show_end()

func _handle_event(ev: Dictionary) -> void:
	match ev["kind"]:
		"hit":
			_add_log("[color=#ff8a7a]%s[/color]" % ev["text"])
			_spawn_float(ev["side"], "-%d" % ev["amount"], Color("ff7a6b"))
		"shield":
			_add_log("[color=#8fc2ff]%s[/color]" % ev["text"])
			_spawn_float(ev["side"], "盾-%d" % ev["amount"], Color("8fc2ff"))
		"heal":
			_add_log("[color=#9be8a4]%s[/color]" % ev["text"])
			_spawn_float(ev["side"], "+%d" % ev["amount"], Color("9be8a4"))
		"poison":
			_add_log("[color=#c9a0ff]%s[/color]" % ev["text"])
			_spawn_float(ev["side"], "毒-%d" % ev["amount"], Color("c9a0ff"))
		_:
			_add_log("[color=#ffd34d]%s[/color]" % ev["text"])

func _refresh_panel() -> void:
	_hp_bar.value = sim.player.hp
	_en_hp_bar.value = sim.enemy.hp
	_hp_label.text = "生命 %d/%d · 护盾 %d" % [sim.player.hp, sim.player.max_hp, sim.player.shield]
	_en_hp_label.text = "生命 %d/%d · 护盾 %d" % [sim.enemy.hp, sim.enemy.max_hp, sim.enemy.shield]
	_timer_label.text = "时间 %.1fs" % sim.time
	_p_effects.text = _effect_summary(sim.player)
	_e_effects.text = _effect_summary(sim.enemy)
	# 冷却
	for w in sim.player.weapons:
		var v: ItemView = _cooldown_views.get("player:" + str(w["uid"]))
		if v:
			v.set_cooldown(clampf(w["time_left"] / w["interval"], 0.0, 1.0))
	for w in sim.enemy.weapons:
		var v: ItemView = _cooldown_views.get("enemy:" + str(w["uid"]))
		if v:
			v.set_cooldown(clampf(w["time_left"] / w["interval"], 0.0, 1.0))

func _effect_summary(c: Combatant) -> String:
	var parts: Array[String] = []
	var active_poisons := 0
	for src in c.poisons:
		if src["ticks_left"] > 0:
			active_poisons += 1
	if active_poisons > 0:
		parts.append("中毒来源 ×%d" % active_poisons)
	if c.heal_amount > 0:
		parts.append("治疗瓶 %s（%d 点）" % ["已用" if c.heal_used else "待命", c.heal_amount])
	if c.shield > 0:
		parts.append("护盾 %d" % c.shield)
	if parts.is_empty():
		return "无持续效果"
	return " · ".join(parts)

func _add_log(line: String) -> void:
	_log.append_text("[color=#6b7280][%.1fs][/color] %s\n" % [sim.time, line])

func _spawn_float(side: String, text: String, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", 26)
	var anchor: Control = _p_panel if side == "player" else _e_panel
	# 飘字在对应面板上半区随机出现，并向上淡出（全局坐标换算到飘字层）
	var global_base: Vector2 = anchor.global_position
	var local_base: Vector2 = global_base - _float_layer.global_position
	l.position = local_base + Vector2(randf_range(anchor.size.x * 0.25, anchor.size.x * 0.6),
		randf_range(30, anchor.size.y * 0.45))
	_float_layer.add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "position:y", l.position.y - 46, 0.9)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.9)
	tw.tween_callback(l.queue_free)

# ---------------- 控制 ----------------

func toggle_speed() -> void:
	speed_idx = 1 - speed_idx
	_speed_btn.text = "速度 %d×（空格）" % speeds[speed_idx]

func toggle_pause() -> void:
	paused = not paused
	_pause_overlay.visible = paused

func _abandon_to_menu() -> void:
	# 放弃本场按失败结算
	_ended = true
	paused = false
	finished.emit("lose", {"abandoned": true})

func _show_end() -> void:
	var result := sim.result
	var headline := ""
	match result:
		"win": headline = "胜利！"
		"lose": headline = "失败……"
		_: headline = "平局"
	var sub := ""
	if sim.reason == "timeout":
		sub = "\n60 秒未分胜负，按平局结算"
	elif result == "draw":
		sub = "\n双方同时倒下，按平局结算"
	var l: Label = _end_overlay.find_child("Headline", true, false)
	l.text = "%s%s\n剩余生命：你 %d / 对手 %d" % [headline, sub, sim.player.hp, sim.enemy.hp]
	_end_overlay.visible = true

func _confirm_end() -> void:
	finished.emit(sim.result, {"abandoned": false})

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			toggle_speed()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and not _ended:
			toggle_pause()
			get_viewport().set_input_as_handled()
