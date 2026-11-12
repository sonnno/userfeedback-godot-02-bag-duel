extends SceneTree
## --script 入口：SceneTree 包装器，异步测试主体在 SmokeTestRunner (Node) 内

func _initialize() -> void:
	var runner := SmokeTestRunner.new()
	root.add_child(runner)

class SmokeTestRunner extends Node:
	var failures: Array[String] = []
	var checks := 0

	func check(cond: bool, name: String) -> void:
		checks += 1
		if cond:
			print("  PASS: ", name)
		else:
			failures.append(name)
			print("  FAIL: ", name)

	func _ready() -> void:
		print("== 运行时冒烟测试 ==")
		var f := FontFile.new()
		if FileAccess.file_exists("C:/Windows/Fonts/msyh.ttc"):
			f.load_dynamic_font("C:/Windows/Fonts/msyh.ttc")
			ThemeDB.fallback_font.set_fallbacks([f])
		await test_shop_build()
		await test_drag_flow()
		await test_mouse_drag()
		await test_battle_playback()
		await test_menu_and_main()
		print("\n共 %d 项检查，失败 %d 项" % [checks, failures.size()])
		if failures.is_empty():
			print("冒烟测试全部通过 ✅")
			get_tree().quit(0)
		else:
			get_tree().quit(1)

	func test_shop_build() -> void:
		print("\n[A] 商店界面构建")
		var state := GameState.new()
		var shop := ShopScreen.new(state)
		add_child(shop)
		await get_tree().process_frame
		await get_tree().process_frame
		check(is_instance_valid(shop.bag_view), "背包 GridView 已创建")
		check(is_instance_valid(shop.staging_view), "暂存区 GridView 已创建")
		check(is_instance_valid(shop.opponent_view), "对手预览 GridView 已创建")
		check(shop._shop_cards.size() == 5, "5 张商店卡片")
		var visible_cards := 0
		for c in shop._shop_cards:
			if c.visible:
				visible_cards += 1
		check(visible_cards == 5, "5 张卡片均可见")
		check(shop.bag_view.get_global_rect().size.x > 300, "背包尺寸正常")
		var slot := -1
		for i in state.shop.size():
			if state.gold >= ItemDef.price(state.shop[i]):
				slot = i
				break
		var gold_before := state.gold
		var type := state.shop[slot]
		shop._on_buy(slot)
		await get_tree().process_frame
		check(state.gold == gold_before - ItemDef.price(type), "界面购买扣金币")
		check(state.bag.items.size() + state.staging.items.size() == 1, "购买后装备出现在包内/暂存区")
		shop._on_reroll()
		check(state.shop.size() == 5, "刷新后货架补满")
		shop.queue_free()
		await get_tree().process_frame

	func test_drag_flow() -> void:
		print("\n[B] 拖拽 / 旋转 / 出售流程")
		var gs := GameState.new()
		var shop := ShopScreen.new(gs)
		add_child(shop)
		await get_tree().process_frame
		var dagger := ItemInstance.make(ItemDef.DAGGER)
		gs.bag.add_item(dagger, Vector2i(0, 0), false, "bag")
		# 磨刀石放在匕首右侧列、只与匕首底端一格边相邻（旋转后也不重叠）
		var stone := ItemInstance.make(ItemDef.WHETSTONE)
		gs.bag.add_item(stone, Vector2i(1, 1), false, "bag")
		shop._refresh_all()
		await get_tree().process_frame
		check(is_instance_valid(shop.bag_view.view_for(dagger.uid)), "装备视图已渲染")
		shop._select(dagger.uid)
		await get_tree().process_frame
		var v: ItemView = shop.bag_view.view_for(dagger.uid)
		check(v.highlight, "选中装备自身金框高亮")
		check(shop.bag_view.view_for(stone.uid).highlight, "联动对象金框高亮")
		var ok := shop._try_rotate(dagger, gs.bag)
		check(ok and dagger.rotated and dagger.footprint() == Vector2i(2, 1), "匕首旋转为 2×1")
		# 出售：用独立干净状态，避免其它装备干扰金币断言
		var gs2 := GameState.new()
		var shop2 := ShopScreen.new(gs2)
		add_child(shop2)
		await get_tree().process_frame
		var solo := ItemInstance.make(ItemDef.DAGGER)
		gs2.bag.add_item(solo, Vector2i(0, 0), false, "bag")
		var refund := GameState.sell_value(solo.type)
		shop2._select(solo.uid)
		shop2._on_sell_selected()
		check(gs2.bag.get_item(solo.uid) == null and gs2.gold == GameState.START_GOLD + refund, "出售返还半价并移除装备")
		shop2.queue_free()
		var heal := ItemInstance.make(ItemDef.HEAL)
		var p: Variant = gs.staging.find_empty(Vector2i(1, 1))
		gs.staging.add_item(heal, p, false, "staging")
		shop._refresh_all()
		await get_tree().process_frame
		check(is_instance_valid(shop.staging_view.view_for(heal.uid)), "暂存区装备已渲染")
		var stats := BuildStats.new(gs.bag)
		check(stats.heal_count == 0, "暂存区治疗瓶不计入战斗数值")
		shop.queue_free()
		await get_tree().process_frame

	func test_mouse_drag() -> void:
		print("\n[B2] 鼠标事件处理链路（本地事件直调，无头环境不做 Viewport 命中分发）")
		var gs := GameState.new()
		var shop := ShopScreen.new(gs)
		add_child(shop)
		for i in 3:
			await get_tree().process_frame
		var dagger := ItemInstance.make(ItemDef.DAGGER)
		gs.bag.add_item(dagger, Vector2i(0, 0), false, "bag")
		shop._refresh_all()
		await get_tree().process_frame
		# 按下（0,0）格中心 -> 进入拖拽
		shop.bag_view._gui_input(_local_button(shop.bag_view, Vector2i(0, 0), MOUSE_BUTTON_LEFT, true))
		check(shop._drag_item != null and shop._drag_item.uid == dagger.uid, "鼠标按下进入拖拽态")
		# 移动到 (3,3) -> 幽灵预览（合法绿色）
		shop._process_drag_motion_for_test(Vector2i(3, 3))
		check(shop.bag_view._ghost.visible and shop.bag_view._ghost.ghost_ok, "合法位置显示绿色占格预览")
		# 松开（测试指定落点格）-> 装备落位。匕首 1×2 从其 (0,0) 格抓起，
		# 落在 (3,3) 时左上角回推为 (3,2)，这是抓取点跟随的正确行为
		shop._drag_forced_cell = Vector2i(3, 3)
		shop._end_drag()
		await get_tree().process_frame
		check(shop._drag_item == null, "松开后拖拽结束")
		var moved: ItemInstance = gs.bag.get_item(dagger.uid)
		check(moved != null and moved.pos == Vector2i(3, 2), "匕首抓取点跟随落到 (3,3)，左上角为 (3,2)（实际 %s）" % (str(moved.pos) if moved else "null"))
		# 非法拖放：拖到禁用格 (5,4)，应回到原位 (3,2)
		shop.bag_view._gui_input(_local_button(shop.bag_view, Vector2i(3, 2), MOUSE_BUTTON_LEFT, true))
		shop._process_drag_motion_for_test(Vector2i(5, 4))
		check(shop.bag_view._ghost.visible and shop.bag_view._ghost.ghost_bad, "禁用格上预览显示红色非法")
		shop._drag_forced_cell = Vector2i(5, 4)
		shop._end_drag()
		await get_tree().process_frame
		var still: ItemInstance = gs.bag.get_item(dagger.uid)
		check(still != null and still.pos == Vector2i(3, 2), "拖到禁用格非法，装备回到原位 (3,2)")
		# 拖拽中滚轮旋转
		shop.bag_view._gui_input(_local_button(shop.bag_view, Vector2i(3, 2), MOUSE_BUTTON_LEFT, true))
		var wheel := InputEventMouseButton.new()
		wheel.button_index = MOUSE_BUTTON_WHEEL_UP
		wheel.pressed = true
		shop._unhandled_input(wheel)
		check(shop._drag_item != null and shop._drag_rotated, "滚轮在拖拽中旋转装备")
		shop._drag_forced_cell = Vector2i(3, 2)
		shop._end_drag()
		await get_tree().process_frame
		# 跨容器：背包 -> 暂存区
		shop.bag_view._gui_input(_local_button(shop.bag_view, Vector2i(3, 2), MOUSE_BUTTON_LEFT, true))
		shop._drag_mouse_target = "staging"
		shop._drag_forced_cell = Vector2i(1, 1)
		shop._end_drag()
		await get_tree().process_frame
		check(gs.staging.get_item(dagger.uid) != null, "装备可从背包拖到暂存区")
		shop.queue_free()
		await get_tree().process_frame

	## 构造指向某 GridView 指定格子中心的本地鼠标按钮事件
	func _local_button(gv: GridView, cell: Vector2i, button: MouseButton, pressed: bool) -> InputEventMouseButton:
		var center: Vector2 = gv.cell_rect(cell).get_center()
		var ev := InputEventMouseButton.new()
		ev.button_index = button
		ev.pressed = pressed
		ev.position = center
		ev.global_position = gv.global_position + center
		return ev

	func test_battle_playback() -> void:
		print("\n[C] 战斗界面播放")
		var gs := GameState.new()
		var dagger := ItemInstance.make(ItemDef.DAGGER)
		gs.bag.add_item(dagger, Vector2i(0, 0), false, "bag")
		var stone := ItemInstance.make(ItemDef.WHETSTONE)
		gs.bag.add_item(stone, Vector2i(1, 0), false, "bag")
		var battle := BattleScreen.new(gs)
		add_child(battle)
		var done := [false]
		battle.finished.connect(func(r, d): done[0] = true)
		battle.speed_idx = 1
		var frames := 0
		while not battle.sim.finished and frames < 20000:
			await get_tree().process_frame
			frames += 1
		check(battle.sim.finished, "战斗在限定帧数内结束（共 %d 帧）" % frames)
		check(["win", "lose", "draw"].has(battle.sim.result), "战斗结果合法：%s" % battle.sim.result)
		check(battle._log.get_parsed_text().length() > 50, "事件日志有内容")
		check(not battle._cooldown_views.is_empty(), "冷却图标已生成")
		battle.toggle_pause()
		check(battle.paused and battle._pause_overlay.visible, "暂停覆盖层显示")
		battle.toggle_pause()
		battle.toggle_speed()
		check(battle.speed_idx == 0, "速度切回 1×")
		check(battle._end_overlay.visible, "结算覆盖层已显示")
		battle._confirm_end()
		# 信号回调可能在下一帧分发
		for i in 3:
			await get_tree().process_frame
		check(done[0], "确认结算发出 finished 信号")
		battle.queue_free()
		await get_tree().process_frame

	func test_menu_and_main() -> void:
		print("\n[D] 主场景（main.gd）启动")
		var main_scene: PackedScene = load("res://main.tscn")
		check(main_scene != null, "main.tscn 可加载")
		var main: Control = main_scene.instantiate()
		add_child(main)
		for i in 6:
			await get_tree().process_frame
		check(main.get_child_count() > 0, "主场景已生成界面")
		var start_btn := _find_button(main, "开始游戏")
		check(start_btn != null, "主菜单有开始游戏按钮")
		if start_btn:
			start_btn.pressed.emit()
			for i in 6:
				await get_tree().process_frame
			check(main.state != null and main.state.gold == 15, "点击后进入商店并初始化 15 金币")
			check(is_instance_valid(main._shop), "ShopScreen 已挂载")
			# 暂停菜单：直接调用与 Esc 同一路径的处理函数
			main._pause_menu()
			await get_tree().process_frame
			await get_tree().process_frame
			var dlg := _find_dialog(main, "暂停")
			check(dlg != null, "暂停菜单可弹出（与 Esc 同一处理函数）")
			if dlg:
				dlg.queue_free()
		main.queue_free()
		await get_tree().process_frame

	func _find_button(node: Node, text: String) -> Button:
		if node is Button and node.text == text:
			return node
		for c in node.get_children():
			var found := _find_button(c, text)
			if found:
				return found
		return null

	func _find_dialog(node: Node, title: String) -> Window:
		if node is Window and node.title == title:
			return node
		for c in node.get_children():
			var found := _find_dialog(c, title)
			if found:
				return found
		return null
