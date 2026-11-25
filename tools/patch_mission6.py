import os
p = os.path.join(os.path.dirname(__file__), '..', 'scripts', 'autoload', 'Game.gd')
s = open(p, encoding='utf-8').read()
s = s.replace('const MISSION_COUNT := 5', 'const MISSION_COUNT := 6')
lines = s.split('\n')
start = next(i for i, l in enumerate(lines) if l.startswith('const MISSIONS := ['))
end = next(i for i, l in enumerate(lines[start:], start) if l == ']')
new = [
'\t{',
'\t\t"title": "ছাদের যুদ্ধ", "title_en": "Rooftop War",',
'\t\t"place": "কাজলা — বহুতল ভবন", "time": "night", "stealth": true,',
'\t\t"zone": "rooftops", "subtitle": "Vertical assault", "reward": 1800,',
'\t\t"parachute": true, "alarm_limit": 180.0,',
'\t\t"brief": "প্যারাস্যুট থেকে নেমে বহুতল বাড়ির ছাদ দখল করুন। ভেতরের ঘর, উপরের তলা আর ছাদে পাহারাদার আছে। ছাদ থেকে লক্ষ্য চিহ্নিত করে, কমান্ডারকে বাদ দিয়ে, চার্জ লাগিয়ে এবং নথি সংগ্রহ করে বের হন।",',
'\t\t"objectives": [',
'\t\t\t{"type": "infiltrate", "text": "প্রথম বাড়ির ভেতরে প্রবেশ করুন", "pos_y": 4, "radius": 7.0},',
'\t\t\t{"type": "reach", "text": "উপরের তলায় উঠুন", "pos_y": 5, "radius": 7.0},',
'\t\t\t{"type": "reach", "text": "ছাদে পৌঁছান", "pos_y": 6, "radius": 8.0},',
'\t\t\t{"type": "photo", "text": "ছাদ থেকে দুটি লক্ষ্য চিহ্নিত করুন", "label": "[E] ছবি তুলুন", "count": 2},',
'\t\t\t{"type": "eliminate", "text": "দুই কমান্ডারকে বাদ দিন", "tag": "commander", "count": 2},',
'\t\t\t{"type": "sabotage", "text": "দুটি লক্ষ্যে চার্জ লাগান", "label": "[E] চার্জ লাগান", "count": 2},',
'\t\t\t{"type": "bcs_gate", "text": "BCS প্রশ্নের উত্তর দিয়ে গেট খুলুন", "label": "[E] গেট খুলুন", "count": 1},',
'\t\t\t{"type": "collect", "text": "দুটি নথি সংগ্রহ করুন", "label": "[E] নথি নিন", "count": 2},',
'\t\t\t{"type": "survive", "text": "ছাদে ২৫ সেকেন্ড অবস্থান ধরে থাকুন", "time": 25.0, "pos_y": 6, "radius": 12.0},',
'\t\t\t{"type": "extract", "text": "এক্সট্রাকশন পয়েন্টে ফিরে আসুন", "pos_y": 1, "radius": 8.0},',
'\t\t],',
'\t},',
]
lines[end:end] = new
open(p, 'w', encoding='utf-8').write('\n'.join(lines))
print('mission 6 added')
