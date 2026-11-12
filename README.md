# 行囊决斗（Bag Duel）

Godot 4.7.2 · 2D 背包构筑自动战斗 · Windows 键鼠 · 1280×720 · GL Compatibility · 零外部资源（UI 与图标全部程序绘制）

## 运行

用 Godot 4.7.2 打开本目录后按 F5，或命令行：

```powershell
& "Godot_v4.7.2-stable_win64.exe" --path .
```

## 玩法循环

商店购买装备 → 拖入 7×6 背包（右下角 2×2 禁用）→ 利用边相邻组成联动 → 锁定后自动战斗 → 战后回商店调整。初始 3 条命，累计 5 胜通关；失败或平局各扣 1 命，命尽失败。

## 操作

| 操作 | 方式 |
|---|---|
| 移动装备 | 鼠标拖拽，绿/红占格预览；非法放置回到原位 |
| 旋转 90° | R 键或鼠标滚轮（拖拽中/选中后均可） |
| 查看联动 | 点击选中或悬停，金框高亮当前生效的联动对象 |
| 出售 | 拖到出售区，或选中后点「出售」（返还 ⌊买价/2⌋） |
| 战斗速度 | 空格切换 1× / 2× |
| 暂停 | Esc |

## 装备与联动

- 匕首 1×2（4 伤/1.0s）、重剑 1×3（10 伤/2.4s）、弓 2×3（6 伤/2.0s 远程）
- 盾牌 2×2（开场 15 护盾）、箭袋 1×2、治疗瓶 1×1、毒瓶 1×1、磨刀石 1×1
- 磨刀石 ↔ 武器（边相邻，伤害 +2）；箭袋 ↔ 弓（间隔 ×0.8）；盾牌 ↔ 治疗瓶（回复 +10）
- 斜角不算相邻；同一来源对同一目标只生效一次，不同来源可叠加；移动/旋转/出售后立即重算
- 毒伤每秒一跳、持续 5 秒、穿盾，每个毒瓶独立计时
- 治疗瓶在生命首次低于 50% 时全部未用瓶各触发一次

## 工程结构

```
main.tscn / scripts/main.gd        屏幕管理：主菜单/商店/战斗/暂停/结算
scripts/item_def.gd                装备静态数据表
scripts/item_instance.gd           装备实例（uid、坐标、旋转态）
scripts/bag_grid.gd                格子容器：越界/重叠/禁用格校验、自动找空位
scripts/build_stats.gd             背包 → 战斗数值与联动关系（边相邻判定）
scripts/opponents.gd               7 套离线对手（快攻/毒蚀/弓手/均衡/护盾/重剑/混合）
scripts/combatant.gd               战斗单位：生命/护盾/冷却/治疗/中毒
scripts/battle_sim.gd              固定步长无随机战斗模拟器（可逐帧播放或一次跑完）
scripts/item_view.gd               装备程序绘制（色块+描边+中文单字+冷却遮罩）
scripts/grid_view.gd               格子绘制、占格预览、点击命中
scripts/shop_screen.gd             商店/背包整理/拖拽/悬停提示/对手预览
scripts/battle_screen.gd           战斗播放：血条/冷却/事件日志/飘字/速度/暂停
scripts/game_state.gd              金币/命/胜场/轮次、商店与经济规则
tests/run_tests.gd                 无头逻辑测试（77 项）
tests/smoke_test.gd                运行时冒烟测试（38 项，含拖拽链路）
tests/window_check.gd              带窗口启动并截图
```

## 测试

```powershell
# 逻辑测试（格子/联动/对手/战斗/经济，无需渲染）
godot --headless --path . --script res://tests/run_tests.gd

# 运行时冒烟测试（界面构建、购买、拖拽、战斗播放、菜单）
godot --headless --path . --script res://tests/smoke_test.gd

# 带窗口截图验证
godot --path . --script res://tests/window_check.gd
```

说明：Godot 无头模式不做 Viewport GUI 命中分发，因此拖拽测试通过本地事件直调
（`_gui_input` + 测试辅助落点）验证完整处理链路；真实鼠标交互在带窗口模式下正常。
