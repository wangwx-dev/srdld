extends Control
class_name DeskBackdrop

var sky_phase := 1
var fan_ratios: Array = [0.4, 0.25, 0.18]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	var parent := get_parent() as Control
	if parent and size != parent.size:
		position = Vector2.ZERO
		size = parent.size
	queue_redraw()


func _draw() -> void:
	var size := get_size()
	if size.x < 10.0 or size.y < 10.0:
		return
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 700.0)
	_rect(Rect2(Vector2.ZERO, size), Color("E7D3BE"))
	var window := Rect2(size.x * 0.08, size.y * 0.06, size.x * 0.34, size.y * 0.42)
	_draw_sky(window)
	draw_rect(window.grow(8), Color("8C5A3C"), false, 8)
	_buildings(window)
	var orb := window.position + Vector2(window.size.x * 0.78, window.size.y * 0.28)
	var orb_color := Color("F6E2A8") if sky_phase < 3 else Color("F4F0D8")
	draw_circle(orb, 18, orb_color)
	_board(Rect2(size.x * 0.48, size.y * 0.1, size.x * 0.16, size.y * 0.28))
	var desk := Rect2(0, size.y * 0.62, size.x, size.y * 0.38)
	_rect(desk, Color("C4895A"))
	_rect(Rect2(0, desk.position.y, size.x, 14), Color("8C5A3C"))
	_monitor(Rect2(size.x * 0.1, size.y * 0.4, 210, 150))
	_notebook(Rect2(size.x * 0.34, size.y * 0.7, 150, 90))
	draw_circle(Vector2(size.x * 0.58, size.y * 0.78), 24, Color("F4F7F2"))
	draw_circle(Vector2(size.x * 0.58, size.y * 0.78), 16, Color("6F4E37"))
	_plant(Vector2(size.x * 0.78, size.y * 0.74))
	var lamp := Vector2(size.x * 0.9, size.y * 0.58)
	draw_line(lamp + Vector2(0, 70), lamp, Color("E7C27A"), 4)
	draw_circle(lamp, 26 + pulse * 4, Color(0.95, 0.78, 0.42, 0.28))
	draw_circle(lamp, 10, Color("F6D98A"))


func _draw_sky(window: Rect2) -> void:
	var top := Color("8EC8E6")
	var bottom := Color("D7EEF8")
	match sky_phase:
		0:
			top = Color("F6C99A")
			bottom = Color("F3E1C4")
		2:
			top = Color("F2A36B")
			bottom = Color("F6D2A8")
		3:
			top = Color("2C3E5A")
			bottom = Color("6E84A0")
	for i in 8:
		var t := float(i) / 8.0
		var band := Rect2(window.position.x, window.position.y + window.size.y * t, window.size.x, window.size.y / 8.0 + 1.0)
		_rect(band, top.lerp(bottom, t))


func _buildings(window: Rect2) -> void:
	var base := window.position.y + window.size.y
	var specs := [[0.08, 0.28, "6E7F86"], [0.28, 0.4, "596870"], [0.5, 0.22, "7E8E86"], [0.68, 0.34, "4E6270"]]
	for spec in specs:
		var rect := Rect2(window.position.x + window.size.x * float(spec[0]), base - window.size.y * float(spec[1]), window.size.x * 0.16, window.size.y * float(spec[1]))
		_rect(rect, Color(str(spec[2])))


func _board(rect: Rect2) -> void:
	_rect(rect, Color("8C5A3C"))
	_rect(rect.grow(-8), Color("C9894A"))
	_rect(Rect2(rect.position.x + 16, rect.position.y + 18, rect.size.x - 32, 28), Color("FFF8EE"))
	_rect(Rect2(rect.position.x + 16, rect.position.y + 54, rect.size.x - 32, 28), Color("F6E2A8"))


func _monitor(rect: Rect2) -> void:
	_rect(rect, Color("2C241C"))
	var screen := rect.grow(-12)
	screen.size.y -= 8
	_rect(screen, Color("FFF8EE"))
	var colors := [Color("C65B38"), Color("1F6F68"), Color("3D6EA8")]
	for i in 3:
		var ratio: float = float(fan_ratios[i]) if i < fan_ratios.size() else 0.2
		var h := screen.size.y * clampf(ratio, 0.08, 0.86)
		var bar := Rect2(screen.position.x + 16 + i * 52, screen.position.y + screen.size.y - h - 12, 32, h)
		_rect(bar, colors[i])
	_rect(Rect2(rect.position.x + rect.size.x * 0.35, rect.end.y - 8, rect.size.x * 0.3, 10), Color("8C5A3C"))


func _notebook(rect: Rect2) -> void:
	_rect(rect, Color("F7F1E4"))
	draw_line(rect.position + Vector2(rect.size.x * 0.5, 6), rect.position + Vector2(rect.size.x * 0.5, rect.size.y - 6), Color("E4D3BC"), 2)
	for i in 3:
		draw_line(rect.position + Vector2(12, 22 + i * 16), rect.position + Vector2(rect.size.x * 0.42, 22 + i * 16), Color("C65B38"), 2)


func _plant(origin: Vector2) -> void:
	_rect(Rect2(origin + Vector2(-16, 10), Vector2(32, 28)), Color("C65B38"))
	draw_circle(origin + Vector2(-10, -6), 16, Color("3E7C59"))
	draw_circle(origin + Vector2(12, -10), 18, Color("5E8F62"))
	draw_circle(origin + Vector2(0, -20), 14, Color("2F6B45"))


func _rect(rect: Rect2, color: Color) -> void:
	draw_rect(rect, color, true)
