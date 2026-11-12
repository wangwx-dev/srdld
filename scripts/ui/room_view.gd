extends Control
class_name RoomView

## Original cartoon rental room. Drawn in code so the light, monitor and
## character can move. SVG sheets in assets/art are the editable sources
## for the poster and the character design.

var sky_phase := 1
var pose := "idle"
var fan_ratios: Array = [0.45, 0.3, 0.22]
var trend_text := "生活"
var next_trend := "城市"
var sponsor := false
var stamina := 80.0
var mood := 70.0
var stress := 22.0
var time_sec := 0.0
var poster: Texture2D
var portrait: Texture2D

const INK := Color("2C241C")
const SKIN := Color("F3C3A1")
const SKIN_SHADOW := Color("E0A884")
const HAIR := Color("3A2C28")
const HOODIE := Color("E36B45")
const HOODIE_DARK := Color("C4512F")
const PANTS := Color("3D4E6B")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var loaded_poster: Resource = load("res://assets/art/persimmon.svg")
	if loaded_poster is Texture2D:
		poster = loaded_poster
	var loaded_portrait: Resource = load("res://assets/art/character_sheet.svg")
	if loaded_portrait is Texture2D:
		portrait = loaded_portrait


func _process(delta: float) -> void:
	time_sec += delta
	queue_redraw()


func _draw() -> void:
	var box := get_size()
	if box.x < 32.0 or box.y < 32.0:
		return
	_wall(box)
	_window(box)
	_door(box)
	_shelf(box)
	_posters(box)
	_kitchen(box)
	_bed(box)
	_desk(box)
	_person(box)
	_clutter(box)
	_light(box)


func _wall(box: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, box), Color("F6D7B8"))
	draw_rect(Rect2(0, 0, box.x, 18), Color("E7B98A"))
	# Soft vertical wash so the wall is not a flat card.
	for i in 18:
		var shade := 0.04 if i % 2 == 0 else 0.0
		draw_rect(Rect2(i * box.x / 18.0, 18, box.x / 18.0 + 1.0, box.y * 0.62), Color(0.45, 0.28, 0.16, shade))
	draw_rect(Rect2(0, box.y * 0.62, box.x, 16), Color("C98455"))
	draw_rect(Rect2(0, box.y * 0.62 + 16, box.x, box.y), Color("C9864E"))
	var plank_y := box.y * 0.66
	var index := 0
	while plank_y < box.y:
		var tone := Color("B8743E") if index % 2 == 0 else Color("C9864E")
		draw_rect(Rect2(0, plank_y, box.x, 28), tone)
		draw_line(Vector2(0, plank_y), Vector2(box.x, plank_y), Color("8A542C"), 2.0)
		for nail in 6:
			draw_circle(Vector2(80.0 + nail * 200.0, plank_y + 8.0), 1.6, Color("6E4124"))
		plank_y += 28.0
		index += 1
	# Outlet and a hairline crack, the kind a rental never quite fixes.
	_box(Rect2(1180, 250, 22, 32), Color("F7F1E6"), INK)
	draw_circle(Vector2(1191, 262), 3, Color("C9B8A4"))
	draw_circle(Vector2(1191, 272), 3, Color("C9B8A4"))
	draw_line(Vector2(640, 30), Vector2(668, 92), Color("D7B292"), 2.0)


