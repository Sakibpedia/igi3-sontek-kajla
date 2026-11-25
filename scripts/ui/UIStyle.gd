extends RefCounted
## Silent Rescue: Cox's Bazar - the look of every menu and HUD element.
## A coastal palette (deep sea navy, lagoon teal, sunset coral, sand-coloured text) and one Theme for the
## whole game (Game._setup_font puts it on the root window), so every Button, slider, tab, check box,
## drop-down, scroll bar, progress bar and Window looks the same without per-node overrides. Helpers
## build the recurring pieces: cards (panels with an accent strip), chips (small rounded tags), key caps
## ("[E]" style key hints), styled progress bars and buttons. Icons (check boxes, slider grabber) are
## drawn here into small textures, so nothing depends on symbol glyphs the fonts may not have.

const BG_DEEP := Color(0.035, 0.07, 0.10)
const BG := Color(0.06, 0.11, 0.16)
const BG_RAISED := Color(0.10, 0.17, 0.23)
const LINE := Color(0.22, 0.33, 0.40)
const TEAL := Color(0.13, 0.75, 0.68)
const TEAL_DARK := Color(0.05, 0.40, 0.38)
const CORAL := Color(1.0, 0.49, 0.36)
const SUN := Color(1.0, 0.78, 0.36)
const SAND := Color(0.96, 0.92, 0.84)
const MUTED := Color(0.62, 0.71, 0.77)
const DANGER := Color(0.95, 0.27, 0.30)
const OK := Color(0.35, 0.88, 0.55)
const SKY := Color(0.45, 0.78, 1.0)


static func sb(bg: Color, radius: int = 10, border: Color = Color(0, 0, 0, 0), bw: int = 0, mx: float = 14.0, my: float = 10.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(bw)
	s.content_margin_left = mx
	s.content_margin_right = mx
	s.content_margin_top = my
	s.content_margin_bottom = my
	s.anti_aliasing = true
	return s


## A HUD / menu card: translucent sea-navy, a thin accent outline and a 4 px accent strip on the left.
static func card(accent: Color = TEAL, alpha: float = 0.84) -> StyleBoxFlat:
	var s := sb(Color(BG.r, BG.g, BG.b, alpha), 12, Color(accent.r, accent.g, accent.b, 0.42), 1, 16.0, 11.0)
	s.border_width_left = 4
	s.border_color = Color(accent.r, accent.g, accent.b, 0.55)
	s.shadow_color = Color(0, 0, 0, 0.32)
	s.shadow_size = 8
	s.shadow_offset = Vector2(0, 3)
	return s


## A plain raised panel (menus, windows).
static func panel(alpha: float = 0.94) -> StyleBoxFlat:
	var s := sb(Color(BG.r, BG.g, BG.b, alpha), 14, Color(LINE.r, LINE.g, LINE.b, 0.9), 1, 20.0, 16.0)
	s.shadow_color = Color(0, 0, 0, 0.4)
	s.shadow_size = 14
	s.shadow_offset = Vector2(0, 5)
	return s


## A small rounded tag in a colour (status, counts).
static func chip(c: Color, filled: bool = false) -> StyleBoxFlat:
	var s := sb(Color(c.r, c.g, c.b, 0.9 if filled else 0.16), 999, Color(c.r, c.g, c.b, 0.7), 1, 11.0, 3.0)
	return s


static func chip_label(text: String, c: Color, size: int = 15, filled: bool = false) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", chip(c, filled))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", BG_DEEP if filled else c.lightened(0.25))
	p.add_child(l)
	return p


## "[E]"-style key hint: the key on a little raised cap.
static func keycap(text: String, size: int = 15, c: Color = SAND) -> PanelContainer:
	var p := PanelContainer.new()
	var s := sb(Color(0.9, 0.93, 0.95, 0.12), 6, Color(c.r, c.g, c.b, 0.65), 1, 7.0, 1.0)
	s.border_width_bottom = 3
	p.add_theme_stylebox_override("panel", s)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	p.add_child(l)
	return p


