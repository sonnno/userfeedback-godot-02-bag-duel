class_name ShopScreen
extends Control
## 商店 + 背包整理：购买 / 出售 / 刷新 / 拖拽 / 旋转 / 悬停提示 / 联动高亮 / 对手预览

signal start_battle
signal state_changed

const SELL_ZONE_COLOR := Color("8a4b3a")

var state: GameState
var bag_view: GridView
var staging_view: GridView
var opponent_view: GridView

var _gold_label: Label
var _meta_label: Label
var _shop_cards: Array[Button] = []
var _tooltip: PanelContainer
var _tooltip_label: Label
var _message_label: Label
var _sell_zone: Panel
var _selected_uid: int = -1
var _hover_uid: int = -1

# 拖拽状态
var _drag_item: ItemInstance = null
var _drag_from := ""           # bag | staging
var _drag_view: GridView
var _drag_rotated := false
var _drag_offset := Vector2.ZERO
var _drag_layer: ItemView
var _message_timer := 0.0

func _init(p_state: GameState) -> void:
	state = p_state
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	_refresh_all()
	set_process(true)

# ---------------- 构建 UI ----------------

func _build_ui() -> void:
	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 12)
	root.add_theme_constant_override("margin_right", 12)
	root.add_theme_constant_override("margin_top", 8)
	root.add_theme_constant_override("margin_bottom", 8)
	add_child(root)

	var main := VBoxContainer.new()
	main.add_theme_constant_override("separation", 8)
	root.add_child(main)

	# 顶部状态栏
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 24)
	main.add_child(top)
	_gold_label = _make_header(top, "")
	_meta_label = _make_header(top, "")
	var hint_top := _make_header(top, "拖拽移动 · R/滚轮旋转 · 点选查看联动 · Esc 暂停")
	hint_top.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint_top.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# 内容区
	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(content)

	# 左：背包 + 暂存区
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	content.add_child(left)

	bag_view = GridView.new(state.bag, "背包（7×6，右下 2×2 禁用；仅背包内装备参战）")
	bag_view.cell_clicked.connect(_on_grid_clicked)
	left.add_child(bag_view)

	var mid_row := HBoxContainer.new()
	mid_row.add_theme_constant_override("separation", 14)
	left.add_child(mid_row)
	staging_view = GridView.new(state.staging, "包外暂存区（不参战，仅用于整理）")
	staging_view.cell_clicked.connect(_on_grid_clicked)
	mid_row.add_child(staging_view)

	_sell_zone = _make_sell_zone()
	mid_row.add_child(_sell_zone)

	# 右：商店 + 对手 + 按钮（滚动容器兜底）
	var right_scroll := ScrollContainer.new()
	right_scroll.custom_minimum_size.x = 350
	right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(right_scroll)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.custom_minimum_size.x = 340
	right_scroll.add_child(right)

	right.add_child(_section("商店（点击卡片购买，自动放入空位）"))
	for i in GameState.SHOP_SIZE:
		var card := Button.new()
		card.custom_minimum_size = Vector2(320, 46)
		card.pressed.connect(_on_buy.bind(i))
		card.mouse_entered.connect(_on_card_hover.bind(i, true))
		card.mouse_exited.connect(_on_card_hover.bind(i, false))
		right.add_child(card)
		_shop_cards.append(card)

	var shop_btns := HBoxContainer.new()
	shop_btns.add_theme_constant_override("separation", 8)
	right.add_child(shop_btns)
	var reroll := Button.new()
	reroll.text = "刷新（1 金币）"
	reroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reroll.pressed.connect(_on_reroll)
	shop_btns.add_child(reroll)

	right.add_child(HSeparator.new())
	var sell_btn := Button.new()
	sell_btn.text = "出售选中装备（返还半价）"
	sell_btn.pressed.connect(_on_sell_selected)
	right.add_child(sell_btn)
	var rotate_btn := Button.new()
	rotate_btn.text = "旋转选中装备（R）"
	rotate_btn.pressed.connect(_on_rotate_selected)
	right.add_child(rotate_btn)

	right.add_child(HSeparator.new())
	right.add_child(_section("本场对手（悬停装备查看详情）"))
	var opp_data: Dictionary = Opponents.list()[state.current_opponent_index()]
	var opp_title := Label.new()
	opp_title.text = "%s · %s\n%s" % [opp_data["name"], opp_data["tag"], opp_data["desc"]]
	opp_title.add_theme_font_size_override("font_size", 13)
	opp_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	opp_title.custom_minimum_size.x = 320
	right.add_child(opp_title)
	var opp_bag := Opponents.build_bag(state.current_opponent_index())
	opponent_view = GridView.new(opp_bag, "")
	opponent_view.interactive = false
	# 用整数倍 0.5 缩放避免半像素模糊；布局尺寸手动压缩到缩放后大小
	const OPP_SCALE := 0.5
	opponent_view.scale = Vector2(OPP_SCALE, OPP_SCALE)
	opponent_view.position = Vector2.ZERO
	var scaled_size := opponent_view.custom_minimum_size * OPP_SCALE
	opponent_view.custom_minimum_size = scaled_size
	opponent_view.size = scaled_size
	var preview_box := PanelContainer.new()
	preview_box.custom_minimum_size = Vector2(scaled_size.x + 16, scaled_size.y + 16)
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(0.16, 0.17, 0.21)
	psb.set_corner_radius_all(8)
	preview_box.add_theme_stylebox_override("panel", psb)
	var opp_wrap := MarginContainer.new()
	opp_wrap.add_theme_constant_override("margin_left", 8)
	opp_wrap.add_theme_constant_override("margin_top", 8)
	opp_wrap.custom_minimum_size = scaled_size
	opp_wrap.add_child(opponent_view)
	preview_box.add_child(opp_wrap)
	right.add_child(preview_box)

	right.add_child(HSeparator.new())
	var battle_btn := Button.new()
	battle_btn.text = "锁定装备并开始战斗"
	battle_btn.custom_minimum_size = Vector2(320, 48)
	battle_btn.add_theme_font_size_override("font_size", 18)
	battle_btn.pressed.connect(func(): start_battle.emit())
	right.add_child(battle_btn)

	# 底部消息条
	_message_label = Label.new()
	_message_label.text = ""
	_message_label.add_theme_color_override("font_color", Color("ffd34d"))
	main.add_child(_message_label)

	# 悬停提示（浮层）
	_tooltip = PanelContainer.new()
	_tooltip.visible = false
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.13, 0.17, 0.97)
	sb.border_color = Color("ffd34d")
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 7
	sb.content_margin_bottom = 7
	_tooltip.add_theme_stylebox_override("panel", sb)
	_tooltip_label = Label.new()
	_tooltip_label.custom_minimum_size.x = 250
	_tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tooltip.add_child(_tooltip_label)
	add_child(_tooltip)

	# 拖拽浮层
	_drag_layer = ItemView.make("", -1, Vector2.ONE)
	_drag_layer.visible = false
	_drag_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_drag_layer)