func _window(box: Vector2) -> void:
	var frame := Rect2(48, 78, 300, 230)
	var sky := Rect2(frame.position.x + 14, frame.position.y + 14, frame.size.x - 28, frame.size.y - 36)
	var top := Color("F6C99A")
	var bottom := Color("F8E2C4")
	match sky_phase:
		1:
			top = Color("7EBFDF")
			bottom = Color("D7F0FA")
		2:
			top = Color("F08A5A")
			bottom = Color("F6C98A")
		3:
			top = Color("1C2C4A")
			bottom = Color("3E5678")
	for band in 8:
		var t := float(band) / 8.0
		draw_rect(Rect2(sky.position.x, sky.position.y + sky.size.y * t, sky.size.x, sky.size.y / 8.0 + 1.0), top.lerp(bottom, t))
	if sky_phase < 3:
		var sun := sky.position + Vector2(sky.size.x * 0.78, 46 + sin(time_sec * 0.4) * 2.0)
		draw_circle(sun, 22, Color("FFE08A"))
		draw_circle(sun, 30, Color(1, 0.86, 0.45, 0.25))
	else:
		draw_circle(sky.position + Vector2(sky.size.x * 0.8, 40), 12, Color("F4F0D8"))
		draw_circle(sky.position + Vector2(46, 28), 1.4, Color("FFF8EE"))
		draw_circle(sky.position + Vector2(80, 18), 1.2, Color("FFF8EE"))
		draw_circle(sky.position + Vector2(120, 36), 1.5, Color("FFF8EE"))
	_city(sky)
	# Curtains and a slightly crooked frame.
	draw_rect(Rect2(frame.position.x + 8, frame.position.y + 10, 18, sky.size.y), Color("F2C9B0"))
	draw_rect(Rect2(frame.end.x - 26, frame.position.y + 10, 18, sky.size.y), Color("E7B39A"))
	_box(frame, Color("F7F1E6"), INK, false)
	draw_rect(frame, INK, false, 6.0)
	draw_line(Vector2(frame.position.x + frame.size.x * 0.5, frame.position.y + 8), Vector2(frame.position.x + frame.size.x * 0.5, frame.end.y - 8), INK, 4.0)
	draw_rect(Rect2(frame.position.x - 8, frame.end.y - 8, frame.size.x + 16, 16), Color("E6C39A"))
	draw_rect(Rect2(frame.position.x - 8, frame.end.y - 8, frame.size.x + 16, 16), INK, false, 3.0)
	# Sill plant.
	_plant(Vector2(frame.position.x + 36, frame.end.y + 8), 0.72)
	_plant(Vector2(frame.end.x - 20, frame.end.y + 4), 0.55)


func _city(sky: Rect2) -> void:
	var base := sky.end.y
	var specs := [
		[0.02, 0.16, 0.42, "6E624E"],
		[0.18, 0.14, 0.62, "5C5348"],
		[0.33, 0.18, 0.48, "7A6A58"],
		[0.52, 0.12, 0.7, "4E463F"],
		[0.66, 0.15, 0.38, "6A5E52"],
		[0.82, 0.16, 0.55, "3E4450"],
	]
	for spec in specs:
		var rect := Rect2(sky.position.x + sky.size.x * float(spec[0]), base - sky.size.y * float(spec[2]), sky.size.x * float(spec[1]), sky.size.y * float(spec[2]))
		draw_rect(rect, Color(str(spec[3])))
		var win_y := rect.position.y + 8.0
		while win_y < rect.end.y - 6.0:
			var win_x := rect.position.x + 6.0
			while win_x < rect.end.x - 6.0:
				var lit := sky_phase >= 2 and int(win_x + win_y) % 3 != 0
				draw_rect(Rect2(win_x, win_y, 5, 6), Color("F6D98A") if lit else Color("D7E7EF"))
				win_x += 10.0
			win_y += 12.0
	# Water tower, a rental-city silhouette, not a landmark logo.
	var tower := Vector2(sky.position.x + sky.size.x * 0.9, base - sky.size.y * 0.72)
	draw_line(tower, tower + Vector2(0, 36), Color("4E463F"), 3.0)
	draw_rect(Rect2(tower + Vector2(-10, -16), Vector2(20, 16)), Color("6A5E52"))


