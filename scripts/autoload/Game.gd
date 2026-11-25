extends Node
## Global game state: missions, settings, progress, Bengali strings, input map, noise events, the
## mission score, the team's medkits and the character slots.
##
## Silent Rescue: Cox's Bazar - there is no money, no shop. Rewards (hostages rescued,
## senior guards handed to the police, the leader, the cache) are points on the mission score.

const UIStyleScript := preload("res://scripts/ui/UIStyle.gd")

signal settings_changed
signal noise_made(pos: Vector3, radius: float, faction: String)
## the mission score or the team's medkits changed (HUD)
signal score_changed
## the noise-dampening tape tier changed (key 7 / HUD tape bar)
signal tape_changed

const SAVE_PATH := "user://progress.cfg"
const SETTINGS_PATH := "user://settings.cfg"
const MISSION_COUNT := 15
const BN_DIGITS := ["০", "১", "২", "৩", "৪", "৫", "৬", "৭", "৮", "৯"]

# Collision layers (bit values)
const L_WORLD := 1
const L_PLAYER := 2
const L_FRIEND := 4
const L_ENEMY := 8
const L_PICKUP := 16
const L_VEHICLE := 32

var current_mission: int = 1
var unlocked: int = 1
var level: Node = null
var player: Node = null
var ui_font: Font
var stats := {}
var debug_log := false

var settings := {
	"master_volume": 0.85,
	"music_volume": 0.55,
	"sfx_volume": 0.9,
	"signals_volume": 1.0,
	"builtin_sounds": true,
	"mouse_sensitivity": 0.12,
	"quality": 1,
	"fullscreen": true,
	"invert_y": false,
	"fov": 75.0,
	"difficulty": 1,
	"crouch_toggle": true,
	"unlock_all": false,
}

const T := {
	"game_title": "IGI 3 — এস এম নাজমুজ সাকিব",
	"subtitle": "ঢাকার গোপন অভিযান • ১৫টি মিশন",
	"start": "শুরু করুন",
	"continue": "চালিয়ে যান",
	"missions": "মিশন নির্বাচন",
	"options": "সেটিংস",
	"quit": "প্রস্থান",
	"back": "ফিরে যান",
	"credits": "কৃতজ্ঞতা",
	"begin_mission": "মিশন শুরু",
	"locked": "তালাবদ্ধ",
	"loading": "লোড হচ্ছে…",
	"baking": "পথ নির্ণয় তৈরি হচ্ছে…",
	"objective": "লক্ষ্য",
	"health": "স্বাস্থ্য",
	"ammo": "গুলি",
	"reloading": "রিলোড হচ্ছে…",
	"no_ammo": "গুলি শেষ!",
	"paused": "বিরতি",
	"resume": "চালিয়ে যান",
	"restart": "আবার শুরু",
	"main_menu": "প্রধান মেনু",
	"next_mission": "পরবর্তী মিশন",
	"retry": "আবার চেষ্টা",
	"mission_complete": "মিশন সফল",
	"mission_failed": "মিশন ব্যর্থ",
	"you_died": "আপনি নিহত হয়েছেন",
	"detected": "শত্রু আপনাকে দেখে ফেলেছে!",
	"alarm": "সতর্ক সংকেত বেজে উঠেছে!",
	"master_volume": "মূল শব্দ",
	"music_volume": "সংগীত",
	"sfx_volume": "শব্দ প্রভাব",
	"signals_volume": "মিশন সংকেত-শব্দ (পিএ ঘোষণা, অ্যালার্ম)",
	"builtin_sounds": "গেমের নিজস্ব শব্দ (বন্ধ = শুধু আপনার দেওয়া শব্দ)",
	"mouse_sensitivity": "মাউস সংবেদনশীলতা",
	"quality": "গ্রাফিক্স মান",
	"q_low": "নিম্ন (দুর্বল ল্যাপটপ)",
	"q_med": "মাঝারি",
	"q_high": "উচ্চ",
	"fullscreen": "পূর্ণ পর্দা",
	"invert_y": "মাউস উল্টো (Y)",
	"fov": "দৃষ্টিক্ষেত্র",
	"difficulty": "কাঠিন্য",
	"d_easy": "সহজ",
	"d_normal": "সাধারণ",
	"d_hard": "কঠিন",
	"crouch_toggle": "Ctrl চাপলে বসা স্থায়ী",
	"kills": "নিহত শত্রু",
	"accuracy": "নির্ভুলতা",
	"headshots": "হেডশট",
	"time": "সময়",
	"civilians": "অ্যালার্ম সংখ্যা",
	"stealth": "গোপন অভিযান",
	"yes": "হ্যাঁ",
	"no": "না",
	"follow": "আলফা টিম: আমাকে অনুসরণ করো!",
	"hold": "আলফা টিম: এখানেই অবস্থান ধরে রাখো!",
	"ammo_drop": "স্যার, আপনার জন্য গুলির বাক্স রাখলাম!",
	"friendly_fire": "সাবধান স্যার, আমরা আপনার দলের!",
	"hq": "সদর দপ্তর",
	"alpha": "আলফা",
	"press_e": "[E]",
	"controls": "WASD চলাচল • Shift দৌড় • Ctrl শুয়ে পড়া • C/Q উঁকি • বাম ক্লিক গুলি • ডান ক্লিক নিশানা • ১/২/৩ অস্ত্র • R রিলোড • E ইন্টারঅ্যাক্ট / ছবি / নথি / চার্জ • ৪ গ্রেনেড • ৫ মলোটভ • ৬ টাইম বোমা • T থার্মাল • N হেডফোন • Tab লক্ষ্য • M মানচিত্র • Esc বিরতি",
	"faces_hint": "চরিত্র সাজানোর ব্যবস্থা এই সংস্করণে বাদ দেওয়া হয়েছে।",
	"victory_title": "অভিযান সফল",
	"victory_text": "সনটেক কাজলার লক্ষ্যগুলো সম্পন্ন। অপারেটিভ নিরাপদে ফিরে এসেছেন।",
	"campaign": "অভিযান",
	"mission_brief": "মিশন ব্রিফিং",
	"posters": "পোস্টার সংগ্রহ",
	"poster_1": "আইজিআই ৩ — এক অপারেটিভ, পনেরোটি অভিযান",
	"poster_2": "সাহসী হৃদয়, নিঃশব্দ পদচারণা — এস এম নাজমুজ সাকিব",
	"poster_3": "ঢাকার অন্ধকারে সত্যের আলো — IGI 3",
	"poster_4": "লক্ষ্য অর্জনই আমাদের পরিচয় — S M Nazmuz Sakib",
	"bcs_notice": "বিসিএস প্রশ্নের উত্তর দিয়ে গেট খুলুন",
	"reward": "পুরস্কার",
	"rank": "পদমর্যাদা",
	"total_score": "মোট পয়েন্ট",
	"completed": "সম্পন্ন",
	"locked_hint": "পরবর্তী মিশন আনলক করতে এই মিশনটি সম্পন্ন করুন",
}