func _make_header(parent: Node, text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 18)
	parent.add_child(l)
	return l

func _section(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 16)
	return l

func _make_sell_zone() -> Panel:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(180, 150)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(SELL_ZONE_COLOR, 0.35)
	sb.border_color = SELL_ZONE_COLOR
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	p.add_theme_stylebox_override("panel", sb)
	var l := Label.new()
	l.text = "出售区\n拖到此处出售\n返还 ⌊买价/2⌋"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.add_theme_color_override("font_color", Color("f2b8a4"))
	p.add_child(l)
	return p

# ---------------- 数据刷新 ----------------

func _refresh_all() -> void:
	_gold_label.text = "金币：%d" % state.gold
	_meta_label.text = "第 %d 轮 · 生命 %d · 胜场 %d/%d" % [state.round, state.lives, state.wins, GameState.WINS_NEEDED]
	bag_view.rebuild()
	staging_view.rebuild()
	_refresh_cards()
	_update_synergy_highlights()

func _refresh_cards() -> void:
	for i in _shop_cards.size():
		var card: Button = _shop_cards[i]
		if i >= state.shop.size():
			card.visible = false
			continue
		card.visible = true
		var type := state.shop[i]
		card.text = "%s  %s\n%d×%d · %d 金币 · %s" % [
			ItemDef.d(type, "icon"), ItemDef.display_name(type),
			ItemDef.base_size(type).x, ItemDef.base_size(type).y,
			ItemDef.price(type), ItemDef.d(type, "effect")]
		card.disabled = state.gold < ItemDef.price(type)
		card.alignment = HORIZONTAL_ALIGNMENT_LEFT