func _door(box: Vector2) -> void:
	var frame := Rect2(390, 96, 118, 390)
	draw_rect(frame.grow(8), Color("8C5A3C"))
	var open := pose == "outing" or pose == "freelance"
	var door_width := 58.0 if open else 92.0
	var door := Rect2(frame.position.x + 8, frame.position.y + 8, door_width, frame.size.y - 16)
	_box(door, Color("C4895A"), INK)
	draw_rect(Rect2(door.position.x + 8, door.position.y + 12, door.size.x - 16, 78), Color("A86B3C"), false, 3.0)
	draw_rect(Rect2(door.position.x + 8, door.position.y + 102, door.size.x - 16, 78), Color("A86B3C"), false, 3.0)
	draw_circle(door.end + Vector2(-14, -door.size.y * 0.42), 5, Color("E6C98A"))
	if open:
		draw_rect(Rect2(frame.end.x - 36, frame.position.y + 8, 28, frame.size.y - 16), Color("2A241C"))
	# Coat and a pair of lived-in shoes.
	var hook := Vector2(frame.end.x + 18, frame.position.y + 36)
	draw_line(hook, hook + Vector2(0, 10), INK, 3.0)
	_poly([hook + Vector2(-16, 12), hook + Vector2(18, 14), hook + Vector2(10, 70), hook + Vector2(-12, 64)], Color("3E8C86"), INK)
	_poly([Vector2(frame.position.x + 10, frame.end.y + 8), Vector2(frame.position.x + 36, frame.end.y + 6), Vector2(frame.position.x + 34, frame.end.y + 18), Vector2(frame.position.x + 8, frame.end.y + 16)], Color("E36B45"), INK)
	_poly([Vector2(frame.position.x + 40, frame.end.y + 10), Vector2(frame.position.x + 62, frame.end.y + 4), Vector2(frame.position.x + 66, frame.end.y + 16), Vector2(frame.position.x + 42, frame.end.y + 18)], Color("3D4E6B"), INK)

func _shelf(box: Vector2) -> void:
	var shelf := Rect2(1048, 78, 168, 300)
	_box(shelf, Color("A86B3C"), INK)
	var colors := [Color("E25B4A"), Color("F2C14E"), Color("3E8C86"), Color("3D4E6B"), Color("E36B45"), Color("F7F1E6"), Color("C4512F")]
	for row in 4:
		var y := shelf.position.y + 18 + row * 70
		draw_rect(Rect2(shelf.position.x + 6, y + 48, shelf.size.x - 12, 8), Color("C4925A"))
		var x := shelf.position.x + 12.0
		for book in 5:
			var h := 28.0 + float((book * 3 + row) % 4) * 6.0
			var lean := -4.0 if book == 3 and row == 1 else 0.0
			draw_set_transform(Vector2(x, y + 48 - h), deg_to_rad(lean), Vector2.ONE)
			draw_rect(Rect2(0, 0, 16, h), colors[(book + row) % colors.size()])
			draw_rect(Rect2(0, 0, 16, h), INK, false, 2.0)
			draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
			x += 22.0
	# Trailing plant and a tiny camera.
	draw_circle(Vector2(shelf.position.x + 28, shelf.position.y + 28), 10, Color("3F8F5A"))
	draw_line(Vector2(shelf.position.x + 28, shelf.position.y + 36), Vector2(shelf.position.x + 18, shelf.position.y + 70), Color("2C6B42"), 3.0)
	_box(Rect2(shelf.end.x - 46, shelf.position.y + 20, 28, 18), Color("2C241C"), INK)
	draw_circle(Vector2(shelf.end.x - 32, shelf.position.y + 29), 5, Color("8FB7C9"))