const MISSIONS := [
	{
		"title": "কাজলা reconnaissance", "title_en": "Kajla Recon",
		"place": "কাজলা, ঢাকা", "time": "night", "stealth": true,
		"zone": "north", "subtitle": "Photograph + observe", "reward": 400,
		"brief": "কাজলা বাস স্টপ এলাকায় প্রবেশ করুন, তিনটি লক্ষ্যের ছবি তুলুন, একটি নথি সংগ্রহ করুন এবং কাজলা পার্ক থেকে পর্যবেক্ষণ শেষ করে এক্সট্রাকশন পয়েন্টে ফিরে আসুন।",
		"objectives": [
			{"type": "reach", "text": "কাজলা বাস স্টপ এলাকায় প্রবেশ করুন", "pos_y": 3, "radius": 20.0},
			{"type": "photo", "text": "তিনটি লক্ষ্যের ছবি তুলুন", "label": "[E] ছবি তুলুন", "count": 3},
			{"type": "collect", "text": "একটি গোপন নথি সংগ্রহ করুন", "label": "[E] নথি নিন", "count": 1},
			{"type": "reach", "text": "কাজলা পার্ক থেকে পর্যবেক্ষণ করুন", "pos_y": 2, "radius": 14.0},
			{"type": "infiltrate", "text": "ভেতরের ঘরে প্রবেশ করুন", "pos_y": 4, "radius": 7.0},
			{"type": "survive", "text": "অবস্থান ধরে ২৫ সেকেন্ড টিকে থাকুন", "time": 25.0, "pos_y": 4, "radius": 12.0},
			{"type": "photo", "text": "নির্দিষ্ট যানবাহন চিহ্নিত করুন", "label": "[E] যানবাহন চিহ্নিত", "count": 1},
			{"type": "sabotage", "text": "শত্রুদের অস্ত্রের গুদাম ধ্বংস করুন", "label": "[E] চার্জ লাগান", "count": 1},
			{"type": "bcs_gate", "text": "BCS প্রশ্নের উত্তর দিয়ে গেট খুলুন", "label": "[E] গেট খুলুন", "count": 1},
			{"type": "extract", "text": "এক্সট্রাকশন পয়েন্টে ফিরে আসুন", "pos_y": 1, "radius": 8.0},
		],
	},
	{
		"title": "নথি উদ্ধার", "title_en": "Document Run",
		"place": "কাজলা, ঢাকা", "time": "night", "stealth": true,
		"zone": "south", "subtitle": "Wiretap + documents", "reward": 550,
		"brief": "একটি ফোনে ওয়্যারট্যাপ লাগান, দুটি নথির গুচ্ছ সংগ্রহ করুন এবং আরেকটি লক্ষ্যের ছবি তুলুন। পাহারাদাররা দেখে ফেললে অ্যালার্ম বাজবে।",
		"objectives": [
			{"type": "wiretap", "text": "ফোনে ওয়্যারট্যাপ লাগান", "label": "[E] ওয়্যারট্যাপ", "count": 1},
			{"type": "collect", "text": "দুটি নথির গুচ্ছ সংগ্রহ করুন", "label": "[E] নথি নিন", "count": 2},
			{"type": "photo", "text": "অতিরিক্ত একটি লক্ষ্যের ছবি তুলুন", "label": "[E] ছবি তুলুন", "count": 1},
			{"type": "infiltrate", "text": "ভেতরের ঘরে প্রবেশ করুন", "pos_y": 4, "radius": 7.0},
			{"type": "survive", "text": "অবস্থান ধরে ২৫ সেকেন্ড টিকে থাকুন", "time": 25.0, "pos_y": 4, "radius": 12.0},
			{"type": "photo", "text": "নির্দিষ্ট যানবাহন চিহ্নিত করুন", "label": "[E] যানবাহন চিহ্নিত", "count": 1},
			{"type": "sabotage", "text": "শত্রুদের অস্ত্রের গুদাম ধ্বংস করুন", "label": "[E] চার্জ লাগান", "count": 1},
			{"type": "bcs_gate", "text": "BCS প্রশ্নের উত্তর দিয়ে গেট খুলুন", "label": "[E] গেট খুলুন", "count": 1},
			{"type": "extract", "text": "এক্সট্রাকশন পয়েন্টে ফিরে আসুন", "pos_y": 1, "radius": 8.0},
		],
	},
	{
		"title": "পার্কে নজরদারি", "title_en": "Park Stakeout",
		"place": "কাজলা পার্ক, ঢাকা", "time": "night", "stealth": true,
		"zone": "park", "subtitle": "Stake out + eliminate", "reward": 700,
		"brief": "কাজলা পার্কে অবস্থান নিন। দুটি লক্ষ্যের ছবি তুলুন, চিহ্নিত কমান্ডারকে বাদ দিন, একটি নথি নিন এবং বের হন। ভেতরের ঘরেও পাহারাদার আছে — সাবধান।",
		"objectives": [
			{"type": "reach", "text": "কাজলা পার্কে অবস্থান নিন", "pos_y": 2, "radius": 16.0},
			{"type": "photo", "text": "দুটি লক্ষ্যের ছবি তুলুন", "label": "[E] ছবি তুলুন", "count": 2},
			{"type": "eliminate", "text": "চিহ্নিত কমান্ডারকে বাদ দিন", "tag": "commander", "count": 1},
			{"type": "collect", "text": "কমান্ডারের কাছ থেকে নথি নিন", "label": "[E] নথি নিন", "count": 1},
			{"type": "infiltrate", "text": "ভেতরের ঘরে প্রবেশ করুন", "pos_y": 4, "radius": 7.0},
			{"type": "survive", "text": "অবস্থান ধরে ২৫ সেকেন্ড টিকে থাকুন", "time": 25.0, "pos_y": 4, "radius": 12.0},
			{"type": "photo", "text": "নির্দিষ্ট যানবাহন চিহ্নিত করুন", "label": "[E] যানবাহন চিহ্নিত", "count": 1},
			{"type": "sabotage", "text": "শত্রুদের অস্ত্রের গুদাম ধ্বংস করুন", "label": "[E] চার্জ লাগান", "count": 1},
			{"type": "bcs_gate", "text": "BCS প্রশ্নের উত্তর দিয়ে গেট খুলুন", "label": "[E] গেট খুলুন", "count": 1},
			{"type": "extract", "text": "এক্সট্রাকশন পয়েন্টে ফিরে আসুন", "pos_y": 1, "radius": 8.0},
		],
	},
	{
		"title": "R110 সাবোতাজ", "title_en": "R110 Sabotage",
		"place": "কাজলা — R110 হাইওয়ে", "time": "night", "stealth": true,
		"zone": "highway", "subtitle": "Charges + alarm", "reward": 900, "alarm_limit": 120.0,
		"brief": "দুটি যানবাহনে বিস্ফোরক লাগান, অ্যালার্ম সিস্টেম অক্ষম করুন এবং একটি নথি সংগ্রহ করুন। অ্যালার্ম বাজলে ১২০ সেকেন্ডের মধ্যে পালাতে হবে। গাড়ি চালিয়ে দ্রুত বের হতে পারেন।",
		"objectives": [
			{"type": "sabotage", "text": "দুটি যানবাহনে চার্জ লাগান", "label": "[E] চার্জ লাগান", "count": 2},
			{"type": "disable_alarm", "text": "অ্যালার্ম সিস্টেম অক্ষম করুন", "label": "[E] অ্যালার্ম বন্ধ করুন", "count": 1},
			{"type": "collect", "text": "একটি নথি সংগ্রহ করুন", "label": "[E] নথি নিন", "count": 1},
			{"type": "infiltrate", "text": "ভেতরের ঘরে প্রবেশ করুন", "pos_y": 4, "radius": 7.0},
			{"type": "survive", "text": "অবস্থান ধরে ২৫ সেকেন্ড টিকে থাকুন", "time": 25.0, "pos_y": 4, "radius": 12.0},
			{"type": "photo", "text": "নির্দিষ্ট যানবাহন চিহ্নিত করুন", "label": "[E] যানবাহন চিহ্নিত", "count": 1},
			{"type": "sabotage", "text": "শত্রুদের অস্ত্রের গুদাম ধ্বংস করুন", "label": "[E] চার্জ লাগান", "count": 1},
			{"type": "bcs_gate", "text": "BCS প্রশ্নের উত্তর দিয়ে গেট খুলুন", "label": "[E] গেট খুলুন", "count": 1},
			{"type": "extract", "text": "এক্সট্রাকশন পয়েন্টে ফিরে আসুন", "pos_y": 1, "radius": 8.0},
		],
	},
	{
		"title": "চূড়ান্ত অভিযান", "title_en": "Final Sweep",
		"place": "কাজলা — পুরো এলাকা", "time": "night", "stealth": true,
		"zone": "full", "subtitle": "Full operational sweep", "reward": 1400, "alarm_limit": 150.0,
		"brief": "দুই কমান্ডারকে বাদ দিন, দুটি লক্ষ্যে চার্জ লাগান, একটি ওয়্যারট্যাপ লাগান এবং দুটি নথি সংগ্রহ করুন — সব শেষে বের হন। এটি সবচেয়ে কঠিন মিশন; থার্মাল ভিশন (T) ও গাড়ি কাজে লাগান।",
		"objectives": [
			{"type": "eliminate", "text": "দুই কমান্ডারকে বাদ দিন", "tag": "commander", "count": 2},
			{"type": "sabotage", "text": "দুটি লক্ষ্যে চার্জ লাগান", "label": "[E] চার্জ লাগান", "count": 2},
			{"type": "wiretap", "text": "ওয়্যারট্যাপ লাগান", "label": "[E] ওয়্যারট্যাপ", "count": 1},
			{"type": "collect", "text": "দুটি নথি সংগ্রহ করুন", "label": "[E] নথি নিন", "count": 2},
			{"type": "infiltrate", "text": "ভেতরের ঘরে প্রবেশ করুন", "pos_y": 4, "radius": 7.0},
			{"type": "survive", "text": "অবস্থান ধরে ২৫ সেকেন্ড টিকে থাকুন", "time": 25.0, "pos_y": 4, "radius": 12.0},
			{"type": "photo", "text": "নির্দিষ্ট যানবাহন চিহ্নিত করুন", "label": "[E] যানবাহন চিহ্নিত", "count": 1},
			{"type": "sabotage", "text": "শত্রুদের অস্ত্রের গুদাম ধ্বংস করুন", "label": "[E] চার্জ লাগান", "count": 1},
			{"type": "bcs_gate", "text": "BCS প্রশ্নের উত্তর দিয়ে গেট খুলুন", "label": "[E] গেট খুলুন", "count": 1},
			{"type": "extract", "text": "এক্সট্রাকশন পয়েন্টে ফিরে আসুন", "pos_y": 1, "radius": 8.0},
		],
	},
	{
		"title": "ছাদের যুদ্ধ", "title_en": "Rooftop War",
		"place": "কাজলা — বহুতল ভবন", "time": "night", "stealth": true,
		"zone": "rooftops", "subtitle": "Vertical assault", "reward": 1800,
		"parachute": true, "alarm_limit": 180.0,
		"brief": "প্যারাস্যুট থেকে নেমে বহুতল বাড়ির ছাদ দখল করুন। ভেতরের ঘর, উপরের তলা আর ছাদে পাহারাদার আছে। ছাদ থেকে লক্ষ্য চিহ্নিত করে, কমান্ডারকে বাদ দিয়ে, চার্জ লাগিয়ে এবং নথি সংগ্রহ করে বের হন।",
		"objectives": [
			{"type": "infiltrate", "text": "প্রথম বাড়ির ভেতরে প্রবেশ করুন", "pos_y": 4, "radius": 7.0},
			{"type": "reach", "text": "উপরের তলায় উঠুন", "pos_y": 5, "radius": 7.0},
			{"type": "reach", "text": "ছাদে পৌঁছান", "pos_y": 6, "radius": 8.0},
			{"type": "photo", "text": "ছাদ থেকে দুটি লক্ষ্য চিহ্নিত করুন", "label": "[E] ছবি তুলুন", "count": 2},
			{"type": "eliminate", "text": "দুই কমান্ডারকে বাদ দিন", "tag": "commander", "count": 2},
			{"type": "sabotage", "text": "দুটি লক্ষ্যে চার্জ লাগান", "label": "[E] চার্জ লাগান", "count": 2},
			{"type": "bcs_gate", "text": "BCS প্রশ্নের উত্তর দিয়ে গেট খুলুন", "label": "[E] গেট খুলুন", "count": 1},
			{"type": "collect", "text": "দুটি নথি সংগ্রহ করুন", "label": "[E] নথি নিন", "count": 2},
			{"type": "survive", "text": "ছাদে ২৫ সেকেন্ড অবস্থান ধরে থাকুন", "time": 25.0, "pos_y": 6, "radius": 12.0},
			{"type": "extract", "text": "এক্সট্রাকশন পয়েন্টে ফিরে আসুন", "pos_y": 1, "radius": 8.0},
		],
	},
	{
		"title": "কূটনৈতিক চৌহদ্দি", "title_en": "Diplomatic Compound",
		"place": "গুলশান-২, ঢাকা", "time": "night", "stealth": true,
		"zone": "north", "subtitle": "Wiretap + surveillance", "reward": 2100,
		"brief": "দূতাবাসের চৌহদ্দির কাছে গোপনে প্রবেশ করুন। দুটি লক্ষ্যের ছবি তুলুন, যোগাযোগের তারে ওয়্যারট্যাপ লাগান এবং গোপন নথি সংগ্রহ করে নিরাপদে বের হন। পাহারাদাররা দেখে ফেললে অ্যালার্ম বাজবে।",
		"objectives": [
			{"type": "reach", "text": "দূতাবাসের উত্তর প্রান্তে পৌঁছান", "pos_y": 3, "radius": 20.0},
			{"type": "photo", "text": "দুটি লক্ষ্যের ছবি তুলুন", "label": "[E] ছবি তুলুন", "count": 2},
			{"type": "wiretap", "text": "যোগাযোগের তারে ওয়্যারট্যাপ লাগান", "label": "[E] ওয়্যারট্যাপ", "count": 1},
			{"type": "collect", "text": "গোপন নথি সংগ্রহ করুন", "label": "[E] নথি নিন", "count": 1},
			{"type": "infiltrate", "text": "ভেতরের ঘরে প্রবেশ করুন", "pos_y": 4, "radius": 7.0},
			{"type": "bcs_gate", "text": "BCS প্রশ্নের উত্তর দিয়ে গেট খুলুন", "label": "[E] গেট খুলুন", "count": 1},
			{"type": "extract", "text": "এক্সট্রাকশন পয়েন্টে ফিরে আসুন", "pos_y": 1, "radius": 8.0},
		],
	},
	{
		"title": "মোতিজয়েল নিশাচল", "title_en": "Motijheel Nightfall",
		"place": "মোতিজয়েল, ঢাকা", "time": "night", "stealth": true,
		"zone": "south", "subtitle": "Documents + sabotage", "reward": 2400,
		"brief": "ব্যাংক-অফিস এলাকায় নামুন। ফোনে ওয়্যারট্যাপ লাগান, দুটি নথি নিন এবং দুটি যানবাহনে চার্জ লাগান। শত্রুদের গুদাম ধ্বংস করে BCS প্রশ্নের উত্তর দিয়ে বের হন।",
		"objectives": [
			{"type": "wiretap", "text": "অফিসের ফোনে ওয়্যারট্যাপ লাগান", "label": "[E] ওয়্যারট্যাপ", "count": 1},
			{"type": "collect", "text": "দুটি গোপন নথি সংগ্রহ করুন", "label": "[E] নথি নিন", "count": 2},
			{"type": "sabotage", "text": "দুটি যানবাহনে চার্জ লাগান", "label": "[E] চার্জ লাগান", "count": 2},
			{"type": "photo", "text": "নির্দিষ্ট যানবাহন চিহ্নিত করুন", "label": "[E] যানবাহন চিহ্নিত", "count": 1},
			{"type": "sabotage", "text": "শত্রুদের অস্ত্রের গুদাম ধ্বংস করুন", "label": "[E] চার্জ লাগান", "count": 1},
			{"type": "bcs_gate", "text": "BCS প্রশ্নের উত্তর দিয়ে গেট খুলুন", "label": "[E] গেট খুলুন", "count": 1},
			{"type": "extract", "text": "এক্সট্রাকশন পয়েন্টে ফিরে আসুন", "pos_y": 1, "radius": 8.0},
		],
	},
	{
		"title": "হাতিরঝিল সেতু", "title_en": "Hatirjheel Bridge",
		"place": "হাতিরঝিল, ঢাকা", "time": "night", "stealth": true,
		"zone": "park", "subtitle": "Stakeout + eliminate", "reward": 2700,
		"brief": "সেতুর পাশে অবস্থান নিন। চিহ্নিত কমান্ডারকে বাদ দিন, দুটি লক্ষ্যের ছবি তুলুন, একটি নথি নিন এবং ৩০ সেকেন্ড অবস্থান ধরে থাকুন। জলের কাছে সাবধান।",
		"objectives": [
			{"type": "reach", "text": "সেতুর পাশে অবস্থান নিন", "pos_y": 2, "radius": 16.0},
			{"type": "photo", "text": "দুটি লক্ষ্যের ছবি তুলুন", "label": "[E] ছবি তুলুন", "count": 2},
			{"type": "eliminate", "text": "চিহ্নিত কমান্ডারকে বাদ দিন", "tag": "commander", "count": 1},
			{"type": "collect", "text": "কমান্ডারের নথি সংগ্রহ করুন", "label": "[E] নথি নিন", "count": 1},
			{"type": "survive", "text": "অবস্থান ধরে ৩০ সেকেন্ড টিকে থাকুন", "time": 30.0, "pos_y": 2, "radius": 12.0},
			{"type": "bcs_gate", "text": "BCS প্রশ্নের উত্তর দিয়ে গেট খুলুন", "label": "[E] গেট খুলুন", "count": 1},
			{"type": "extract", "text": "এক্সট্রাকশন পয়েন্টে ফিরে আসুন", "pos_y": 1, "radius": 8.0},
		],
	},
	{
		"title": "লালবাগের দুর্গ", "title_en": "Lalbagh Fort",
		"place": "লালবাগ, ঢাকা", "time": "night", "stealth": true,
		"zone": "full", "subtitle": "Fort stronghold", "reward": 3000, "alarm_limit": 140.0,
		"brief": "ঐতিহাসিক দুর্গ এলাকায় পাহারাদার বেশি। ভেতরে প্রবেশ করুন, দুটি লক্ষ্যে চার্জ লাগান, এক কমান্ডারকে বাদ দিন এবং অবস্থান ধরে থাকুন। থার্মাল ভিশন কাজে লাগান।",
		"objectives": [
			{"type": "infiltrate", "text": "দুর্গের ভেতরে প্রবেশ করুন", "pos_y": 4, "radius": 7.0},
			{"type": "sabotage", "text": "দুটি লক্ষ্যে চার্জ লাগান", "label": "[E] চার্জ লাগান", "count": 2},
			{"type": "eliminate", "text": "এক কমান্ডারকে বাদ দিন", "tag": "commander", "count": 1},
			{"type": "photo", "text": "দুর্গের ভেতরের লক্ষ্য চিহ্নিত করুন", "label": "[E] ছবি তুলুন", "count": 2},
			{"type": "survive", "text": "অবস্থান ধরে ২৫ সেকেন্ড টিকে থাকুন", "time": 25.0, "pos_y": 4, "radius": 12.0},
			{"type": "bcs_gate", "text": "BCS প্রশ্নের উত্তর দিয়ে গেট খুলুন", "label": "[E] গেট খুলুন", "count": 1},
			{"type": "extract", "text": "এক্সট্রাকশন পয়েন্টে ফিরে আসুন", "pos_y": 1, "radius": 8.0},
		],
	},
	{
		"title": "করওয়ান বাজার", "title_en": "Karwan Bazar",
		"place": "করওয়ান বাজার, ঢাকা", "time": "night", "stealth": true,
		"zone": "highway", "subtitle": "Market sweep", "reward": 3300, "alarm_limit": 150.0,
		"brief": "ব্যস্ত বাজার এলাকায় মিশে দুটি লক্ষ্যের ছবি তুলুন, একটি যানবাহনে চার্জ লাগান, ফোনে ওয়্যারট্যাপ লাগান ও দুটি নথি নিন। বেশি অ্যালার্ম হলে মিশন ব্যর্থ হবে।",
		"objectives": [
			{"type": "photo", "text": "দুটি লক্ষ্যের ছবি তুলুন", "label": "[E] ছবি তুলুন", "count": 2},
			{"type": "sabotage", "text": "একটি যানবাহনে চার্জ লাগান", "label": "[E] চার্জ লাগান", "count": 1},
			{"type": "wiretap", "text": "বাজারের ফোনে ওয়্যারট্যাপ লাগান", "label": "[E] ওয়্যারট্যাপ", "count": 1},
			{"type": "collect", "text": "দুটি নথি সংগ্রহ করুন", "label": "[E] নথি নিন", "count": 2},
			{"type": "eliminate", "text": "এক কমান্ডারকে বাদ দিন", "tag": "commander", "count": 1},
			{"type": "bcs_gate", "text": "BCS প্রশ্নের উত্তর দিয়ে গেট খুলুন", "label": "[E] গেট খুলুন", "count": 1},
			{"type": "extract", "text": "এক্সট্রাকশন পয়েন্টে ফিরে আসুন", "pos_y": 1, "radius": 8.0},
		],
	},
	{
		"title": "বিমানবন্দরের ভোর", "title_en": "Airport Dawn",
		"place": "শাহজালাল বিমানবন্দর", "time": "night", "stealth": true,
		"zone": "north", "subtitle": "Cargo infiltration", "reward": 3600, "parachute": true,
		"brief": "প্যারাস্যুট থেকে নেমে কার্গো এলাকায় প্রবেশ করুন। শত্রুদের গুদাম ধ্বংস করুন, দুটি লক্ষ্যে চার্জ লাগান, ম্যানিফেস্ট নিন ও ছবি তুলুন। অ্যালার্ম এড়িয়ে বের হন।",
		"objectives": [
			{"type": "infiltrate", "text": "কার্গো এলাকায় প্রবেশ করুন", "pos_y": 4, "radius": 7.0},
			{"type": "photo", "text": "দুটি লক্ষ্যের ছবি তুলুন", "label": "[E] ছবি তুলুন", "count": 2},
			{"type": "sabotage", "text": "দুটি লক্ষ্যে চার্জ লাগান", "label": "[E] চার্জ লাগান", "count": 2},
			{"type": "sabotage", "text": "শত্রুদের অস্ত্রের গুদাম ধ্বংস করুন", "label": "[E] চার্জ লাগান", "count": 1},
			{"type": "collect", "text": "কার্গো ম্যানিফেস্ট সংগ্রহ করুন", "label": "[E] নথি নিন", "count": 1},
			{"type": "survive", "text": "অবস্থান ধরে ২৫ সেকেন্ড টিকে থাকুন", "time": 25.0, "pos_y": 4, "radius": 12.0},
			{"type": "extract", "text": "এক্সট্রাকশন পয়েন্টে ফিরে আসুন", "pos_y": 1, "radius": 8.0},
		],
	},
	{
		"title": "বুড়িগঙ্গার রাত", "title_en": "Buriganga Night",
		"place": "বুড়িগঙ্গা নদী, ঢাকা", "time": "night", "stealth": true,
		"zone": "south", "subtitle": "Riverfront operation", "reward": 3900, "alarm_limit": 160.0,
		"brief": "নদীপারের গুদামে ঢুকে দুই কমান্ডারকে বাদ দিন, দুটি চার্জ লাগান, ওয়্যারট্যাপ লাগান এবং দুটি নথি নিন। ঘাটে ফিরে যেতে হবে দ্রুত।",
		"objectives": [
			{"type": "eliminate", "text": "দুই কমান্ডারকে বাদ দিন", "tag": "commander", "count": 2},
			{"type": "sabotage", "text": "দুটি লক্ষ্যে চার্জ লাগান", "label": "[E] চার্জ লাগান", "count": 2},
			{"type": "wiretap", "text": "নদীপারের ফোনে ওয়্যারট্যাপ লাগান", "label": "[E] ওয়্যারট্যাপ", "count": 1},
			{"type": "collect", "text": "দুটি নথি সংগ্রহ করুন", "label": "[E] নথি নিন", "count": 2},
			{"type": "photo", "text": "নৌযান চিহ্নিত করুন", "label": "[E] ছবি তুলুন", "count": 1},
			{"type": "bcs_gate", "text": "BCS প্রশ্নের উত্তর দিয়ে গেট খুলুন", "label": "[E] গেট খুলুন", "count": 1},
			{"type": "extract", "text": "এক্সট্রাকশন পয়েন্টে ফিরে আসুন", "pos_y": 1, "radius": 8.0},
		],
	},
	{
		"title": "সংসদ এলাকা", "title_en": "Parliament Zone",
		"place": "জাতীয় সংসদ, ঢাকা", "time": "night", "stealth": true,
		"zone": "full", "subtitle": "High-value sweep", "reward": 4200, "alarm_limit": 180.0,
		"brief": "সংসদ এলাকার চারপাশে পাহারা বেশি। দুই কমান্ডারকে বাদ দিন, দুটি লক্ষ্যে চার্জ লাগান, BCS প্রশ্নের উত্তর দিয়ে গেট খুলুন ও অবস্থান ধরে থাকুন। সবচেয়ে কঠিন অভিযান।",
		"objectives": [
			{"type": "reach", "text": "সংসদ এলাকার দক্ষিণ প্রান্তে পৌঁছান", "pos_y": 2, "radius": 18.0},
			{"type": "eliminate", "text": "দুই কমান্ডারকে বাদ দিন", "tag": "commander", "count": 2},
			{"type": "sabotage", "text": "দুটি লক্ষ্যে চার্জ লাগান", "label": "[E] চার্জ লাগান", "count": 2},
			{"type": "photo", "text": "দুটি লক্ষ্য চিহ্নিত করুন", "label": "[E] ছবি তুলুন", "count": 2},
			{"type": "bcs_gate", "text": "BCS প্রশ্নের উত্তর দিয়ে গেট খুলুন", "label": "[E] গেট খুলুন", "count": 1},
			{"type": "survive", "text": "অবস্থান ধরে ৩০ সেকেন্ড টিকে থাকুন", "time": 30.0, "pos_y": 4, "radius": 12.0},
			{"type": "extract", "text": "এক্সট্রাকশন পয়েন্টে ফিরে আসুন", "pos_y": 1, "radius": 8.0},
		],
	},
	{
		"title": "শেষ অভিযান", "title_en": "Final Operation",
		"place": "কাজলা — সমগ্র এলাকা", "time": "night", "stealth": true,
		"zone": "rooftops", "subtitle": "Final extraction", "reward": 5000,
		"parachute": true, "alarm_limit": 200.0,
		"brief": "চূড়ান্ত অভিযান: ছাদ দখল করুন, দুই কমান্ডারকে বাদ দিন, দুটি চার্জ লাগান, ওয়্যারট্যাপ লাগান, দুটি নথি নিন এবং BCS প্রশ্নের উত্তর দিন। অ্যালার্ম ২০০ সেকেন্ডের বেশি হলে ব্যর্থ।",
		"objectives": [
			{"type": "infiltrate", "text": "প্রথম বাড়ির ভেতরে প্রবেশ করুন", "pos_y": 4, "radius": 7.0},
			{"type": "reach", "text": "উপরের তলায় উঠুন", "pos_y": 5, "radius": 7.0},
			{"type": "reach", "text": "ছাদে পৌঁছান", "pos_y": 6, "radius": 8.0},
			{"type": "eliminate", "text": "দুই কমান্ডারকে বাদ দিন", "tag": "commander", "count": 2},
			{"type": "sabotage", "text": "দুটি লক্ষ্যে চার্জ লাগান", "label": "[E] চার্জ লাগান", "count": 2},
			{"type": "wiretap", "text": "ওয়্যারট্যাপ লাগান", "label": "[E] ওয়্যারট্যাপ", "count": 1},
			{"type": "collect", "text": "দুটি নথি সংগ্রহ করুন", "label": "[E] নথি নিন", "count": 2},
			{"type": "bcs_gate", "text": "BCS প্রশ্নের উত্তর দিয়ে গেট খুলুন", "label": "[E] গেট খুলুন", "count": 1},
			{"type": "survive", "text": "ছাদে ২৫ সেকেন্ড অবস্থান ধরে থাকুন", "time": 25.0, "pos_y": 6, "radius": 12.0},
			{"type": "extract", "text": "এক্সট্রাকশন পয়েন্টে ফিরে আসুন", "pos_y": 1, "radius": 8.0},
		],
	},
]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_register_inputs()
	_setup_audio_buses()
	_setup_font()
	load_settings()
	load_custom()
	load_progress()
	load_economy()
	load_igi_save()
	apply_settings()
	reset_stats()
	if DisplayServer.get_name() != "headless":
		get_window().title = "IGI 3 — S M Nazmuz Sakib  |  Dhaka  |  15 Missions"


