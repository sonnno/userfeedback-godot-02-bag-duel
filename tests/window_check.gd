extends SceneTree
## 带窗口快速启动验证：主菜单 -> 商店 -> 战斗，截图后退出

func _initialize() -> void:
	var f := FontFile.new()
	if FileAccess.file_exists("C:/Windows/Fonts/msyh.ttc"):
		f.load_dynamic_font("C:/Windows/Fonts/msyh.ttc")
		ThemeDB.fallback_font.set_fallbacks([f])
	var main: Control = load("res://main.tscn").instantiate()
	root.add_child(main)
	var runner := ShotRunner.new()
	root.add_child(runner)
	runner.main = main

class ShotRunner extends Node:
	var main: Control
	var step := 0

	func _process(_delta: float) -> void:
		step += 1
		if step == 30:
			await get_tree().process_frame
			var btn := _find(main, "开始游戏")
			btn.pressed.emit()
		elif step == 70:
			await get_tree().process_frame
			var img := get_viewport().get_texture().get_image()
			img.save_png("user://shot_shop.png")
			print("shop shot saved: ", ProjectSettings.globalize_path("user://shot_shop.png"))
			# 滚动右侧面板到底部，检查对手预览与战斗按钮
			var scrolls := _find_scrolls(main)
			for sc in scrolls:
				sc.scroll_vertical = 9999
			for i in 5:
				await get_tree().process_frame
			var img2 := get_viewport().get_texture().get_image()
			img2.save_png("user://shot_shop_bottom.png")
			print("shop bottom shot saved")
			# 进入战斗
			main._enter_battle()
		elif step == 110:
			await get_tree().process_frame
			var img := get_viewport().get_texture().get_image()
			img.save_png("user://shot_battle.png")
			print("battle shot saved: ", ProjectSettings.globalize_path("user://shot_battle.png"))
			# 检查战斗日志是否有事件
			var b: BattleScreen = main._battle
			print("battle log length: ", b._log.get_parsed_text().length())
			print("player hp: ", b.sim.player.hp, " enemy hp: ", b.sim.enemy.hp)
			get_tree().quit(0)

	func _find(node: Node, text: String) -> Button:
		if node is Button and node.text == text:
			return node
		for c in node.get_children():
			var r := _find(c, text)
			if r:
				return r
		return null

	func _find_scrolls(node: Node) -> Array:
		var out: Array = []
		if node is ScrollContainer:
			out.append(node)
		for c in node.get_children():
			out.append_array(_find_scrolls(c))
		return out