func _posters(box: Vector2) -> void:
	# Photo of the same original character, from the editable SVG sheet.
	_box(Rect2(760, 86, 150, 176), Color("F7F1E6"), INK)
	if portrait != null:
		draw_texture_rect(portrait, Rect2(770, 96, 130, 150), false)
	else:
		draw_circle(Vector2(835, 150), 28, SKIN)
	var font := ThemeBuilder.font()
	draw_string(font, Vector2(778, 252), "草稿", HORIZONTAL_ALIGNMENT_LEFT, 120, 14, INK)
	if poster != null:
		draw_set_transform(Vector2(560, 96), deg_to_rad(-6.0), Vector2.ONE)
		draw_texture_rect(poster, Rect2(0, 0, 150, 176), false)
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	else:
		_persimmon(Vector2(620, 160))
	# Today's trend, pinned like a real note rather than a dashboard cell.
	draw_set_transform(Vector2(900, 286), deg_to_rad(3.0), Vector2.ONE)
	_box(Rect2(0, 0, 150, 78), Color("FFF4C2"), INK)
	draw_circle(Vector2(74, 8), 5, Color("C9B8A4"))
	draw_string(font, Vector2(10, 28), "本周趋势", HORIZONTAL_ALIGNMENT_LEFT, 130, 14, Color("6E6258"))
	draw_string(font, Vector2(10, 52), "「%s」" % trend_text, HORIZONTAL_ALIGNMENT_LEFT, 130, 20, INK)
	draw_string(font, Vector2(10, 70), "下周 %s" % next_trend, HORIZONTAL_ALIGNMENT_LEFT, 130, 12, Color("6E6258"))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

func _kitchen(box: Vector2) -> void:
	var counter := Rect2(36, 430, 230, 92)
	_box(counter, Color("F7F1E6"), INK)
	draw_rect(Rect2(counter.position.x, counter.position.y, counter.size.x, 12), Color("E7C9A8"))
	# Kettle.
	_box(Rect2(58, 392, 46, 40), Color("D9E2E4"), INK)
	draw_arc(Vector2(104, 408), 14, PI, TAU * 0.75, 8, INK, 3.0)
	draw_rect(Rect2(70, 384, 22, 8), Color("8AA0A6"))
	# Noodle bowl, the meal corner.
	_ellipse(Vector2(150, 418), Vector2(28, 10), Color("F2C14E"))
	draw_circle(Vector2(150, 412), 22, Color("F7F1E6"))
	draw_circle(Vector2(150, 412), 22, INK, false, 3.0)
	draw_line(Vector2(138, 404), Vector2(146, 392), Color("E36B45"), 3.0)
	draw_line(Vector2(156, 400), Vector2(168, 388), Color("E36B45"), 3.0)
	# Towel.
	_poly([Vector2(214, 392), Vector2(246, 396), Vector2(240, 448), Vector2(208, 442)], Color("3E8C86"), INK)

func _bed(box: Vector2) -> void:
	var frame := Rect2(760, 390, 300, 150)
	_box(Rect2(frame.position.x, frame.position.y + 36, frame.size.x, 86), Color("A86B3C"), INK)
	_box(Rect2(frame.position.x + 8, frame.position.y + 8, 70, 46), Color("F7F1E6"), INK)
	_ellipse(Vector2(frame.position.x + 42, frame.position.y + 30), Vector2(24, 14), Color("E7D3C4"))
	# Rumpled blanket: a wavy polygon, not a flat slab.
	var blanket: PackedVector2Array = PackedVector2Array()
	blanket.append(Vector2(frame.position.x + 70, frame.position.y + 78))
	var wave := frame.position.x + 78.0
	while wave < frame.end.x - 16.0:
		var lift := sin(wave * 0.05 + time_sec) * 4.0
		blanket.append(Vector2(wave, frame.position.y + 46 + lift))
		wave += 28.0
	blanket.append(Vector2(frame.end.x - 12, frame.position.y + 96))
	blanket.append(Vector2(frame.position.x + 86, frame.position.y + 108))
	var cols := PackedColorArray()
	cols.resize(blanket.size())
	cols.fill(Color("E25B4A"))
	draw_polygon(blanket, cols)
	draw_polyline(blanket, INK, 3.0, true)
	# Fold shadow.
	draw_line(Vector2(frame.position.x + 140, frame.position.y + 58), Vector2(frame.position.x + 210, frame.position.y + 96), Color("C44738"), 6.0)
	# Paperback left open.
	_box(Rect2(frame.position.x + 150, frame.position.y + 18, 46, 28), Color("F2C14E"), INK)
	draw_line(Vector2(frame.position.x + 173, frame.position.y + 22), Vector2(frame.position.x + 173, frame.position.y + 42), INK, 2.0)
	if pose == "rest":
		_person_lying(Vector2(frame.position.x + 78, frame.position.y + 58))
		var zed := 18.0 + fmod(time_sec * 18.0, 26.0)
		draw_string(ThemeBuilder.font(), Vector2(frame.position.x + 120, frame.position.y - zed), "z z", HORIZONTAL_ALIGNMENT_LEFT, 80, 18, Color("3E8C86"))