func t(key: String) -> String:
	return str(T.get(key, key))


func bn(value) -> String:
	var s := str(value)
	var out := ""
	for i in s.length():
		var code: int = s.unicode_at(i)
		if code >= 48 and code <= 57:
			out += BN_DIGITS[code - 48]
		else:
			out += s.substr(i, 1)
	return out


func bn_time(seconds: float) -> String:
	var total: int = int(seconds)
	var m: int = int(total / 60.0)
	var s: int = total % 60
	return bn("%02d:%02d" % [m, s])


func mission_data(idx: int) -> Dictionary:
	var i: int = clampi(idx, 1, MISSION_COUNT) - 1
	return MISSIONS[i]


func mission_scene(idx: int) -> String:
	return "res://scenes/missions/M%02d.tscn" % idx


func start_mission(idx: int) -> void:
	current_mission = clampi(idx, 1, MISSION_COUNT)
	reset_stats()
	set_medkits(START_MEDKITS)
	get_tree().paused = false
	# Paint a loading card first: building 1,400+ colony buildings takes time.
	var layer := CanvasLayer.new()
	layer.layer = 200
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.05, 0.04, 0.96)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(shade)
	var lab := Label.new()
	lab.text = "মিশন লোড হচ্ছে…\n" + str(current_mission) + " / " + str(MISSION_COUNT) + "  —  সনটেক কাজলা তৈরি হচ্ছে"
	lab.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lab.add_theme_font_size_override("font_size", 30)
	lab.add_theme_color_override("font_color", Color(0.75, 0.95, 0.8))
	layer.add_child(lab)
	get_tree().root.add_child(layer)
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().change_scene_to_file(mission_scene(current_mission))
	await get_tree().process_frame
	layer.queue_free()


