extends Control
class_name PlaceView

## Simple city and outing scenes in the same warm palette as the room.
## Props are drawn here so a location is never an empty button panel.

var place_id := "map"
var portrait: Texture2D
var picture: Texture2D


func show_place(id: String, who: String = "f") -> void:
	place_id = id
	var file_id := "city" if id == "map" else id
	if who == "m" and file_id != "city":
		var male_path := "res://assets/places/%s_m.png" % file_id
		if ResourceLoader.exists(male_path):
			file_id = "%s_m" % file_id
	var loaded: Resource = load("res://assets/places/%s.png" % file_id)
	picture = loaded if loaded is Texture2D else null
	queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var box := get_size()
	if box.x < 8.0 or box.y < 8.0:
		return
	if picture != null:
		draw_texture_rect(picture, Rect2(Vector2.ZERO, box), false)
		return
	# Missing art stays an empty scene. Do not draw a block stand-in.
	match place_id:
		"park":
			_draw_park(box)
		"cinema":
			_draw_cinema(box)
		"mall":
			_draw_mall(box)
		"gym":
			_draw_gym(box)
		"library":
			_draw_library(box)
		_:
			_draw_map(box)
func _draw_map(box: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, box), Color("E7F0EA"))
	draw_rect(Rect2(0, box.y * 0.62, box.x, box.y * 0.38), Color("E4D2B0"))
	draw_rect(Rect2(0, box.y * 0.72, box.x, 28), Color("D7C4A2"))
	_building(Vector2(box.x * 0.16, box.y * 0.46), Vector2(150, 120), Color("8FB3A8"), "公园")
	_building(Vector2(box.x * 0.36, box.y * 0.40), Vector2(160, 150), Color("3E4A55"), "影院")
	_building(Vector2(box.x * 0.58, box.y * 0.42), Vector2(180, 140), Color("E7A090"), "商场")
	_building(Vector2(box.x * 0.78, box.y * 0.48), Vector2(140, 110), Color("C4A574"), "健身")
	_building(Vector2(box.x * 0.47, box.y * 0.62), Vector2(150, 100), Color("F3E6D0"), "图书馆")
	_text(Vector2(28, 86), "城市", 28, Color("3E4A45"))


func _draw_park(box: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, box), Color("D7E8F2"))
	draw_rect(Rect2(0, box.y * 0.42, box.x, box.y * 0.58), Color("A9C7A2"))
	draw_circle(Vector2(box.x * 0.82, box.y * 0.18), 36, Color("F6D58A"))
	_tree(Vector2(box.x * 0.18, box.y * 0.48))
	_tree(Vector2(box.x * 0.78, box.y * 0.52))
	draw_rect(Rect2(box.x * 0.28, box.y * 0.66, box.x * 0.44, 16), Color("E4D2B0"))
	var seat := Vector2(box.x * 0.46, box.y * 0.58)
	draw_rect(Rect2(seat, Vector2(150, 14)), Color("C4A574"))
	draw_rect(Rect2(seat + Vector2(12, 14), Vector2(8, 26)), Color("8A6244"))
	draw_rect(Rect2(seat + Vector2(130, 14), Vector2(8, 26)), Color("8A6244"))
	_caption("公园")


func _draw_cinema(box: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, box), Color("2C3338"))
	draw_rect(Rect2(box.x * 0.18, box.y * 0.12, box.x * 0.64, box.y * 0.34), Color("D7E4EA"))
	draw_rect(Rect2(box.x * 0.24, box.y * 0.18, box.x * 0.28, box.y * 0.16), Color("E7A090"))
	for row in 3:
		var y := box.y * (0.58 + float(row) * 0.1)
		draw_rect(Rect2(box.x * 0.22, y, box.x * 0.56, 22), Color("5C6B66"))
	_caption("电影院")


func _draw_mall(box: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, box), Color("F6EFE4"))
	draw_rect(Rect2(0, box.y * 0.72, box.x, box.y * 0.28), Color("E4D2B0"))
	var shops: Array = [Color("E7A090"), Color("8FB3A8"), Color("C4A574")]
	var names: Array = ["吃的", "家具", "房子"]
	for i in 3:
		var x := box.x * (0.08 + float(i) * 0.3)
		draw_rect(Rect2(x, box.y * 0.22, box.x * 0.24, box.y * 0.42), Color("FBF7F1"))
		draw_rect(Rect2(x + 16, box.y * 0.28, box.x * 0.24 - 32, box.y * 0.2), shops[i])
		_text(Vector2(x + 24, box.y * 0.58), str(names[i]), 18, Color("3E4A45"))
	_caption("商场")


func _draw_gym(box: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, box), Color("EEF3F1"))
	draw_rect(Rect2(0, box.y * 0.7, box.x, box.y * 0.3), Color("D7C4A2"))
	draw_rect(Rect2(box.x * 0.18, box.y * 0.48, box.x * 0.34, box.y * 0.16), Color("8FB3A8"))
	draw_circle(Vector2(box.x * 0.68, box.y * 0.52), 22, Color("5C6B66"))
	draw_rect(Rect2(box.x * 0.62, box.y * 0.5, 90, 10), Color("8A6244"))
	draw_circle(Vector2(box.x * 0.78, box.y * 0.52), 22, Color("5C6B66"))
	_caption("健身房")


func _draw_library(box: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, box), Color("F6EFE4"))
	draw_rect(Rect2(box.x * 0.08, box.y * 0.16, 28, box.y * 0.5), Color("C4A574"))
	for i in 8:
		var tone := Color("E25B4A") if i % 2 == 0 else Color("3E8C86")
		draw_rect(Rect2(box.x * 0.1, box.y * 0.2 + float(i) * 28.0, 18, 24), tone)
	draw_rect(Rect2(box.x * 0.28, box.y * 0.18, box.x * 0.22, box.y * 0.46), Color("E7F0EA"))
	draw_rect(Rect2(box.x * 0.58, box.y * 0.62, box.x * 0.28, 16), Color("C4A574"))
	_caption("图书馆")


func _building(at: Vector2, size: Vector2, color: Color, _label: String) -> void:
	draw_rect(Rect2(at, size), color)
	draw_rect(Rect2(at + Vector2(size.x * 0.35, size.y * 0.25), Vector2(size.x * 0.3, size.y * 0.35)), Color("FBF7F1"))


func _tree(at: Vector2) -> void:
	draw_rect(Rect2(at.x - 6, at.y, 12, 48), Color("8A6244"))
	draw_circle(at + Vector2(0, -8), 28, Color("6E9A72"))


func _caption(text: String) -> void:
	_text(Vector2(28, 86), text, 28, Color("FBF7F1") if place_id == "cinema" else Color("3E4A45"))


func _text(at: Vector2, text: String, size: int, color: Color) -> void:
	var font := ThemeDB.fallback_font
	if font == null:
		return
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func spot(anchor: Vector2) -> Vector2:
	return Vector2(get_size().x * anchor.x, get_size().y * anchor.y)
