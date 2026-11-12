extends Control
## 屏幕管理器：主菜单 / 商店 / 战斗 / 暂停与结算 / 通关失败重开

var state: GameState
var _current: Control = null
var _shop: ShopScreen = null
var _battle: BattleScreen = null

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_setup_cjk_font()
	_setup_inputs()
	_show_menu()

## 加载系统中文字体作为回退，保证中文与单字图标正常显示
func _setup_cjk_font() -> void:
	var candidates := [
		"C:/Windows/Fonts/msyh.ttc",
		"C:/Windows/Fonts/simhei.ttf",
		"C:/Windows/Fonts/simsun.ttc",
	]
	for path in candidates:
		if FileAccess.file_exists(path):
			var f := FontFile.new()
			if f.load_dynamic_font(path) == OK:
				ThemeDB.fallback_font.set_fallbacks([f])
			break

# 代码注册输入动作，避免在 project.godot 里手写冗长的 InputEvent 资源
func _setup_inputs() -> void:
	for action in ["ui_rotate", "ui_pause", "ui_speed"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	_add_key("ui_rotate", KEY_R)
	_add_key("ui_pause", KEY_ESCAPE)
	_add_key("ui_speed", KEY_SPACE)

func _add_key(action: String, keycode: Key) -> void:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey and ev.keycode == keycode:
			return
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	ev.keycode = keycode
	InputMap.action_add_event(action, ev)

func _swap(screen: Control) -> void:
	if _current:
		_current.queue_free()
	_current = screen
	add_child(screen)

# ---------------- 主菜单 ----------------

func _show_menu() -> void:
	var menu := Control.new()
	menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.add_theme_constant_override("separation", 18)
	menu.add_child(box)
	var title := Label.new()
	title.text = "行囊决斗"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 56)
	box.add_child(title)
	var sub := Label.new()
	sub.text = "背包构筑 · 位置联动 · 自动战斗"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 20)
	sub.add_theme_color_override("font_color", Color("9aa7b5"))
	box.add_child(sub)
	var start := Button.new()
	start.text = "开始游戏"
	start.custom_minimum_size = Vector2(280, 54)
	start.add_theme_font_size_override("font_size", 22)
	start.pressed.connect(_start_new_run)
	box.add_child(start)
	var help := Button.new()
	help.text = "操作提示"
	help.custom_minimum_size = Vector2(280, 44)
	help.pressed.connect(_show_help)
	box.add_child(help)
	var tip := Label.new()
	tip.text = "3 条命 · 累计 5 胜通关 · 失败或平局扣 1 命"
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.add_theme_color_override("font_color", Color("9aa7b5"))
	box.add_child(tip)
	_swap(menu)

func _show_help() -> void:
	var dlg := AcceptDialog.new()
	dlg.title = "操作提示"
	dlg.dialog_text = "\n".join([
		"【背包整理】",
		"· 鼠标拖拽移动装备；放下时显示绿/红占格预览，非法放置回到原位。",
		"· R 键或鼠标滚轮旋转 90°；1×1 装备旋转无效果。",
		"· 点击装备选中，金框标出当前生效的联动对象；悬停查看价格、占格与数值。",
		"· 拖到出售区或点「出售」返还 ⌊买价/2⌋；暂存区装备不参战。",
		"",
		"【商店】",
		"· 每轮 5 件装备，刷新花 1 金币；首轮保证有一件买得起的武器。",
		"",
		"【战斗】",
		"· 锁定装备后自动战斗；空格切换 1×/2× 速度，Esc 暂停。",
		"· 毒伤每秒一次、持续 5 秒、穿盾且各来源独立计时。",
		"· 同帧双亡或 60 秒未分胜负均为平局；战后 +8 金币并返回商店。",
	])
	add_child(dlg)
	dlg.popup_centered(Vector2i(720, 560))
	dlg.confirmed.connect(dlg.queue_free)
	dlg.canceled.connect(dlg.queue_free)

# ---------------- 流程 ----------------

func _start_new_run() -> void:
	state = GameState.new()
	_show_shop()

func _show_shop() -> void:
	_shop = ShopScreen.new(state)
	_shop.start_battle.connect(_start_battle)
	_swap(_shop)
	_shop = _current as ShopScreen

func _start_battle() -> void:
	# 暂存区有装备时给一次确认提示（不参战）
	if not state.staging.items.is_empty():
		var dlg := ConfirmationDialog.new()
		dlg.title = "确认开始战斗"
		dlg.dialog_text = "暂存区有 %d 件装备不会参战，确定要锁定并开始吗？" % state.staging.items.size()
		add_child(dlg)
		dlg.popup_centered()
		dlg.confirmed.connect(func():
			dlg.queue_free()
			_enter_battle())
		dlg.canceled.connect(dlg.queue_free)
	else:
		_enter_battle()

func _enter_battle() -> void:
	_battle = BattleScreen.new(state)
	_battle.finished.connect(_on_battle_finished)
	_swap(_battle)
	_battle = _current as BattleScreen

func _on_battle_finished(result: String, detail: Dictionary) -> void:
	var info: Dictionary = state.settle_battle(result)
	var title := ""
	match result:
		"win": title = "胜利"
		"lose": title = "失败（%s）" % ("主动放弃" if detail.get("abandoned", false) else "阵亡")
		_: title = "平局"
	var lines := [
		"本场结果：%s" % title,
		"获得金币：+%d（当前 %d）" % [info["reward"], state.gold],
	]
	if info["lost_life"]:
		lines.append("扣除 1 条命（剩余 %d）" % state.lives)
	if info["cleared"]:
		lines.append("累计 5 胜，通关成功！")
	elif info["defeated"]:
		lines.append("生命耗尽，本次挑战失败。")
	else:
		lines.append("当前胜场 %d/%d，下一轮对手已就位。" % [state.wins, GameState.WINS_NEEDED])
	var dlg := AcceptDialog.new()
	dlg.title = "战斗结算"
	dlg.dialog_text = "\n".join(lines)
	dlg.get_ok_button().text = "返回商店" if not info["cleared"] and not info["defeated"] else "回到主菜单"
	add_child(dlg)
	dlg.popup_centered(Vector2i(520, 320))
	dlg.confirmed.connect(func():
		dlg.queue_free()
		if info["cleared"] or info["defeated"]:
			_show_menu()
		else:
			_show_shop())

# 商店界面 Esc -> 暂停菜单
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if _current is ShopScreen:
			_pause_menu()

func _pause_menu() -> void:
	var dlg := ConfirmationDialog.new()
	dlg.title = "暂停"
	dlg.dialog_text = "游戏已暂停。确定要放弃当前进度并返回主菜单吗？"
	dlg.get_ok_button().text = "返回主菜单"
	dlg.get_cancel_button().text = "继续游戏"
	add_child(dlg)
	dlg.popup_centered(Vector2i(460, 200))
	dlg.confirmed.connect(func():
		dlg.queue_free()
		_show_menu())
	dlg.canceled.connect(dlg.queue_free)