func _flash(msg: String) -> void:
	_message_label.text = msg
	_message_timer = 2.5

func _process(delta: float) -> void:
	if _tooltip == null or _message_label == null:
		return
	if _message_timer > 0.0:
		_message_timer -= delta
		if _message_timer <= 0.0:
			_message_label.text = ""
	_update_hover()

# ---------------- 购买 / 出售 / 刷新 ----------------

func _on_buy(slot: int) -> void:
	if slot >= state.shop.size():
		return
	var type := state.shop[slot]
	if state.gold < ItemDef.price(type):
		_flash("金币不足，无法购买 %s" % ItemDef.display_name(type))
		return
	var it: ItemInstance = state.buy(slot)
	if it == null:
		_flash("背包和暂存区都没有空位，无法购买")
		return
	_flash("购入 %s，花费 %d 金币" % [ItemDef.display_name(type), ItemDef.price(type)])
	_refresh_all()
	state_changed.emit()

func _on_reroll() -> void:
	if not state.reroll():
		_flash("金币不足，无法刷新")
		return
	_flash("商店已刷新（花费 1 金币）")
	_refresh_all()
	state_changed.emit()

func _on_sell_selected() -> void:
	if _selected_uid < 0:
		_flash("请先点击选中一件装备")
		return
	var it := state.bag.get_item(_selected_uid)
	if it == null:
		it = state.staging.get_item(_selected_uid)
	if it == null:
		_selected_uid = -1
		return
	_do_sell(it)

func _do_sell(it: ItemInstance) -> void:
	var name := ItemDef.display_name(it.type)
	var refund := state.sell(it)
	if _selected_uid == it.uid:
		_selected_uid = -1
	_flash("出售 %s，返还 %d 金币" % [name, refund])
	_refresh_all()
	state_changed.emit()

func _on_rotate_selected() -> void:
	if _selected_uid < 0:
		_flash("请先点击选中一件装备")
		return
	var it := state.bag.get_item(_selected_uid)
	var g := state.bag
	if it == null:
		it = state.staging.get_item(_selected_uid)
		g = state.staging
	if it == null:
		_selected_uid = -1
		return
	_try_rotate(it, g)

func _try_rotate(it: ItemInstance, g: BagGrid) -> bool:
	var new_rot := not it.rotated
	if g.can_place_item(it, it.pos, new_rot, it.uid):
		g.remove_item(it)
		g.add_item(it, it.pos, new_rot, it.container)
		_refresh_all()
		state_changed.emit()
		return true
	_flash("旋转后越界或与其他装备重叠，已取消")
	return false

# ---------------- 拖拽 ----------------

func _on_grid_clicked(gv: GridView, cell: Vector2i, event: InputEvent) -> void:
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	if cell.x < 0:
		_select(-1)
		return
	var it: ItemInstance = gv.grid.item_at(cell)
	if it == null:
		_select(-1)
		return
	_select(it.uid)
	_begin_drag(it, gv, event)

func _select(uid: int) -> void:
	_selected_uid = uid
	_update_synergy_highlights()

func _begin_drag(it: ItemInstance, gv: GridView, event: InputEvent) -> void:
	_drag_item = it
	_drag_from = it.container
	_drag_view = gv
	_drag_rotated = it.rotated
	var r := gv.cell_rect(it.pos)
	_drag_offset = gv.global_position + r.position - get_global_mouse_position()
	var f := it.footprint()
	_drag_layer.item_type = it.type
	_drag_layer.item_uid = it.uid
	_drag_layer.size = Vector2(f.x * GridView.CELL + (f.x - 1) * GridView.GAP,
		f.y * GridView.CELL + (f.y - 1) * GridView.GAP)
	_drag_layer.custom_minimum_size = _drag_layer.size
	_drag_layer.visible = true
	gv.set_dimmed(it.uid, true)