func restart_mission() -> void:
	start_mission(current_mission)


func goto_menu() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	level = null
	player = null
	get_tree().change_scene_to_file("res://scenes/SontekMenu.tscn")


func complete_mission(idx: int) -> void:
	if idx >= unlocked and idx < MISSION_COUNT:
		unlocked = idx + 1
	best_score[idx] = maxi(int(best_score.get(idx, 0)), int(stats.get("score", 0)))
	save_progress()


func reset_stats() -> void:
	stats = {"kills": 0, "shots": 0, "hits": 0, "headshots": 0, "civilians": 0, "detected": false, "time": 0.0, "score": 0, "clues": 0,
		"arrests": 0, "police": 0, "takedowns": 0, "rescued": 0, "hero_rescues": 0,
		"defused": 0, "viruses": 0, "procedures": 0, "chloro": 0, "swaps": 0}
	score_changed.emit()


func noise(pos: Vector3, radius: float, faction: String) -> void:
	noise_made.emit(pos, radius, faction)


func difficulty_damage_scale() -> float:
	var d: int = int(settings["difficulty"])
	if d == 0:
		return 0.55
	if d == 2:
		return 1.35
	return 1.0


func difficulty_accuracy_scale() -> float:
	var d: int = int(settings["difficulty"])
	if d == 0:
		return 1.6
	if d == 2:
		return 0.75
	return 1.0


