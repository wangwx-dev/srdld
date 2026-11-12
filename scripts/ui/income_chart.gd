extends Control
class_name IncomeChart

var points: Array = []


func _draw() -> void:
	var box := get_size()
	draw_rect(Rect2(Vector2.ZERO, box), Color("FFF8EE"))
	draw_rect(Rect2(Vector2(1, 1), box - Vector2(2, 2)), Color("C65B38"), false, 2.0)
	if points.is_empty():
		return
	var peak := 1.0
	for point in points:
		peak = maxf(peak, float(point.get("total", 0)))
	var width := minf(26.0, (box.x - 24.0) / float(points.size()) - 8.0)
	var font := ThemeDB.fallback_font
	for index in points.size():
		var point: Dictionary = points[index]
		var height := float(point.get("total", 0)) / peak * (box.y - 36.0)
		var origin := Vector2(16.0 + float(index) * (width + 12.0), box.y - 22.0 - height)
		draw_rect(Rect2(origin, Vector2(width, height)), Color("1F6F68"))
		if font != null:
			draw_string(font, Vector2(origin.x, box.y - 6.0), str(int(point.get("day", index + 1))), HORIZONTAL_ALIGNMENT_LEFT, width, 12, Color("2C241C"))
