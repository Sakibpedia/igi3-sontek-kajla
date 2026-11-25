extends Node
## Bengali control-room / loudspeaker announcements, IGI-2 style.
## A PA chime + static precedes every line; the text appears as a subtitle and
## a HUD notice.  If a Bengali TTS voice exists, AudioManager.say() speaks it.

const LINES := {
	"start": "অপারেশন সনটেক কাজলা শুরু। অপারেটিভ, কাজলা এলাকায় প্রবেশ করুন। শত্রুদের চোখ এড়িয়ে চলুন।",
	"objective": "লক্ষ্য সম্পন্ন। পরবর্তী নির্দেশের জন্য অপেক্ষা করুন। সাবধানে এগোন।",
	"alarm": "সতর্ক! নিরাপত্তা ব্যবস্থা সক্রিয় হয়েছে। অবিলম্বে এলাকা ত্যাগ করুন।",
	"house": "ভেতরের ঘরে পাহারাদার আছে। থার্মাল ভিশন ব্যবহার করে সাবধানে এগোন।",
	"vehicle": "যানবাহন প্রবেশযোগ্য। দ্রুত পলায়নের জন্য ব্যবহার করুন।",
	"extract": "এক্সট্রাকশন পয়েন্ট প্রস্তুত। নির্ধারিত স্থানে ফিরে আসুন।",
	"success": "মিশন সফল। অপারেটিভ, আপনি এখন নিরাপদ।",
	"bcs_gate": "গেট খুলতে নিচের প্রশ্নের সঠিক উত্তর দিন।",
}

var _last := ""


func announce(key: String, extra: String = "") -> void:
	if key == _last and key == "objective":
		return
	_last = key
	var text := str(LINES.get(key, ""))
	if extra != "":
		text += " " + extra
	AudioManager.play_2d("sfx_pa_chime", -8.0, 1.0)
	AudioManager.say("কাজলা কন্ট্রোল রুম — PA", text, 5.5, 0.82)
	if Game.level != null and Game.level.get("hud") != null:
		Game.level.hud.notify("📢 " + text, Color(0.65, 0.95, 0.85))
