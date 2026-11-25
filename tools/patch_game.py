import io, os
p = os.path.join(os.path.dirname(__file__), '..', 'scripts', 'autoload', 'Game.gd')
s = open(p, encoding='utf-8').read()
lines = s.split('\n')
# replace MISSIONS block (lines are 1-based in editor)
start = next(i for i,l in enumerate(lines) if l.startswith('const MISSIONS := ['))
end = next(i for i,l in enumerate(lines[start:], start) if l == ']') + 1
new = '''const MISSIONS := [
	{
		"title": "কাজলা reconnaissance", "title_en": "Kajla Recon",
		"place": "কাজলা, ঢাকা", "time": "night", "stealth": true,
		"subtitle": "Photograph three targets", "reward": 400,
		"brief": "কাজলা এলাকায় তিনটি গোপন স্থাপনা চিহ্নিত করুন। প্রতিটির সামনে দাঁড়িয়ে E চাপে ছবি তুলুন, তারপর প্রধান রাস্তায় অপেক্ষা করা এক্সট্রাকশন পয়েন্টে ফিরে আসুন। পাহারাদারদের চোখ এড়িয়ে চলুন।",
		"objectives": [
			{"type": "reach", "text": "কাজলা বাস স্টপ এলাকায় প্রবেশ করুন", "pos_y": 0, "radius": 14.0, "say": ["HQ", "কাজলায় নামলেন। প্রথমে রাস্তার পাশের এলাকায় অবস্থান নিন।"]},
			{"type": "photo", "text": "তিনটি লক্ষ্যের ছবি তুলুন", "label": "[E] ছবি তুলুন", "count": 3},
			{"type": "extract", "text": "এক্সট্রাকশন পয়েন্টে ফিরে আসুন", "pos_y": 1, "radius": 8.0, "say": ["HQ", "কাজ শেষ। এখন প্রধান রাস্তার এক্সট্রাকশন পয়েন্টে যান।"]},
		],
	},
	{
		"title": "নথি উদ্ধার", "title_en": "Document Run",
		"place": "কাজলা, ঢাকা", "time": "night", "stealth": true,
		"subtitle": "Collect two document caches", "reward": 550,
		"brief": "দুটি ভবনে গোপন নথি রাখা আছে। ভিতরে ঢুকে E চাপে নথি সংগ্রহ করুন। অ্যালার্ম বাঙলে শত্রু দল আসবে — সতর্কতা অবলম্বন করুন।",
		"objectives": [
			{"type": "collect", "text": "দুটি নথির গুচ্ছ সংগ্রহ করুন", "label": "[E] নথি নিন", "count": 2},
			{"type": "extract", "text": "এক্সট্রাকশন পয়েন্টে ফিরে আসুন", "pos_y": 1, "radius": 8.0},
		],
	},
	{
		"title": "সাবোতাজ", "title_en": "Sabotage",
		"place": "কাজলা, ঢাকা", "time": "night", "stealth": true,
		"subtitle": "Plant two charges and escape", "reward": 800, "alarm_limit": 95.0,
		"brief": "দুটি লক্ষ্যে বিস্ফোরক লাগান। একবার অ্যালার্ম বাজলে ৯৫ সেকেন্ডের মধ্যে বের হতে হবে — নাহলে শত্রু বাহিনী এসে আপনাকে আটক করবে।",
		"objectives": [
			{"type": "sabotage", "text": "দুটি লক্ষ্যে চার্জ লাগান", "label": "[E] চার্জ লাগান", "count": 2},
			{"type": "extract", "text": "এক্সট্রাকশন পয়েন্টে ফিরে আসুন", "pos_y": 1, "radius": 8.0},
		],
	},
]'''
lines[start:end] = new.split('\n')
s = '\n'.join(lines)
s = s.replace('const MISSION_COUNT := 11', 'const MISSION_COUNT := 3')
s = s.replace('return "res://scenes/levels/Level_%02d.tscn" % idx', 'return "res://scenes/missions/M%02d.tscn" % idx')
s = s.replace('config/name="Silent Rescue: Dhaka"', 'config/name="IGI: Sontek Kajla"') if False else s
open(p, 'w', encoding='utf-8').write(s)
print('patched Game.gd')
