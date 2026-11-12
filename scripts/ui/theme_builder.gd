extends RefCounted
class_name ThemeBuilder

const INK := Color("2C241C")
const INK_SOFT := Color("6E6258")
const PAPER := Color("FFF8EE")
const PAPER_DEEP := Color("F3E4D0")
const LINE := Color("E4D3BC")
const CLAY := Color("C65B38")
const CLAY_DARK := Color("A4482C")
const CREAM := Color("FFF8EF")
const TEAL := Color("1F6F68")
const GOLD := Color("D0892E")
const SAGE := Color("5E8F62")
const DANGER := Color("A33B32")
const MUTED_FILL := Color("E7D9C6")


static var _font: Font


static func font() -> Font:
	if _font == null:
		var loaded: Resource = load("res://assets/fonts/SourceHanSansCN-Regular.otf")
		if loaded is Font:
			_font = loaded
		else:
			var file := FontFile.new()
			var bytes := FileAccess.get_file_as_bytes("res://assets/fonts/SourceHanSansCN-Regular.otf")
			file.data = bytes
			file.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
			file.hinting = TextServer.HINTING_LIGHT
			_font = file
	return _font


static func make() -> Theme:
	var theme := Theme.new()
	var face := font()
	theme.default_font = face
	theme.default_font_size = 16
	for kind in ["Label", "Button", "CheckButton", "LineEdit", "RichTextLabel", "ProgressBar"]:
		theme.set_font("font", kind, face)
		theme.set_color("font_color", kind, INK)
	theme.set_font_size("font_size", "Button", 18)
	theme.set_font_size("font_size", "Label", 16)
	theme.set_font_size("font_size", "CheckButton", 16)
	theme.set_font_size("font_size", "LineEdit", 18)
	theme.set_color("font_color", "Button", INK)
	theme.set_color("font_hover_color", "Button", INK)
	theme.set_color("font_pressed_color", "Button", INK)
	theme.set_color("font_disabled_color", "Button", INK_SOFT)
	theme.set_color("font_focus_color", "Button", INK)
	theme.set_stylebox("normal", "Button", button_style(PAPER, LINE))
	theme.set_stylebox("hover", "Button", button_style(Color("F7E7D4"), TEAL))
	theme.set_stylebox("pressed", "Button", button_style(Color("EAD3BA"), TEAL))
	theme.set_stylebox("disabled", "Button", button_style(MUTED_FILL, LINE))
	theme.set_stylebox("focus", "Button", button_style(PAPER, TEAL, 2))
	theme.set_stylebox("normal", "LineEdit", button_style(PAPER, LINE))
	theme.set_stylebox("focus", "LineEdit", button_style(PAPER, TEAL, 2))
	theme.set_stylebox("read_only", "LineEdit", button_style(PAPER_DEEP, LINE))
	theme.set_color("font_placeholder_color", "LineEdit", INK_SOFT)
	theme.set_stylebox("panel", "PanelContainer", panel_style())
	var bg := StyleBoxFlat.new()
	bg.bg_color = MUTED_FILL
	bg.corner_radius_top_left = 6
	bg.corner_radius_top_right = 6
	bg.corner_radius_bottom_left = 6
	bg.corner_radius_bottom_right = 6
	var fill := StyleBoxFlat.new()
	fill.bg_color = TEAL
	fill.corner_radius_top_left = 6
	fill.corner_radius_top_right = 6
	fill.corner_radius_bottom_left = 6
	fill.corner_radius_bottom_right = 6
	theme.set_stylebox("background", "ProgressBar", bg)
	theme.set_stylebox("fill", "ProgressBar", fill)
	theme.set_constant("outline_size", "Button", 0)
	return theme


static func panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 0.973, 0.933, 0.94)
	style.border_color = LINE
	style.set_border_width_all(1)
	style.set_corner_radius_all(16)
	style.shadow_color = Color(0.25, 0.14, 0.08, 0.16)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 3)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


static func button_style(fill: Color, border: Color, border_width: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(12)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


static func paint_primary(button: Button) -> void:
	button.add_theme_stylebox_override("normal", button_style(CLAY, CLAY_DARK))
	button.add_theme_stylebox_override("hover", button_style(Color("D4704A"), CLAY_DARK))
	button.add_theme_stylebox_override("pressed", button_style(CLAY_DARK, CLAY_DARK))
	button.add_theme_stylebox_override("focus", button_style(CLAY, CREAM, 2))
	button.add_theme_color_override("font_color", CREAM)
	button.add_theme_color_override("font_hover_color", CREAM)
	button.add_theme_color_override("font_pressed_color", CREAM)
	button.add_theme_color_override("font_focus_color", CREAM)


static func paint_bar(bar: ProgressBar, color: Color) -> void:
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(6)
	bar.add_theme_stylebox_override("fill", fill)