func _desk(box: Vector2) -> void:
	# Rug first, then legs, then top.
	draw_set_transform(Vector2(470, 610), 0, Vector2(1.5, 0.45))
	draw_circle(Vector2.ZERO, 120, Color("C44738"))
	draw_circle(Vector2.ZERO, 120, INK, false, 3.0)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	for leg in [Vector2(250, 560), Vector2(250, 640), Vector2(620, 560), Vector2(620, 640)]:
		draw_rect(Rect2(leg, Vector2(14, 70)), Color("8C5A3C"))
	var top := Rect2(230, 500, 430, 28)
	_box(Rect2(230, 430, 430, 78), Color("E6C08A"), INK)
	draw_rect(top, Color("F0D2A4"))
	draw_rect(top, INK, false, 3.0)
	# Monitor.
	var bezel := Rect2(300, 300, 190, 130)
	_box(bezel, Color("2C241C"), INK)
	var screen := bezel.grow(-10)
	screen.size.y -= 8
	draw_rect(screen, Color("1E2A32"))
	var glow := 0.35 + 0.15 * sin(time_sec * 3.0)
	draw_rect(screen, Color(0.55, 0.85, 0.75, glow * 0.35))
	for i in 3:
		var ratio: float = float(fan_ratios[i]) if i < fan_ratios.size() else 0.2
		var h := screen.size.y * clampf(ratio, 0.12, 0.82)
		var bar := Rect2(screen.position.x + 16 + i * 48, screen.end.y - h - 12, 28, h)
		var colors := [Color("E36B45"), Color("3E8C86"), Color("7EA0C4")]
		draw_rect(bar, colors[i])
	if pose == "type":
		var slide := fmod(time_sec * 40.0, 30.0)
		draw_rect(Rect2(screen.position.x + 12, screen.position.y + 16 + slide * 0.2, 70, 4), Color("D7F0E8"))
		draw_rect(Rect2(screen.position.x + 12, screen.position.y + 28, 48, 4), Color("D7F0E8"))
	if fmod(time_sec, 1.1) < 0.55:
		draw_rect(Rect2(screen.position.x + 16, screen.position.y + 18, 8, 14), Color("F7F1E6"))
	draw_rect(Rect2(bezel.position.x + 78, bezel.end.y - 6, 34, 18), Color("3A322C"))
	# Keyboard, mug, headphones, cable.
	_box(Rect2(520, 470, 110, 28), Color("F7F1E6"), INK)
	for key_x in 8:
		draw_rect(Rect2(528 + key_x * 12, 478, 8, 6), Color("E7D3C4"))
	_mug(Vector2(250, 468))
	_headphones(Vector2(640, 455))
	var cable := PackedVector2Array([
		Vector2(390, 430), Vector2(370, 470), Vector2(340, 500), Vector2(300, 560), Vector2(260, 600),
	])
	draw_polyline(cable, Color("2C241C"), 3.0, true)
	_box(Rect2(230, 598, 54, 16), Color("F7F1E6"), INK)
	if sponsor:
		_box(Rect2(560, 430, 54, 36), Color("FFF4C2"), INK)
		draw_line(Vector2(560, 448), Vector2(614, 448), Color("E36B45"), 2.0)
	# Window light on the desktop.
	draw_rect(Rect2(250, 444, 120, 40), Color(1, 0.9, 0.6, 0.18 if sky_phase < 3 else 0.05))
	# Lamp.
	var lamp := Vector2(690, 250)
	draw_line(lamp + Vector2(0, 180), lamp, Color("E6C98A"), 4.0)
	draw_circle(lamp, 16, Color("F6D98A"))
	draw_circle(lamp, 34 + sin(time_sec * 2.0) * 2.0, Color(1, 0.82, 0.4, 0.18))