func _process_drag_motion() -> void:
	if _drag_item == null:
		return
	_drag_layer.global_position = get_global_mouse_position() + _drag_offset
	var target_view := _hovered_grid()
	if target_view == null:
		bag_view.hide_ghost()
		staging_view.hide_ghost()
		return
	var local := target_view.get_local_mouse_position()
	var cell: Variant = target_view.cell_at_local(local)
	if cell == null:
		target_view.show_ghost(null, _drag_item.type, _drag_rotated, false)
		return
	var top_left: Vector2i = (cell as Vector2i) - _cell_offset_in_item(target_view, cell)
	var ok := target_view.grid.can_place_item(_drag_item, top_left, _drag_rotated, _drag_item.uid)
	target_view.show_ghost(top_left, _drag_item.type, _drag_rotated, ok)
	if target_view != bag_view:
		bag_view.hide_ghost()
	if target_view != staging_view:
		staging_view.hide_ghost()

## 鼠标在装备内的相对格，用于让装备以原抓取点跟随
func _cell_offset_in_item(gv: GridView, cell: Vector2i) -> Vector2i:
	var rel := cell - _drag_item.pos
	var f := ItemDef.footprint(_drag_item.type, _drag_rotated)
	rel.x = clampi(rel.x, 0, f.x - 1)
	rel.y = clampi(rel.y, 0, f.y - 1)
	return rel

func _hovered_grid() -> GridView:
	var m := get_local_mouse_position()
	if bag_view.get_global_rect().has_point(get_global_mouse_position()):
		return bag_view
	if staging_view.get_global_rect().has_point(get_global_mouse_position()):
		return staging_view
	return null

## 测试辅助：无头环境无法做 Viewport 命中，直接指定格子驱动拖拽预览
func _process_drag_motion_for_test(cell: Vector2i, target := "bag") -> void:
	if _drag_item == null:
		return
	var gv: GridView = bag_view if target == "bag" else staging_view
	var top_left: Vector2i = cell - _cell_offset_in_item(gv, cell)
	var ok := gv.grid.can_place_item(_drag_item, top_left, _drag_rotated, _drag_item.uid)
	gv.show_ghost(top_left, _drag_item.type, _drag_rotated, ok)
	if gv != bag_view:
		bag_view.hide_ghost()
	if gv != staging_view:
		staging_view.hide_ghost()

func _end_drag() -> void:
	if _drag_item == null:
		return
	var it := _drag_item
	var old_view := _drag_view
	var sell_drop := _sell_zone.get_global_rect().has_point(get_global_mouse_position())
	var target_view := _hovered_grid()
	if _drag_mouse_target == "bag":
		target_view = bag_view
	elif _drag_mouse_target == "staging":
		target_view = staging_view
	# 无头测试：只要指定了落点格而容器未知，默认落在背包
	if target_view == null and _drag_forced_cell != null:
		target_view = bag_view
	var forced_cell: Variant = _drag_forced_cell
	_drag_mouse_target = ""
	_drag_forced_cell = null
	bag_view.hide_ghost()
	staging_view.hide_ghost()
	_drag_layer.visible = false
	old_view.set_dimmed(it.uid, false)

	if sell_drop:
		_do_sell(it)
		_drag_item = null
		return
	if target_view == null:
		_flash("拖出有效区域，装备回到原位")
		_refresh_all()
		_drag_item = null
		return
	var cell: Variant = forced_cell
	if cell == null:
		cell = target_view.cell_at_local(target_view.get_local_mouse_position())
	if cell == null:
		_refresh_all()
		_drag_item = null
		return
	_finish_drop(it, target_view, cell)