func quality() -> int:
	return int(settings["quality"])


# ---------------------------------------------------------------- input map
func _register_inputs() -> void:
	_bind_key("move_forward", KEY_W)
	_bind_key("move_forward", KEY_UP)
	_bind_key("move_back", KEY_S)
	_bind_key("move_back", KEY_DOWN)
	_bind_key("move_left", KEY_A)
	_bind_key("move_left", KEY_LEFT)
	_bind_key("move_right", KEY_D)
	_bind_key("move_right", KEY_RIGHT)
	_bind_key("sprint", KEY_SHIFT)
	_bind_key("crouch", KEY_CTRL)
	_bind_key("lean", KEY_C)
	_bind_key("lean_left", KEY_Q)
	_bind_key("jump", KEY_SPACE)
	_bind_key("reload", KEY_R)
	_bind_key("interact", KEY_E)
	_bind_key("weapon_1", KEY_1)
	_bind_key("weapon_2", KEY_2)
	_bind_key("weapon_3", KEY_3)
	_bind_key("team_order", KEY_H)
	_bind_key("carry", KEY_G)
	_bind_key("give_water", KEY_F)
	_bind_key("tie", KEY_X)
	_bind_key("ally_assist", KEY_J)
	_bind_key("binoculars", KEY_B)
	_bind_key("scope", KEY_8)
	_bind_key("thermal", KEY_T)
	_bind_key("toggle_camera", KEY_V)
	_bind_key("objectives", KEY_TAB)
	_bind_key("prone", KEY_Z)
	_bind_key("throw_grenade", KEY_4)
	_bind_key("throw_molotov", KEY_5)
	_bind_key("plant_bomb", KEY_6)
	_bind_key("call_alpha", KEY_L)
	_bind_key("send_extract", KEY_K)
	_bind_key("headphones", KEY_N)
	_bind_key("give_food", KEY_Y)
	_bind_key("companion", KEY_U)
	_bind_key("radio", KEY_O)
	_bind_key("ask", KEY_I)
	_bind_key("cycle_tape", KEY_7)
	_bind_key("intercept", KEY_M)
	_bind_key("skip_brief", KEY_ENTER)
	_bind_key("pause", KEY_ESCAPE)
	_bind_key("pause", KEY_P)
	_bind_mouse("fire", MOUSE_BUTTON_LEFT)
	_bind_mouse("aim", MOUSE_BUTTON_RIGHT)
	_bind_mouse("weapon_next", MOUSE_BUTTON_WHEEL_DOWN)
	_bind_mouse("weapon_prev", MOUSE_BUTTON_WHEEL_UP)