func _person(box: Vector2) -> void:
	match pose:
		"rest":
			pass
		"study":
			_person_stand(Vector2(1008, 470), true)
		"outing", "freelance":
			_person_stand(Vector2(448, 545), false)
		_:
			_person_sit(Vector2(470, 520), pose == "type")

func _person_sit(hip: Vector2, typing: bool) -> void:
	var bob := sin(time_sec * 2.1) * 2.2
	var seat := hip + Vector2(0, bob)
	# Chair.
	_box(Rect2(seat.x - 46, seat.y - 10, 92, 18), Color("8C5A3C"), INK)
	draw_rect(Rect2(seat.x - 8, seat.y + 8, 12, 78), Color("6E452C"))
	draw_rect(Rect2(seat.x + 28, seat.y + 8, 12, 78), Color("6E452C"))
	_box(Rect2(seat.x - 18, seat.y - 78, 16, 74), Color("A86B3C"), INK)
	# Legs.
	_poly([seat + Vector2(-30, 8), seat + Vector2(-6, 8), seat + Vector2(-2, 78), seat + Vector2(-34, 74)], PANTS, INK)
	_poly([seat + Vector2(8, 8), seat + Vector2(34, 10), seat + Vector2(40, 80), seat + Vector2(8, 76)], PANTS, INK)
	_box(Rect2(seat.x - 40, seat.y + 70, 28, 12), Color("2C241C"), INK)
	_box(Rect2(seat.x + 8, seat.y + 74, 30, 12), Color("E36B45"), INK)
	# Torso.
	_poly([
		seat + Vector2(-40, -6), seat + Vector2(42, -2), seat + Vector2(36, -70), seat + Vector2(-34, -74),
	], HOODIE, INK)
	draw_line(seat + Vector2(-20, -40), seat + Vector2(18, -36), HOODIE_DARK, 8.0)
	# Arms toward the keyboard. They swap height while typing.
	var flap := sin(time_sec * (9.0 if typing else 1.6)) * (8.0 if typing else 2.0)
	_limb(seat + Vector2(-28, -48), seat + Vector2(-70, -6 + flap), 12, HOODIE)
	_limb(seat + Vector2(24, -46), seat + Vector2(78, -10 - flap), 12, HOODIE)
	draw_circle(seat + Vector2(-70, -6 + flap), 8, SKIN)
	draw_circle(seat + Vector2(78, -10 - flap), 8, SKIN)
	draw_rect(Rect2(seat.x - 8, seat.y - 86, 18, 20), SKIN)
	_head(seat + Vector2(2, -96), false)


func _person_stand(feet: Vector2, book: bool) -> void:
	var bob := sin(time_sec * 2.4) * 1.6
	var hip := feet + Vector2(0, -78 + bob)
	_poly([hip + Vector2(-22, 0), hip + Vector2(-6, 0), hip + Vector2(-10, 78), hip + Vector2(-28, 76)], PANTS, INK)
	_poly([hip + Vector2(6, 0), hip + Vector2(22, 2), hip + Vector2(18, 80), hip + Vector2(2, 76)], PANTS, INK)
	_box(Rect2(hip.x - 30, feet.y - 8, 22, 10), Color("2C241C"), INK)
	_box(Rect2(hip.x + 6, feet.y - 6, 22, 10), Color("E36B45"), INK)
	_poly([hip + Vector2(-32, -4), hip + Vector2(32, -2), hip + Vector2(28, -62), hip + Vector2(-28, -64)], HOODIE, INK)
	if book:
		_limb(hip + Vector2(-10, -40), hip + Vector2(20, -18), 11, HOODIE)
		_box(Rect2(hip.x + 8, hip.y - 36, 28, 36), Color("F2C14E"), INK)
	else:
		var step := sin(time_sec * 6.0) * 6.0
		_limb(hip + Vector2(-18, -36), hip + Vector2(-36, 8 + step), 10, HOODIE)
		_limb(hip + Vector2(16, -36), hip + Vector2(34, 6 - step), 10, HOODIE)
		if pose == "freelance":
			_box(Rect2(hip.x + 18, hip.y - 10, 26, 18), Color("FFF4C2"), INK)
	draw_rect(Rect2(hip.x - 7, hip.y - 78, 16, 18), SKIN)
	_head(hip + Vector2(0, -88), false)


