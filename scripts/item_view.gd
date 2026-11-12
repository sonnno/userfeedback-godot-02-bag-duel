class_name ItemView
extends Control
## 装备视觉：程序绘制色块 + 描边 + 中文单字图标，兼作战斗冷却图标

var item_type := ""
var item_uid := -1
var highlight := false          # 联动金框
var dimmed := false             # 拖拽中 / 不可用
var ghost_ok := false           # 占格预览（合法）
var ghost_bad := false          # 占格预览（非法）
var cooldown_ratio := -1.0      # 0..1 剩余冷却比例，<0 不显示
var show_cross := false         # 禁用格叉

static func make(it_type: String, uid: int, size: Vector2) -> ItemView:
	var v := ItemView.new()
	v.item_type = it_type
	v.item_uid = uid
	v.custom_minimum_size = size
	v.size = size
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return v

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if item_type == "":
		return
	var base: Color = ItemDef.d(item_type, "color", Color.GRAY)
	var fill := base
	if dimmed:
		fill = base.darkened(0.45)
	if ghost_ok:
		fill = Color(0.35, 0.85, 0.45, 0.45)
	elif ghost_bad:
		fill = Color(0.9, 0.3, 0.3, 0.5)
	# 圆角底块
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_corner_radius_all(6)
	style.set_border_width_all(2)
	if highlight:
		style.border_color = Color("ffd34d")
		style.set_border_width_all(3)
		style.shadow_color = Color(1.0, 0.83, 0.3, 0.55)
		style.shadow_size = 5
	else:
		style.border_color = base.darkened(0.45)
	if ghost_ok or ghost_bad:
		style.border_color = Color.WHITE
	draw_style_box(style, r)
	# 图标字
	var icon: String = ItemDef.d(item_type, "icon", "?")
	var font := ThemeDB.fallback_font
	var font_size := mini(size.x, size.y) * 0.42
	var ts := font.get_string_size(icon, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var col := Color.WHITE if not (ghost_ok or ghost_bad) else Color(1, 1, 1, 0.9)
	draw_string(font, Vector2((size.x - ts.x) / 2.0, (size.y + ts.y) / 2.0 - ts.y * 0.18),
		icon, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, col)
	# 冷却遮罩（从底部消退）
	if cooldown_ratio >= 0.0:
		var h := size.y * clampf(cooldown_ratio, 0.0, 1.0)
		draw_rect(Rect2(Vector2(0, size.y - h), Vector2(size.x, h)), Color(0, 0, 0, 0.45), true)

func set_cooldown(ratio: float) -> void:
	cooldown_ratio = ratio
	queue_redraw()