func _bind_key(action: String, key: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = key
	InputMap.action_add_event(action, ev)


func _bind_mouse(action: String, button: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)


# ---------------------------------------------------------------- fonts / theme
func _setup_font() -> void:
	var latin_path := "res://assets/fonts/NotoSans-Regular.ttf"
	var bengali_path := "res://assets/fonts/NotoSansBengali-Regular.ttf"
	var bengali: Font = null
	if ResourceLoader.exists(bengali_path):
		bengali = load(bengali_path)
	if ResourceLoader.exists(latin_path):
		var latin: FontFile = load(latin_path)
		var fb: Array[Font] = []
		if bengali != null:
			fb.append(bengali)
		latin.fallbacks = fb
		ui_font = latin
	elif bengali != null:
		ui_font = bengali
	else:
		var sf := SystemFont.new()
		sf.font_names = PackedStringArray(["Nirmala UI", "Vrinda", "Noto Sans Bengali", "Shonar Bangla", "Arial"])
		ui_font = sf
	ThemeDB.fallback_font = ui_font
	get_tree().root.theme = UIStyleScript.make_theme(ui_font)


# ---------------------------------------------------------------- audio buses
const BUSES := ["Music", "SFX", "Signals", "UI", "Ambience", "Voice"]


func _setup_audio_buses() -> void:
	for bus_name in BUSES:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx: int = AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")


# ---------------------------------------------------------------- character slots
const CUSTOM_PATH := "user://characters.cfg"
const ALLY_SLOTS := 6
const VILLAIN_SLOTS := 2
const ENEMY_SLOTS := 8
const HOSTAGE_SLOTS := 36
const PHOTO_ROLES := ["hero", "ally", "villain", "enemy", "boss"]
const DEFAULT_GENDER := {
	"ally": ["female", "male", "female", "male", "female", "male"],
	"villain": ["male", "female"],
	"enemy": ["male", "male", "female", "male", "male", "female", "male", "male"],
}
var custom := {}
var best_score := {}

# --- phase 6 settings ---------------------------------------------------------------
## Full coastal clothes (the GDD look), beachwear, or the anatomical body.
const CLOTHING_MODES := ["outfit", "swim", "bare"]
## An Alpha woman's silent takedown is lethal half the time; the other half the target
## becomes a gaggable, tappable, carryable captive for the tourist police.
const TAKEDOWN_HOSTAGE_CHANCE := 0.5


func get_clothing_mode() -> String:
	var s: Dictionary = custom.get("settings", {})
	var m := str(s.get("clothing_mode", "outfit"))
	return m if CLOTHING_MODES.has(m) else "outfit"


func set_clothing_mode(m: String) -> void:
	if not CLOTHING_MODES.has(m):
		return
	if not custom.has("settings"):
		custom["settings"] = {}
	(custom["settings"] as Dictionary)["clothing_mode"] = m
	save_custom()


## Roll the takedown outcome. Kept here so Mission, HostageOps and tests share one rule.
## Tactical rule: a captive may only be restrained, carried or reassured by a
## handler of the opposite gender. The Freelancer's gender comes from the
## customiser, so J calls the matching Alpha member when needed.
func can_handle(actor: Node, target: Node) -> bool:
	if target == null or actor == null:
		return false
	return is_female(actor) != is_female(target)


func can_hand_gag(actor: Node, target: Node) -> bool:
	if actor == null or target == null or not actor.is_in_group("allies"):
		return false
	return is_female(actor) and not is_female(target)


func handler_word(target: Node) -> String:
	return "নারী" if not is_female(target) else "পুরুষ"


func is_female(n: Node) -> bool:
	return n != null and bool(n.get("female"))


func hero_female() -> bool:
	return str(custom_for("hero").get("gender", "male")) == "female"


func load_custom() -> void:
	custom = {}
	var cf := ConfigFile.new()
	if cf.load(CUSTOM_PATH) != OK:
		return
	for r in cf.get_sections():
		var d := {}
		for k in cf.get_section_keys(r):
			d[k] = cf.get_value(r, k)
		custom[r] = d


func save_custom() -> void:
	var cf := ConfigFile.new()
	for r in custom.keys():
		var d: Dictionary = custom.get(r, {})
		for k in d.keys():
			cf.set_value(str(r), k, d[k])
	cf.save(CUSTOM_PATH)


func custom_for(role: String, slot: int = 0) -> Dictionary:
	var base: Dictionary = custom.get(role, {})
	if slot <= 0:
		return base
	var d := base.duplicate()
	d.merge(custom.get("%s_%d" % [role, slot], {}), true)
	return d


func slot_gender(role: String, slot: int) -> String:
	var own: Dictionary = custom.get("%s_%d" % [role, slot], {})
	if own.has("gender"):
		return str(own["gender"])
	var defs: Array = DEFAULT_GENDER.get(role, [])
	if defs.is_empty():
		return str(custom_for(role).get("gender", "male"))
	return str(defs[(slot - 1) % defs.size()])


func slot_count(role: String) -> int:
	match role:
		"ally":
			return ALLY_SLOTS
		"villain":
			return VILLAIN_SLOTS
		"enemy":
			return ENEMY_SLOTS
	return 1




# ---------------------------------------------------------------- settings
func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(SETTINGS_PATH) != OK:
		return
	for key in settings.keys():
		settings[key] = cf.get_value("settings", key, settings[key])


func save_settings() -> void:
	var cf := ConfigFile.new()
	for key in settings.keys():
		cf.set_value("settings", key, settings[key])
	cf.save(SETTINGS_PATH)


func apply_audio_settings() -> void:
	_set_bus_volume("Master", float(settings["master_volume"]))
	_set_bus_volume("Music", float(settings["music_volume"]))
	_set_bus_volume("SFX", float(settings["sfx_volume"]))
	_set_bus_volume("Signals", float(settings["signals_volume"]))
	_set_bus_volume("UI", float(settings["sfx_volume"]))
	_set_bus_volume("Ambience", 0.0)
	_set_bus_volume("Voice", 0.0)
	var am := get_node_or_null("/root/AudioManager")
	if am != null and am.has_method("reload_custom"):
		am.reload_custom()


func apply_settings() -> void:
	apply_audio_settings()
	if not OS.has_feature("editor") and DisplayServer.get_name() != "headless":
		var mode := DisplayServer.window_get_mode()
		if bool(settings["fullscreen"]):
			if mode != DisplayServer.WINDOW_MODE_FULLSCREEN:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		elif mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var q: int = quality()
	var vp := get_viewport()
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	vp.scaling_3d_scale = 0.75 if q == 0 else 1.0
	Engine.max_fps = 60
	settings_changed.emit()


func _set_bus_volume(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		var off := 0.0
		var am := get_node_or_null("/root/AudioManager")
		if am != null and am.has_method("bus_offset"):
			off = am.bus_offset(bus_name)
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)) + off)
		AudioServer.set_bus_mute(idx, linear <= 0.0001)