func _person_lying(pillow: Vector2) -> void:
	_poly([pillow + Vector2(-10, 20), pillow + Vector2(120, 28), pillow + Vector2(110, 58), pillow + Vector2(-16, 50)], HOODIE, INK)
	_head(pillow + Vector2(8, -6), true)


func _head(center: Vector2, asleep: bool) -> void:
	var bob := sin(time_sec * 2.1) * 1.2
	var c := center + Vector2(0, bob)
	# Hair mass behind the face.
	draw_circle(c + Vector2(0, -6), 34, HAIR)
	draw_circle(c + Vector2(2, 4), 30, SKIN)
	draw_circle(c + Vector2(2, 4), 30, INK, false, 3.0)
	# Bangs.
	_poly([c + Vector2(-28, -8), c + Vector2(-6, -34), c + Vector2(10, -8), c + Vector2(-8, 0)], HAIR, INK)
	_poly([c + Vector2(-4, -32), c + Vector2(22, -36), c + Vector2(18, -6)], HAIR, INK)
	# Cowlick.
	draw_arc(c + Vector2(-2, -34), 10, PI * 1.15, PI * 1.85, 8, HAIR, 4.0)
	var blink := asleep or fmod(time_sec, 3.6) > 3.42 or stamina < 18.0
	var heavy := stamina < 36.0 and not asleep
	if blink:
		draw_line(c + Vector2(-12, 2), c + Vector2(-2, 4), INK, 3.0)
		draw_line(c + Vector2(8, 2), c + Vector2(18, 4), INK, 3.0)
	else:
		draw_circle(c + Vector2(-8, 2), 4.5, Color("FFF8EE"))
		draw_circle(c + Vector2(12, 2), 4.5, Color("FFF8EE"))
		var look := 1.0 if pose == "type" else 0.0
		draw_circle(c + Vector2(-7 + look, 3), 2.4, INK)
		draw_circle(c + Vector2(13 + look, 3), 2.4, INK)
		if heavy:
			draw_line(c + Vector2(-13, -2), c + Vector2(-2, 0), INK, 2.0)
			draw_line(c + Vector2(7, -2), c + Vector2(18, 0), INK, 2.0)
	# Mouth follows mood and stress without becoming a chart.
	if asleep or mood > 60.0:
		draw_arc(c + Vector2(2, 14), 7, 0.15, PI - 0.15, 8, Color("A85A48"), 2.5)
	elif stress > 60.0:
		draw_line(c + Vector2(-6, 16), c + Vector2(10, 14), Color("A85A48"), 2.5)
	else:
		draw_line(c + Vector2(-4, 16), c + Vector2(8, 16), Color("A85A48"), 2.5)
	draw_circle(c + Vector2(-16, 10), 4, Color(0.9, 0.55, 0.48, 0.45))
	draw_circle(c + Vector2(18, 10), 4, Color(0.9, 0.55, 0.48, 0.45))
	# One earphone, the other lives on the desk.
	if pose == "type" or pose == "idle":
		draw_circle(c + Vector2(28, 8), 6, Color("2C241C"))
		draw_circle(c + Vector2(28, 8), 2, Color("E6C98A"))


