extends Control
## IGI 3 — S M Nazmuz Sakib : Bengali mission-select screen.
## Cards show place, objective count and reward; a poster gallery shows the
## campaign's Bengali/English propaganda slogans. Everything scrolls on small laptops.

const HUD := preload("res://scripts/ui/HUD.gd")
const UIStyle := preload("res://scripts/ui/UIStyle.gd")


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.028, 0.055, 0.06)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	# Subtle top band, IGI-style
	var band := ColorRect.new()
	band.color = Color(0.05, 0.18, 0.15, 0.9)
	band.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	band.size.y = 6
	add_child(band)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for s in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(s, 22)
	add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var root_v := VBoxContainer.new()
	root_v.add_theme_constant_override("separation", 8)
	root_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(root_v)

	var title_sz := 38 if get_viewport().size.x < 1100 else 52
	var title := HUD.make_label("IGI 3  —  এস এম নাজমুজ সাকিব", title_sz, Color(0.78, 0.97, 0.84))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root_v.add_child(title)
	var sub := HUD.make_label("ঢাকার গোপন অভিযান  •  সনটেক–কাজলা  •  পনেরোটি মিশন", 20, UIStyle.SUN)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root_v.add_child(sub)
	var rank := HUD.make_label("%s: %s   •   %s: %s   •   %s: %s/%s" % [
		Game.t("rank"), Game.campaign_rank, Game.t("total_score"),
		Game.bn(Game.total_campaign_score()), Game.t("completed"),
		Game.bn(Game.mission_records.size()), Game.bn(Game.MISSION_COUNT)], 18, Color(0.6, 1.0, 0.75))
	rank.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root_v.add_child(rank)
	root_v.add_child(HSeparator.new())

	if Game.has_checkpoint():
		var cont := HUD.make_button("▶ %s %s (checkpoint)" % [Game.t("continue"), Game.bn(Game.checkpoint.get("mission", 1))],
			func(): Game.resume_checkpoint())
		cont.custom_minimum_size = Vector2(0, 48)
		cont.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		root_v.add_child(cont)

	var brief := HUD.make_label(
		"আপনি একজন গোয়েন্দা অপারেটিভ। শহরের ভিড়ে মিশে লক্ষ্য চিহ্নিত করুন, তথ্য সংগ্রহ করুন "
		+ "এবং শত্রুদের চোখ এড়িয়ে নির্ধারিত স্থানে ফিরে আসুন। ধরা পড়লে অ্যালার্ম বাজবে।", 19, Color(0.86, 0.9, 0.86))
	brief.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	brief.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root_v.add_child(brief)

	var head := HUD.make_label("— %s —" % Game.t("campaign"), 22, UIStyle.SUN)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root_v.add_child(head)

	for i in range(1, Game.MISSION_COUNT + 1):
		var m: Dictionary = Game.mission_data(i)
		var nobj: int = (m.get("objectives", []) as Array).size()
		var locked: bool = i > Game.unlocked and not bool(Game.settings.get("unlock_all", false))
		var suffix := "" if not locked else "  [" + Game.t("locked") + " / অনুশীলন]"
		var b := HUD.make_button("%s. %s  —  %s%s" % [Game.bn(i), str(m.get("title", "")),
			str(m.get("title_en", "")), suffix], func(): Game.start_mission(i))
		b.custom_minimum_size = Vector2(0, 50)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		root_v.add_child(b)
		var meta := HUD.make_label("   %s   •   %s   •   %s %s   •   %s %s পয়েন্ট" % [
			str(m.get("place", "")), str(m.get("subtitle", "")),
			Game.t("objective"), Game.bn(nobj), Game.t("reward"), Game.bn(m.get("reward", 0))], 15, Color(0.7, 0.85, 0.78))
		meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		root_v.add_child(meta)
		var d := HUD.make_label("   " + str(m.get("brief", "")), 14, Color(0.72, 0.8, 0.76))
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		root_v.add_child(d)

	root_v.add_child(HSeparator.new())
	# Poster gallery — IGI-style wanted / propaganda posters with Bengali slogans
	var ph := HUD.make_label("— %s —" % Game.t("posters"), 22, UIStyle.SUN)
	ph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root_v.add_child(ph)
	for k in ["poster_1", "poster_2", "poster_3", "poster_4"]:
		var pl := HUD.make_label("★  " + Game.t(k), 17, Color(1.0, 0.85, 0.5))
		pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		root_v.add_child(pl)
	root_v.add_child(HUD.make_label("S M NAZMUS SAKIB  •  IGI 3  •  DHAKA", 13, Color(0.8, 0.7, 0.4)))

	root_v.add_child(HSeparator.new())
	var board := HUD.make_label("— MISSION RECORD —", 18, UIStyle.SUN)
	board.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root_v.add_child(board)
	for i in range(1, Game.MISSION_COUNT + 1):
		var rec: Variant = Game.mission_records.get(i, null)
		var line: String
		if rec is Dictionary:
			var d: Dictionary = rec
			line = "  %s. %s — %s • %s • %s pts • %s s" % [Game.bn(i), str(Game.mission_data(i).get("title_en", "")),
				str(d.get("medal", "")), str(d.get("objectives", "")), Game.bn(d.get("score", 0)), Game.bn(int(d.get("time", 0)))]
		else:
			line = "  %s. %s — %s" % [Game.bn(i), str(Game.mission_data(i).get("title_en", "")), Game.t("no")]
		root_v.add_child(HUD.make_label(line, 14, Color(0.72, 0.82, 0.78)))

	root_v.add_child(HSeparator.new())
	var keys := HUD.make_label(Game.t("controls"), 14, Color(0.7, 0.78, 0.75))
	keys.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root_v.add_child(keys)
	var credit := HUD.make_label("Map data © OpenStreetMap contributors, ODbL 1.0 — Kajla, Dhaka", 12, Color(0.5, 0.6, 0.58))
	credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root_v.add_child(credit)