static func style_bar(pb: ProgressBar, fill: Color, h: float = 10.0) -> void:
	pb.show_percentage = false
	pb.custom_minimum_size.y = h
	var bg := sb(Color(0, 0, 0, 0.45), 999, Color(1, 1, 1, 0.08), 1, 0.0, 0.0)
	var fg := sb(fill, 999, Color(fill.r, fill.g, fill.b, 0.0), 0, 0.0, 0.0)
	pb.add_theme_stylebox_override("background", bg)
	pb.add_theme_stylebox_override("fill", fg)


## Re-tints a styled bar's fill (health colour by amount).
static func tint_bar(pb: ProgressBar, fill: Color) -> void:
	var fg = pb.get_theme_stylebox("fill")
	if fg is StyleBoxFlat:
		(fg as StyleBoxFlat).bg_color = fill


## green -> amber -> red as a fraction drops
static func health_color(frac: float) -> Color:
	if frac > 0.5:
		return OK.lerp(SUN, clampf((1.0 - frac) * 2.0, 0.0, 1.0))
	return SUN.lerp(DANGER, clampf((0.5 - frac) * 2.0, 0.0, 1.0))


## Buttons: raised navy with an accent outline; hover / press fill with the accent and dark text.
static func style_button(b: Button, accent: Color = TEAL, font_size: int = 22) -> void:
	b.add_theme_font_size_override("font_size", font_size)
	for k in _button_boxes(accent):
		b.add_theme_stylebox_override(str(k[0]), k[1])
	b.add_theme_color_override("font_color", SAND)
	b.add_theme_color_override("font_hover_color", BG_DEEP)
	b.add_theme_color_override("font_pressed_color", BG_DEEP)
	b.add_theme_color_override("font_focus_color", SAND)
	b.add_theme_color_override("font_disabled_color", Color(MUTED.r, MUTED.g, MUTED.b, 0.5))


static func _button_boxes(accent: Color) -> Array:
	var n := sb(BG_RAISED, 10, Color(accent.r, accent.g, accent.b, 0.55), 1, 18.0, 9.0)
	n.border_width_bottom = 3
	var h := sb(accent, 10, accent.lightened(0.25), 1, 18.0, 9.0)
	h.border_width_bottom = 3
	h.shadow_color = Color(accent.r, accent.g, accent.b, 0.35)
	h.shadow_size = 10
	var p := sb(accent.darkened(0.2), 10, accent.darkened(0.35), 1, 18.0, 10.0)
	p.border_width_top = 2
	var f := sb(Color(0, 0, 0, 0), 10, SAND, 2, 18.0, 9.0)
	var d := sb(Color(BG_RAISED.r, BG_RAISED.g, BG_RAISED.b, 0.5), 10, Color(LINE.r, LINE.g, LINE.b, 0.5), 1, 18.0, 9.0)
	return [["normal", n], ["hover", h], ["pressed", p], ["focus", f], ["disabled", d], ["hover_pressed", p]]


static func _circle(r: int, fill: Color, ring: Color = Color(0, 0, 0, 0), ring_w: float = 0.0) -> ImageTexture:
	var sz := r * 2 + 2
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var c := Vector2(sz, sz) * 0.5
	for y in sz:
		for x in sz:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			var a := clampf(float(r) - d + 0.5, 0.0, 1.0)
			var col := fill
			if ring_w > 0.0 and d > float(r) - ring_w:
				col = ring
			img.set_pixel(x, y, Color(col.r, col.g, col.b, col.a * a))
	return ImageTexture.create_from_image(img)