func _clutter(box: Vector2) -> void:
	# Wastebasket and a crumpled draft.
	_poly([Vector2(700, 600), Vector2(748, 604), Vector2(740, 660), Vector2(708, 656)], Color("E7E1D6"), INK)
	draw_circle(Vector2(724, 590), 8, Color("FFF4C2"))
	# Power brick and a sock.
	_box(Rect2(180, 640, 36, 16), Color("2C241C"), INK)
	_poly([Vector2(820, 640), Vector2(846, 636), Vector2(850, 654), Vector2(822, 656)], Color("F2C14E"), INK)
	# Foreground cable loop.
	draw_arc(Vector2(210, 670), 18, 0.2, PI, 10, INK, 3.0)

func _light(box: Vector2) -> void:
	if sky_phase == 2:
		draw_rect(Rect2(Vector2.ZERO, box), Color(0.55, 0.28, 0.08, 0.12))
	elif sky_phase == 3:
		draw_rect(Rect2(Vector2.ZERO, box), Color(0.05, 0.08, 0.18, 0.34))
		draw_circle(Vector2(690, 250), 150, Color(1, 0.78, 0.4, 0.16))
		draw_circle(Vector2(390, 360), 70, Color(0.6, 0.9, 0.8, 0.12))
	elif sky_phase == 0:
		draw_rect(Rect2(Vector2.ZERO, box), Color(1, 0.72, 0.45, 0.08))
	# Monitor spill on the hoodie when writing at night is already in the glow.


func _mug(at: Vector2) -> void:
	_box(Rect2(at.x, at.y, 36, 32), Color("F7F1E6"), INK)
	draw_rect(Rect2(at.x + 4, at.y + 6, 28, 8), Color("6F4E37"))
	draw_arc(at + Vector2(40, 16), 10, -PI * 0.4, PI * 0.4, 8, INK, 3.0)
	var steam := fmod(time_sec * 20.0, 18.0)
	draw_arc(at + Vector2(12, -steam), 6, PI, TAU, 6, Color(1, 1, 1, 0.45), 2.0)


func _headphones(at: Vector2) -> void:
	draw_arc(at, 16, PI, TAU, 10, INK, 4.0)
	draw_circle(at + Vector2(-16, 4), 8, Color("E36B45"))
	draw_circle(at + Vector2(16, 4), 8, Color("E36B45"))
	draw_circle(at + Vector2(-16, 4), 8, INK, false, 2.0)
	draw_circle(at + Vector2(16, 4), 8, INK, false, 2.0)


func _plant(at: Vector2, scale: float) -> void:
	draw_set_transform(at, 0, Vector2(scale, scale))
	_box(Rect2(-14, 0, 28, 22), Color("E36B45"), INK)
	draw_circle(Vector2(-8, -10), 12, Color("3F8F5A"))
	draw_circle(Vector2(10, -16), 14, Color("2C6B42"))
	draw_circle(Vector2(0, -24), 10, Color("67A86A"))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)


func _persimmon(at: Vector2) -> void:
	draw_circle(at, 28, Color("E25B2A"))
	draw_circle(at, 28, INK, false, 3.0)
	draw_circle(at + Vector2(-8, -6), 8, Color("F4A06A"))
	_poly([at + Vector2(-6, -24), at + Vector2(4, -40), at + Vector2(16, -22)], Color("3F8F5A"), INK)


func _limb(a: Vector2, b: Vector2, radius: float, color: Color) -> void:
	draw_line(a, b, color, radius * 2.0)
	draw_line(a, b, INK, 2.0)
	draw_circle(a, radius * 0.7, color)
	draw_circle(b, radius * 0.85, color)


func _ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	draw_set_transform(center, 0, radii / 20.0)
	draw_circle(Vector2.ZERO, 20, color)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)


func _box(rect: Rect2, fill: Color, ink: Color, filled: bool = true) -> void:
	if filled:
		draw_rect(rect, fill)
	draw_rect(rect, ink, false, 3.0)


func _poly(pts: Array, fill: Color, ink: Color) -> void:
	var poly := PackedVector2Array()
	var cols := PackedColorArray()
	for point in pts:
		poly.append(point)
		cols.append(fill)
	draw_polygon(poly, cols)
	var line := poly.duplicate()
	line.append(poly[0])
	draw_polyline(line, ink, 3.0, true)
