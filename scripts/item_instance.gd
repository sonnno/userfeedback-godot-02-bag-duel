class_name ItemInstance
extends RefCounted
## 装备实例：uid、类型、格坐标、旋转态、所在容器

static var _next_uid := 1

var uid: int
var type: String
var pos: Vector2i          # 左上角格坐标
var rotated: bool = false
var container := ""        # "bag" | "staging" | ""（尚未放置）

static func make(type: String) -> ItemInstance:
	var it := ItemInstance.new()
	it.uid = _next_uid
	_next_uid += 1
	it.type = type
	return it

func footprint() -> Vector2i:
	return ItemDef.footprint(type, rotated)

func cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var f := footprint()
	for x in range(pos.x, pos.x + f.x):
		for y in range(pos.y, pos.y + f.y):
			out.append(Vector2i(x, y))
	return out

func duplicate_instance() -> ItemInstance:
	var it := ItemInstance.new()
	it.uid = uid
	it.type = type
	it.pos = pos
	it.rotated = rotated
	it.container = container
	return it
