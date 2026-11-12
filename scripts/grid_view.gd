class_name GridView
extends Control
## 格子绘制 + 装备视图承载 + 放置预览（绿/红幽灵格）

signal cell_clicked(grid_view: GridView, cell: Vector2i, event: InputEvent)

const CELL := 54
const GAP := 3

var grid: BagGrid
var interactive := true
var title := ""

var _views: Dictionary = {}          # uid -> ItemView
var _ghost: ItemView
var _title_label: Label

func _init(g: BagGrid, p_title: String = "") -> void:
	grid = g
	title = p_title
	custom_minimum_size = Vector2(g.dims.x * (CELL + GAP) + GAP, g.dims.y * (CELL + GAP) + GAP + 26)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	_title_label = Label.new()
	_title_label.text = title
	_title_label.position = Vector2(4, 2)
	_title_label.add_theme_font_size_override("font_size", 15)
	add_child(_title_label)
	_ghost = ItemView.make("", -1, Vector2.ONE)
	_ghost.visible = false
	add_child(_ghost)
	rebuild()

func grid_origin() -> Vector2:
	return Vector2(GAP, 26)

func cell_rect(cell: Vector2i) -> Rect2:
	var o := grid_origin()
	return Rect2(o + Vector2(cell.x * (CELL + GAP), cell.y * (CELL + GAP)), Vector2(CELL, CELL))

func cell_at_local(local: Vector2) -> Variant:
	var o := grid_origin() / scale
	var p := local - o
	if p.x < 0 or p.y < 0:
		return null
	var step := (CELL + GAP) / scale.x
	var x := floori(p.x / step)
	var y := floori(p.y / step)
	if x >= grid.dims.x or y >= grid.dims.y:
		return null
	# 点在间隙里也算最近格，但若超出格子右/下边缘太多则忽略
	var cell := Vector2i(x, y)
	if not cell_rect(cell).grow(GAP).has_point(local * scale):
		return null
	return cell

func _draw() -> void:
	var font := ThemeDB.fallback_font
	for x in grid.dims.x:
		for y in grid.dims.y:
			var cell := Vector2i(x, y)
			var r := cell_rect(cell)
			var style := StyleBoxFlat.new()
			style.set_corner_radius_all(4)
			style.set_border_width_all(1)
			if grid.is_blocked(cell):
				style.bg_color = Color(0.16, 0.15, 0.18)
				style.border_color = Color(0.32, 0.3, 0.36)
				draw_style_box(style, r)
				draw_line(r.position + Vector2(6, 6), r.end - Vector2(6, 6), Color(0.45, 0.42, 0.5), 2.0)
				draw_line(Vector2(r.position.x + 6, r.end.y - 6), Vector2(r.end.x - 6, r.position.y + 6), Color(0.45, 0.42, 0.5), 2.0)
			else:
				style.bg_color = Color(0.23, 0.24, 0.29)
				style.border_color = Color(0.36, 0.38, 0.45)
				draw_style_box(style, r)

## 依据 grid.items 重建所有装备视图
func rebuild() -> void:
	for v in _views.values():
		v.queue_free()
	_views.clear()
	for it in grid.items:
		_add_view(it)

func _add_view(it: ItemInstance) -> void:
	var f := it.footprint()
	var v := ItemView.make(it.type, it.uid,
		Vector2(f.x * CELL + (f.x - 1) * GAP, f.y * CELL + (f.y - 1) * GAP))
	v.position = _unscaled_cell_origin(it.pos)
	add_child(v)
	_views[it.uid] = v

## 单元格左上角在本控件本地坐标系中的位置（考虑 scale）
func _unscaled_cell_origin(cell: Vector2i) -> Vector2:
	var o := grid_origin()
	return (o + Vector2(cell.x * (CELL + GAP), cell.y * (CELL + GAP))) / scale

func view_for(uid: int) -> ItemView:
	return _views.get(uid)

func set_highlight(uid: int, on: bool) -> void:
	var v: ItemView = _views.get(uid)
	if v:
		v.highlight = on
		v.queue_redraw()

func clear_highlights() -> void:
	for v in _views.values():
		v.highlight = false
		v.queue_redraw()

func set_dimmed(uid: int, on: bool) -> void:
	var v: ItemView = _views.get(uid)
	if v:
		v.dimmed = on
		v.queue_redraw()

## 显示占格预览；cell 为左上角格，foot 占格；ok 控制绿/红
func show_ghost(cell: Variant, type: String, rotated: bool, ok: bool) -> void:
	if cell == null:
		_ghost.visible = false
		return
	var f := ItemDef.footprint(type, rotated)
	_ghost.item_type = type
	_ghost.size = Vector2(f.x * CELL + (f.x - 1) * GAP, f.y * CELL + (f.y - 1) * GAP)
	_ghost.custom_minimum_size = _ghost.size
	_ghost.position = cell_rect(cell).position
	_ghost.ghost_ok = ok
	_ghost.ghost_bad = not ok
	_ghost.visible = true
	_ghost.queue_redraw()

func hide_ghost() -> void:
	_ghost.visible = false

func _gui_input(event: InputEvent) -> void:
	if not interactive:
		return
	if event is InputEventMouseButton and event.pressed:
		var cell: Variant = cell_at_local(event.position)
		cell_clicked.emit(self, cell if cell != null else Vector2i(-1, -1), event)