## 测试辅助：指定松开时鼠标所在容器
var _drag_mouse_target := ""
## 测试辅助：指定松开时悬停的格子（绕过无头环境的鼠标命中）
var _drag_forced_cell: Variant = null

## 共用落点逻辑：校验、移动/跨容器、非法则回退
func _finish_drop(it: ItemInstance, target_view: GridView, cell: Variant) -> void:
	var top_left: Vector2i = (cell as Vector2i) - _cell_offset_in_item(target_view, cell)
	var rotated := _drag_rotated
	if not target_view.grid.can_place_item(it, top_left, rotated, it.uid):
		_flash("越界或重叠，装备回到拖拽前位置")
		_refresh_all()
		_drag_item = null
		return
	var source: BagGrid = state.bag if _drag_from == "bag" else state.staging
	var dest: BagGrid = target_view.grid
	var container_name := "bag" if target_view == bag_view else "staging"
	if source == dest:
		dest.remove_item(it)
	else:
		source.remove_item(it)
	dest.add_item(it, top_left, rotated, container_name)
	_refresh_all()
	state_changed.emit()
	_drag_item = null

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and _drag_item != null:
		_process_drag_motion()
	elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _drag_item != null:
		_end_drag()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP and _drag_item != null:
		_drag_rotated = not _drag_rotated
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_R:
		if _drag_item != null:
			_drag_rotated = not _drag_rotated
		else:
			_on_rotate_selected()
		get_viewport().set_input_as_handled()

func _on_card_hover(slot: int, entered: bool) -> void:
	if not entered or slot >= state.shop.size():
		if entered:
			return
		_tooltip.visible = false
		return
	_show_tooltip(state.shop[slot], -1)

# ---------------- 悬停提示与联动高亮 ----------------

func _update_hover() -> void:
	var uid := -1
	var type := ""
	# 背包 / 暂存区装备
	for gv in [bag_view, staging_view]:
		var cell: Variant = gv.cell_at_local(gv.get_local_mouse_position())
		if cell != null and gv.get_global_rect().has_point(get_global_mouse_position()):
			var it: ItemInstance = gv.grid.item_at(cell)
			if it != null:
				uid = it.uid
				type = it.type
	# 对手预览（只读）
	if uid < 0 and opponent_view.get_global_rect().has_point(get_global_mouse_position()):
		var cell: Variant = opponent_view.cell_at_local(opponent_view.get_local_mouse_position())
		if cell != null:
			var it: ItemInstance = opponent_view.grid.item_at(cell)
			if it != null:
				type = it.type
	if type != "":
		_show_tooltip(type, uid)
	else:
		_tooltip.visible = false
	if uid != _hover_uid:
		_hover_uid = uid
		_update_synergy_highlights()

func _show_tooltip(type: String, uid: int) -> void:
	var txt := "%s（%d×%d，%d 金币）\n%s" % [
		ItemDef.display_name(type), ItemDef.base_size(type).x, ItemDef.base_size(type).y,
		ItemDef.price(type), ItemDef.d(type, "effect")]
	var link: String = ItemDef.d(type, "link")
	if link != "":
		txt += "\n联动条件：" + link
	if uid >= 0:
		var stats := BuildStats.new(state.bag)
		for t in stats.link_texts(uid):
			txt += "\n★ " + t
	_tooltip_label.text = txt
	_tooltip.reset_size()
	var pos := get_global_mouse_position() + Vector2(18, 18)
	pos.x = minf(pos.x, size.x - _tooltip.size.x - 6)
	pos.y = minf(pos.y, size.y - _tooltip.size.y - 6)
	_tooltip.position = pos
	_tooltip.visible = true

func _update_synergy_highlights() -> void:
	bag_view.clear_highlights()
	staging_view.clear_highlights()
	var focus := _selected_uid if _selected_uid >= 0 else _hover_uid
	if focus < 0:
		return
	var stats := BuildStats.new(state.bag)
	var partners: Array = stats.highlighted_partners(focus)
	if partners.is_empty() and not stats.has_link(focus):
		return
	bag_view.set_highlight(focus, true)
	for p in partners:
		bag_view.set_highlight(p, true)