# ---------------------------------------------------------------- score and medkits
const START_MEDKITS := 2

## Noise-dampening tape tiers. A strip over a captive's mouth reduces how far
## their voice carries, so guards are less likely to hear them. Tier 7 selects
## the quietest tape available; the choice is a stealth-equipment decision only.
const TAPE_TYPES := [
	{"id": "gang", "bn": "চক্রের টেপ", "en": "Gang tape", "talk": 1.0, "muffle": 1.0, "color": Color(0.45, 0.45, 0.47)},
	{"id": "basic", "bn": "বেসিক টেপ", "en": "Basic", "talk": 0.85, "muffle": 0.75, "color": Color(0.62, 0.66, 0.7)},
	{"id": "standard", "bn": "স্ট্যান্ডার্ড টেপ", "en": "Standard", "talk": 0.7, "muffle": 0.5, "color": Color(0.35, 0.62, 0.95)},
	{"id": "advanced", "bn": "অ্যাডভান্সড টেপ", "en": "Advanced", "talk": 0.55, "muffle": 0.3, "color": Color(0.7, 0.45, 0.95)},
	{"id": "tactical", "bn": "ট্যাকটিক্যাল টেপ", "en": "Tactical", "talk": 0.4, "muffle": 0.12, "color": Color(1.0, 0.62, 0.2)},
]
const QUIET_RANGE := 2.0
var tape_type := 2