## Check box / toggle icons: a rounded square, with a drawn tick when on.
static func _check_icon(on: bool, disabled: bool = false) -> ImageTexture:
	var sz := 24
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var fill := TEAL if on else Color(0, 0, 0, 0.35)
	var edge := TEAL.lightened(0.2) if on else MUTED
	if disabled:
		fill = Color(fill.r, fill.g, fill.b, fill.a * 0.4)
		edge = Color(edge.r, edge.g, edge.b, 0.4)
	for y in sz:
		for x in sz:
			# rounded square 2..21, radius 5
			var q := Vector2(clampf(x + 0.5, 7.0, 17.0), clampf(y + 0.5, 7.0, 17.0))
			var d := Vector2(x + 0.5, y + 0.5).distance_to(q)
			if d > 5.5:
				continue
			var a := clampf(5.5 - d, 0.0, 1.0)
			var col := edge if d > 4.0 else fill
			img.set_pixel(x, y, Color(col.r, col.g, col.b, col.a * a))
	if on:
		# the tick: two strokes
		var pts := [Vector2(6.5, 12.5), Vector2(10.5, 16.5), Vector2(17.5, 7.5)]
		for s in 2:
			var a0: Vector2 = pts[s]
			var a1: Vector2 = pts[s + 1]
			for i in 40:
				var p := a0.lerp(a1, float(i) / 39.0)
				for oy in range(-1, 2):
					for ox in range(-1, 2):
						var px := int(p.x) + ox
						var py := int(p.y) + oy
						if px >= 0 and py >= 0 and px < sz and py < sz:
							img.set_pixel(px, py, BG_DEEP)
	return ImageTexture.create_from_image(img)


static var _theme: Theme = null


