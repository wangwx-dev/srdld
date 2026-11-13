extends Control
class_name IncomeChart

var points: Array = []
var cumulative := false


func _draw() -> void:
	var box := get_size()
	draw_rect(Rect2(Vector2.ZERO, box), Color("FFF8EE"))
	draw_rect(Rect2(Vector2(1, 1), box - Vector2(2, 2)), Color("E4D3BC"), false, 2.0)
	var font := ThemeDB.fallback_font
	var title := "累计到账（金）" if cumulative else "每日到账（金）"
	if font != null:
		draw_string(font, Vector2(12, 22), title, HORIZONTAL_ALIGNMENT_LEFT, box.x - 20, 16, Color("2C241C"))
	if points.is_empty():
		if font != null:
			draw_string(font, Vector2(16, box.y * 0.55), "还没有跨过结算", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("6E6258"))
		return
	var peak := 1.0
	for point in points:
		var key := "total" if cumulative else "amount"
		peak = maxf(peak, float(point.get(key, 0)) / 100.0)
	var left := 56.0
	var bottom := box.y - 28.0
	var top := 36.0
	var plot_h := bottom - top
	var plot_w := box.x - left - 12.0
	draw_line(Vector2(left, top), Vector2(left, bottom), Color("6E6258"), 1.5)
	draw_line(Vector2(left, bottom), Vector2(box.x - 12.0, bottom), Color("6E6258"), 1.5)
	if font != null:
		draw_string(font, Vector2(4, top + 12), "%.1f" % peak, HORIZONTAL_ALIGNMENT_LEFT, 48, 12, Color("6E6258"))
		draw_string(font, Vector2(4, bottom), "0", HORIZONTAL_ALIGNMENT_LEFT, 48, 12, Color("6E6258"))
	var slot := plot_w / float(points.size())
	var bar_w := minf(28.0, slot - 8.0)
	for index in points.size():
		var point: Dictionary = points[index]
		var key := "total" if cumulative else "amount"
		var gold := float(point.get(key, 0)) / 100.0
		var height := gold / peak * plot_h
		var x := left + float(index) * slot + (slot - bar_w) * 0.5
		draw_rect(Rect2(x, bottom - height, bar_w, height), Color("1F6F68"))
		if font != null:
			draw_string(font, Vector2(x, bottom + 16), str(int(point.get("day", index + 1))), HORIZONTAL_ALIGNMENT_LEFT, bar_w + 4, 12, Color("2C241C"))
