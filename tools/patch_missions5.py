import os
p = os.path.join(os.path.dirname(__file__), '..', 'scripts', 'autoload', 'Game.gd')
s = open(p, encoding='utf-8').read()
lines = s.split('\n')
start = next(i for i, l in enumerate(lines) if l.startswith('const MISSIONS := ['))
end = next(i for i, l in enumerate(lines[start:], start) if l == ']') + 1
new = '''const MISSIONS := [
	{
		"title": "কাজলা reconnaissance", "title_en": "Kajla Recon",
		"place": "কাজলা, ঢাকা", "time": "night", "stealth": true,
		"subtitle": "Photograph + observe", "reward": 400,
		"brief": "কাজলা বাস স্টপ এলাকায় প্রবেশ করুন, তিনটি লক্ষ্যের ছবি তুলুন, একটি নথি সংগ্রহ করুন এবং কাজলা পার্ক থেকে পর্যবেক্ষণ শেষ করে এক্সট্রাকশন পয়েন্টে ফিরে আসুন।",
		"objectives": [
			{"type": "reach", "text": "কাজলা বাস স্টপ এলাকায় প্রবেশ করুন", "pos_y": 3, "radius": 20.0},
			{"type": "photo", "text": "তিনটি লক্ষ্যের ছবি তুলুন", "label": "[E] ছবি তুলুন", "count": 3},
			{"type": "collect", "text": "একটি গোপন নথি সংগ্রহ করুন", "label": "[E] নথি নিন", "count": 1},
			{"type": "reach", "text": "কাজলা পার্ক থেকে পর্যবেক্ষণ করুন", "pos_y": 2, "radius": 14.0},
			{"type": "extract", "text": "এক্সট্রাকশন পয়েন্টে ফিরে আসুন", "pos_y": 1, "radius": 8.0},
		],
	},
	{
		"title": "নথি উদ্ধার", "title_en": "Document Run",
		"place": "কাজলা, ঢাকা", "time": "night", "stealth": true,
		"subtitle": "Wiretap + documents", "reward": 550,
		"brief": "একটি ফোনে ওয়্যারট্যাপ লাগান, দুটি নথির গুচ্ছ সংগ্রহ করুন এবং আরেকটি লক্ষ্যের ছবি তুলুন। পাহারাদাররা দেখে ফেললে অ্যালার্ম বাজবে।",
		"objectives": [
			{"type": "wiretap", "text": "ফোনে ওয়্যারট্যাপ লাগান", "label": "[E] ওয়্যারট্যাপ", "count": 1},
			{"type": "collect", "text": "দুটি নথির গুচ্ছ সংগ্রহ করুন", "label": "[E] নথি নিন", "count": 2},
			{"type": "photo", "text": "অতিরিক্ত একটি লক্ষ্যের ছবি তুলুন", "label": "[E] ছবি তুলুন", "count": 1},
			{"type": "extract", "text": "এক্সট্রাকশন পয়েন্টে ফিরে আসুন", "pos_y": 1, "radius": 8.0},
		],
	},
	{
		"title": "পার্কে নজরদারি", "title_en": "Park Stakeout",
		"place": "কাজলা পার্ক, ঢাকা", "time": "night", "stealth": true,
		"subtitle": "Stake out + eliminate", "reward": 700,
		"brief": "কাজলা পার্কে অবস্থান নিন। দুটি লক্ষ্যের ছবি তুলুন, চিহ্নিত কমান্ডারকে বাদ দিন, একটি নথি নিন এবং বের হন। ভেতরের ঘরেও পাহারাদার আছে — সাবধান।",
		"objectives": [
			{"type": "reach", "text": "কাজলা পার্কে অবস্থান নিন", "pos_y": 2, "radius": 16.0},
			{"type": "photo", "text": "দুটি লক্ষ্যের ছবি তুলুন", "label": "[E] ছবি তুলুন", "count": 2},
			{"type": "eliminate", "text": "চিহ্নিত কমান্ডারকে বাদ দিন", "tag": "commander", "count": 1},
			{"type": "collect", "text": "কমান্ডারের কাছ থেকে নথি নিন", "label": "[E] নথি নিন", "count": 1},
			{"type": "extract", "text": "এক্সট্রাকশন পয়েন্টে ফিরে আসুন", "pos_y": 1, "radius": 8.0},
		],
	},
	{
		"title": "R110 সাবোতাজ", "title_en": "R110 Sabotage",
		"place": "কাজলা — R110 হাইওয়ে", "time": "night", "stealth": true,
		"subtitle": "Charges + alarm", "reward": 900, "alarm_limit": 120.0,
		"brief": "দুটি যানবাহনে বিস্ফোরক লাগান, অ্যালার্ম সিস্টেম অক্ষম করুন এবং একটি নথি সংগ্রহ করুন। অ্যালার্ম বাজলে ১২০ সেকেন্ডের মধ্যে পালাতে হবে। গাড়ি চালিয়ে দ্রুত বের হতে পারেন।",
		"objectives": [
			{"type": "sabotage", "text": "দুটি যানবাহনে চার্জ লাগান", "label": "[E] চার্জ লাগান", "count": 2},
			{"type": "disable_alarm", "text": "অ্যালার্ম সিস্টেম অক্ষম করুন", "label": "[E] অ্যালার্ম বন্ধ করুন", "count": 1},
			{"type": "collect", "text": "একটি নথি সংগ্রহ করুন", "label": "[E] নথি নিন", "count": 1},
			{"type": "extract", "text": "এক্সট্রাকশন পয়েন্টে ফিরে আসুন", "pos_y": 1, "radius": 8.0},
		],
	},
	{
		"title": "চূড়ান্ত অভিযান", "title_en": "Final Sweep",
		"place": "কাজলা — পুরো এলাকা", "time": "night", "stealth": true,
		"subtitle": "Full operational sweep", "reward": 1400, "alarm_limit": 150.0,
		"brief": "দুই কমান্ডারকে বাদ দিন, দুটি লক্ষ্যে চার্জ লাগান, একটি ওয়্যারট্যাপ লাগান এবং দুটি নথি সংগ্রহ করুন — সব শেষে বের হন। এটি সবচেয়ে কঠিন মিশন; থার্মাল ভিশন (T) ও গাড়ি কাজে লাগান।",
		"objectives": [
			{"type": "eliminate", "text": "দুই কমান্ডারকে বাদ দিন", "tag": "commander", "count": 2},
			{"type": "sabotage", "text": "দুটি লক্ষ্যে চার্জ লাগান", "label": "[E] চার্জ লাগান", "count": 2},
			{"type": "wiretap", "text": "ওয়্যারট্যাপ লাগান", "label": "[E] ওয়্যারট্যাপ", "count": 1},
			{"type": "collect", "text": "দুটি নথি সংগ্রহ করুন", "label": "[E] নথি নিন", "count": 2},
			{"type": "extract", "text": "এক্সট্রাকশন পয়েন্টে ফিরে আসুন", "pos_y": 1, "radius": 8.0},
		],
	},
]'''
lines[start:end] = new.split('\n')
s = '\n'.join(lines).replace('const MISSION_COUNT := 3', 'const MISSION_COUNT := 5')
open(p, 'w', encoding='utf-8').write(s)
print('patched to 5 missions')
