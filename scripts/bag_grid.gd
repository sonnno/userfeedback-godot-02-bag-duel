class_name BagGrid
extends RefCounted
## 通用格子容器：放置校验（越界 / 重叠 / 禁用格）、自动找空位

var dims: Vector2i
var blocked: Array[Vector2i] = []
var items: Array[ItemInstance] = []

func _init(d: Vector2i = Vector2i(7, 6)) -> void:
	dims = d

func set_blocked(cells: Array[Vector2i]) -> void:
	blocked = cells.duplicate()

func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < dims.x and cell.y < dims.y

func item_at(cell: Vector2i) -> ItemInstance:
	for it in items:
		if it.cells().has(cell):
			return it
	return null

func is_blocked(cell: Vector2i) -> bool:
	return blocked.has(cell)

## 判断装备以 foot 占格放在 pos 是否合法（忽略 except_uid 这件，用于拖拽中的自身）
func can_place(foot: Vector2i, pos: Vector2i, except_uid: int = -1) -> bool:
	for x in range(pos.x, pos.x + foot.x):
		for y in range(pos.y, pos.y + foot.y):
			var cell := Vector2i(x, y)
			if not in_bounds(cell) or is_blocked(cell):
				return false
			var occ := item_at(cell)
			if occ != null and occ.uid != except_uid:
				return false
	return true

func can_place_item(it: ItemInstance, pos: Vector2i, rotated: bool, except_uid: int = -1) -> bool:
	return can_place(ItemDef.footprint(it.type, rotated), pos, except_uid)

## 从左上角开始扫描第一个能放下的空位；找不到返回 null
func find_empty(foot: Vector2i) -> Variant:
	for y in range(dims.y - foot.y + 1):
		for x in range(dims.x - foot.x + 1):
			var p := Vector2i(x, y)
			if can_place(foot, p):
				return p
	return null

func add_item(it: ItemInstance, pos: Vector2i, rotated: bool, container: String) -> bool:
	if not can_place(ItemDef.footprint(it.type, rotated), pos):
		return false
	it.pos = pos
	it.rotated = rotated
	it.container = container
	if not items.has(it):
		items.append(it)
	return true

func remove_item(it: ItemInstance) -> void:
	items.erase(it)
	it.container = ""

func get_item(uid: int) -> ItemInstance:
	for it in items:
		if it.uid == uid:
			return it
	return null

## 背包右下角 2×2 禁用格
static func make_bag() -> BagGrid:
	var g := BagGrid.new(Vector2i(7, 6))
	var b: Array[Vector2i] = []
	for x in range(5, 7):
		for y in range(4, 6):
			b.append(Vector2i(x, y))
	g.set_blocked(b)
	return g

static func make_staging() -> BagGrid:
	return BagGrid.new(Vector2i(6, 3))