## The game-wide theme (built once).
static func make_theme(font: Font) -> Theme:
	if _theme != null:
		return _theme
	var th := Theme.new()
	th.default_font = font
	th.default_font_size = 20
	# ---- text
	for t in ["Label", "RichTextLabel"]:
		th.set_color("font_color" if t == "Label" else "default_color", t, SAND)
	th.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.55))
	th.set_constant("shadow_offset_x", "Label", 1)
	th.set_constant("shadow_offset_y", "Label", 2)
	# ---- buttons (Button, OptionButton, MenuButton share the boxes)
	for t in ["Button", "OptionButton", "MenuButton"]:
		for k in _button_boxes(TEAL):
			th.set_stylebox(str(k[0]), t, k[1])
		th.set_color("font_color", t, SAND)
		th.set_color("font_hover_color", t, BG_DEEP)
		th.set_color("font_pressed_color", t, BG_DEEP)
		th.set_color("font_hover_pressed_color", t, BG_DEEP)
		th.set_color("font_focus_color", t, SAND)
		th.set_color("font_disabled_color", t, Color(MUTED.r, MUTED.g, MUTED.b, 0.5))
		th.set_constant("h_separation", t, 8)
	# ---- check boxes / toggles: no box, the drawn icon carries the state
	for t in ["CheckBox", "CheckButton"]:
		var clear := sb(Color(0, 0, 0, 0), 8, Color(0, 0, 0, 0), 0, 6.0, 4.0)
		var hov := sb(Color(1, 1, 1, 0.06), 8, Color(0, 0, 0, 0), 0, 6.0, 4.0)
		for st in ["normal", "pressed", "focus", "disabled", "hover_pressed"]:
			th.set_stylebox(st, t, clear)
		th.set_stylebox("hover", t, hov)
		th.set_color("font_color", t, SAND)
		th.set_color("font_hover_color", t, Color.WHITE)
		th.set_color("font_pressed_color", t, SAND)
		th.set_color("font_hover_pressed_color", t, Color.WHITE)
		th.set_constant("h_separation", t, 10)
	th.set_icon("checked", "CheckBox", _check_icon(true))
	th.set_icon("unchecked", "CheckBox", _check_icon(false))
	th.set_icon("checked_disabled", "CheckBox", _check_icon(true, true))
	th.set_icon("unchecked_disabled", "CheckBox", _check_icon(false, true))
	th.set_icon("radio_checked", "CheckBox", _circle(10, TEAL, TEAL.lightened(0.3), 2.0))
	th.set_icon("radio_unchecked", "CheckBox", _circle(10, Color(0, 0, 0, 0.35), MUTED, 2.0))
	th.set_icon("checked", "CheckButton", _check_icon(true))
	th.set_icon("unchecked", "CheckButton", _check_icon(false))
	# ---- sliders
	var track := sb(Color(0, 0, 0, 0.45), 999, Color(1, 1, 1, 0.1), 1, 0.0, 3.0)
	var area := sb(TEAL_DARK, 999, Color(0, 0, 0, 0), 0, 0.0, 3.0)
	var area_h := sb(TEAL, 999, Color(0, 0, 0, 0), 0, 0.0, 3.0)
	th.set_stylebox("slider", "HSlider", track)
	th.set_stylebox("grabber_area", "HSlider", area)
	th.set_stylebox("grabber_area_highlight", "HSlider", area_h)
	th.set_icon("grabber", "HSlider", _circle(9, SAND, TEAL, 3.0))
	th.set_icon("grabber_highlight", "HSlider", _circle(10, Color.WHITE, TEAL.lightened(0.2), 3.0))
	th.set_icon("grabber_disabled", "HSlider", _circle(9, MUTED, LINE, 3.0))
	th.set_constant("center_grabber", "HSlider", 0)
	# ---- text fields / spin boxes
	th.set_stylebox("normal", "LineEdit", sb(Color(0, 0, 0, 0.35), 8, LINE, 1, 10.0, 6.0))
	th.set_stylebox("focus", "LineEdit", sb(Color(0, 0, 0, 0), 8, TEAL, 2, 10.0, 6.0))
	th.set_stylebox("read_only", "LineEdit", sb(Color(0, 0, 0, 0.2), 8, Color(LINE.r, LINE.g, LINE.b, 0.5), 1, 10.0, 6.0))
	th.set_color("font_color", "LineEdit", SAND)
	th.set_color("caret_color", "LineEdit", TEAL)
	th.set_color("selection_color", "LineEdit", Color(TEAL.r, TEAL.g, TEAL.b, 0.35))
	# ---- panels and windows
	th.set_stylebox("panel", "PanelContainer", panel(0.9))
	th.set_stylebox("panel", "Panel", panel(0.9))
	th.set_stylebox("panel", "PopupPanel", panel(0.97))
	th.set_stylebox("panel", "TooltipPanel", sb(Color(BG_DEEP.r, BG_DEEP.g, BG_DEEP.b, 0.96), 8, TEAL, 1, 10.0, 6.0))
	th.set_color("font_color", "TooltipLabel", SAND)
	var win := panel(0.98)
	win.expand_margin_top = 34
	win.expand_margin_left = 6
	win.expand_margin_right = 6
	win.expand_margin_bottom = 6
	win.border_color = TEAL_DARK
	th.set_stylebox("embedded_border", "Window", win)
	th.set_stylebox("embedded_unfocused_border", "Window", win)
	th.set_color("title_color", "Window", SAND)
	th.set_constant("title_height", "Window", 34)
	th.set_font_size("title_font_size", "Window", 20)
	# ---- drop-down lists / popups
	th.set_stylebox("panel", "PopupMenu", panel(0.98))
	th.set_stylebox("hover", "PopupMenu", sb(Color(TEAL.r, TEAL.g, TEAL.b, 0.85), 6, Color(0, 0, 0, 0), 0, 8.0, 4.0))
	th.set_color("font_color", "PopupMenu", SAND)
	th.set_color("font_hover_color", "PopupMenu", BG_DEEP)
	th.set_constant("v_separation", "PopupMenu", 8)
	th.set_icon("radio_checked", "PopupMenu", _circle(7, TEAL))
	th.set_icon("radio_unchecked", "PopupMenu", _circle(7, Color(0, 0, 0, 0.3), MUTED, 1.5))
	th.set_icon("checked", "PopupMenu", _check_icon(true))
	th.set_icon("unchecked", "PopupMenu", _check_icon(false))
	# ---- tabs
	var tab_sel := sb(BG_RAISED, 10, TEAL, 0, 18.0, 8.0)
	tab_sel.border_width_bottom = 3
	tab_sel.corner_radius_bottom_left = 0
	tab_sel.corner_radius_bottom_right = 0
	var tab_un := sb(Color(0, 0, 0, 0.25), 10, Color(0, 0, 0, 0), 0, 18.0, 8.0)
	tab_un.corner_radius_bottom_left = 0
	tab_un.corner_radius_bottom_right = 0
	var tab_hov := sb(Color(TEAL.r, TEAL.g, TEAL.b, 0.18), 10, Color(0, 0, 0, 0), 0, 18.0, 8.0)
	tab_hov.corner_radius_bottom_left = 0
	tab_hov.corner_radius_bottom_right = 0
	for t in ["TabContainer", "TabBar"]:
		th.set_stylebox("tab_selected", t, tab_sel)
		th.set_stylebox("tab_unselected", t, tab_un)
		th.set_stylebox("tab_hovered", t, tab_hov)
		th.set_stylebox("tab_disabled", t, tab_un)
		th.set_stylebox("tab_focus", t, sb(Color(0, 0, 0, 0), 10, Color(0, 0, 0, 0), 0))
		th.set_color("font_selected_color", t, SAND)
		th.set_color("font_unselected_color", t, MUTED)
		th.set_color("font_hovered_color", t, Color.WHITE)
	var tpanel := panel(0.9)
	tpanel.corner_radius_top_left = 0
	th.set_stylebox("panel", "TabContainer", tpanel)
	# ---- progress bars
	th.set_stylebox("background", "ProgressBar", sb(Color(0, 0, 0, 0.45), 999, Color(1, 1, 1, 0.08), 1, 0.0, 0.0))
	th.set_stylebox("fill", "ProgressBar", sb(TEAL, 999, Color(0, 0, 0, 0), 0, 0.0, 0.0))
	th.set_color("font_color", "ProgressBar", SAND)
	# ---- scroll bars
	for t in ["VScrollBar", "HScrollBar"]:
		th.set_stylebox("scroll", t, sb(Color(0, 0, 0, 0.25), 999, Color(0, 0, 0, 0), 0, 3.0, 3.0))
		th.set_stylebox("grabber", t, sb(Color(MUTED.r, MUTED.g, MUTED.b, 0.55), 999, Color(0, 0, 0, 0), 0, 3.0, 3.0))
		th.set_stylebox("grabber_highlight", t, sb(TEAL, 999, Color(0, 0, 0, 0), 0, 3.0, 3.0))
		th.set_stylebox("grabber_pressed", t, sb(TEAL.lightened(0.2), 999, Color(0, 0, 0, 0), 0, 3.0, 3.0))
	# ---- item lists, separators
	th.set_stylebox("panel", "ItemList", sb(Color(0, 0, 0, 0.3), 10, LINE, 1, 8.0, 8.0))
	th.set_stylebox("selected", "ItemList", sb(Color(TEAL.r, TEAL.g, TEAL.b, 0.35), 6, Color(0, 0, 0, 0), 0))
	th.set_stylebox("selected_focus", "ItemList", sb(Color(TEAL.r, TEAL.g, TEAL.b, 0.5), 6, Color(0, 0, 0, 0), 0))
	th.set_stylebox("hovered", "ItemList", sb(Color(1, 1, 1, 0.06), 6, Color(0, 0, 0, 0), 0))
	th.set_color("font_color", "ItemList", SAND)
	var sep := StyleBoxLine.new()
	sep.color = Color(LINE.r, LINE.g, LINE.b, 0.8)
	sep.thickness = 1
	th.set_stylebox("separator", "HSeparator", sep)
	th.set_constant("separation", "HSeparator", 14)
	_theme = th
	return th


## A section heading: sun-coloured text over a thin line.
static func heading(text: String, size: int = 22, c: Color = SUN) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	v.add_child(l)
	var line := ColorRect.new()
	line.color = Color(c.r, c.g, c.b, 0.35)
	line.custom_minimum_size = Vector2(0, 2)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(line)
	return v