func tape_info(tape_id: int) -> Dictionary:
	return TAPE_TYPES[clampi(tape_id, 0, TAPE_TYPES.size() - 1)]


func tape_name(tape_id: int) -> String:
	return str(tape_info(tape_id)["bn"])


func set_tape_type(tape_id: int) -> void:
	tape_type = clampi(tape_id, 1, TAPE_TYPES.size() - 1)
	tape_changed.emit()


func cycle_tape() -> int:
	set_tape_type(tape_type % (TAPE_TYPES.size() - 1) + 1)
	return tape_type


func tape_for_noise(noise_level: float, muffle_base: float = 4.0) -> int:
	for tape_idx in range(1, TAPE_TYPES.size()):
		if muffle_base * noise_level * float(TAPE_TYPES[tape_idx]["muffle"]) <= QUIET_RANGE:
			return tape_idx
	return TAPE_TYPES.size() - 1

const SCORE := {"objective": 150, "leader": 500, "cache": 300, "stash": 150, "mission": 500}
var medkits := START_MEDKITS


func add_score(points: int, reason: String = "") -> void:
	stats["score"] = int(stats.get("score", 0)) + points
	score_changed.emit()
	if reason != "" and level != null and level.get("hud") != null:
		level.hud.notify("%s  (+%s পয়েন্ট)" % [reason, bn(points)], Color(0.6, 1.0, 0.6))


func score() -> int:
	return int(stats.get("score", 0))


func set_medkits(n: int) -> void:
	medkits = maxi(n, 0)
	score_changed.emit()


# ---------------------------------------------------------------- colony economy
## Money and tradeable loot carried between missions. Sold to colony shopkeepers.
const ECONOMY_PATH := "user://economy.cfg"
var money: int = 500
var loot_ammo: int = 0
var loot_guns: int = 0
var health_bonus: int = 0
var medicine_used: int = 0


func load_economy() -> void:
	var cf := ConfigFile.new()
	if cf.load(ECONOMY_PATH) == OK:
		money = maxi(int(cf.get_value("economy", "money", 500)), 0)
		loot_ammo = maxi(int(cf.get_value("economy", "loot_ammo", 0)), 0)
		loot_guns = maxi(int(cf.get_value("economy", "loot_guns", 0)), 0)
		health_bonus = clampi(int(cf.get_value("economy", "health_bonus", 0)), 0, 75)
		medicine_used = maxi(int(cf.get_value("economy", "medicine_used", 0)), 0)


func save_economy() -> void:
	var cf := ConfigFile.new()
	cf.set_value("economy", "money", money)
	cf.set_value("economy", "loot_ammo", loot_ammo)
	cf.set_value("economy", "loot_guns", loot_guns)
	cf.set_value("economy", "health_bonus", health_bonus)
	cf.set_value("economy", "medicine_used", medicine_used)
	cf.save(ECONOMY_PATH)


func add_money(amount: int, reason: String = "") -> void:
	money = maxi(money + amount, 0)
	save_economy()
	score_changed.emit()
	if reason != "" and level != null and level.get("hud") != null:
		level.hud.notify("%s  (+%s ৳)" % [reason, bn(amount)], Color(1.0, 0.85, 0.4))


func add_loot(ammo: int, guns: int) -> void:
	loot_ammo = maxi(loot_ammo + ammo, 0)
	loot_guns = maxi(loot_guns + guns, 0)
	save_economy()


func buy_health_upgrade(cost: int) -> bool:
	if money < cost or health_bonus >= 75:
		return false
	money -= cost
	health_bonus = mini(health_bonus + 25, 75)
	save_economy()
	if player != null and player.has_method("apply_health_bonus"):
		player.call("apply_health_bonus")
	return true


# ---------------------------------------------------------------- progress
func load_progress() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) == OK:
		unlocked = clampi(int(cf.get_value("progress", "unlocked", 1)), 1, MISSION_COUNT)
		best_score = cf.get_value("progress", "best_score", {})


func save_progress() -> void:
	var cf := ConfigFile.new()
	cf.set_value("progress", "unlocked", unlocked)
	cf.set_value("progress", "best_score", best_score)
	cf.save(SAVE_PATH)


# ---------------------------------------------------------------- IGI campaign save
const IGI_SAVE_PATH := "user://igi_campaign.cfg"
var mission_records := {}          # mission index -> {score, time, objectives, alarms, medal, rank}
var campaign_rank := "Recruit"
var checkpoint := {}               # mid-mission resume data
const RANKS := ["Recruit", "Agent", "Specialist", "Elite", "Master Agent"]


func load_igi_save() -> void:
	var cf := ConfigFile.new()
	if cf.load(IGI_SAVE_PATH) != OK:
		return
	mission_records = cf.get_value("campaign", "records", {})
	campaign_rank = str(cf.get_value("campaign", "rank", "Recruit"))
	checkpoint = cf.get_value("campaign", "checkpoint", {})
	unlocked = clampi(maxi(unlocked, int(cf.get_value("campaign", "unlocked", 1))), 1, MISSION_COUNT)


func save_igi_save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("campaign", "records", mission_records)
	cf.set_value("campaign", "rank", campaign_rank)
	cf.set_value("campaign", "checkpoint", checkpoint)
	cf.set_value("campaign", "unlocked", unlocked)
	cf.save(IGI_SAVE_PATH)


func has_checkpoint() -> bool:
	return not checkpoint.is_empty() and int(checkpoint.get("mission", 0)) > 0


func save_checkpoint(mission: int, obj: int, progress: Dictionary, pos: Vector3,
		time: float, score: int) -> void:
	checkpoint = {"mission": mission, "obj": obj, "progress": progress,
		"pos": [pos.x, pos.y, pos.z], "time": time, "score": score}
	save_igi_save()


func clear_checkpoint() -> void:
	checkpoint = {}
	save_igi_save()


func resume_checkpoint() -> void:
	if not has_checkpoint():
		return
	start_mission(int(checkpoint["mission"]))


func rank_for_score(total: int) -> String:
	var thresholds := [0, 1500, 4000, 8000, 14000]
	var r := 0
	for i in thresholds.size():
		if total >= int(thresholds[i]):
			r = i
	return RANKS[mini(r, RANKS.size() - 1)]


func total_campaign_score() -> int:
	var total := 0
	for k in mission_records.keys():
		total += int((mission_records[k] as Dictionary).get("score", 0))
	return total


func record_mission_result(mission: int, obj_done: int, obj_total: int, alarms: int, time: float) -> void:
	var sc := score()
	var medal := "Gold"
	if alarms > 0 or time > 420.0 or obj_done < obj_total:
		medal = "Bronze"
	elif time > 240.0 or alarms > 0:
		medal = "Silver"
	mission_records[mission] = {"score": sc, "time": time, "objectives": "%d/%d" % [obj_done, obj_total],
		"alarms": alarms, "medal": medal, "rank": campaign_rank}
	campaign_rank = rank_for_score(total_campaign_score())
	if mission >= unlocked and mission < MISSION_COUNT:
		unlocked = mission + 1
	clear_checkpoint()
	save_igi_save()
	save_progress()
