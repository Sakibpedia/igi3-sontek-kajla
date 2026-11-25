import os, re
p = os.path.join(os.path.dirname(__file__), '..', 'scripts', 'autoload', 'Game.gd')
s = open(p, encoding='utf-8').read()

s = s.replace("## Silent Rescue: Cox's Bazar - there is no money, no shop. Rewards (hostages rescued,\n## arrested gang members,...) are score only.",
              "## IGI: Sontek Kajla - mission-based stealth infiltration. Rewards are score only.")

# replace the long controls / faces hint strings
lines = s.split('\n')
for i, l in enumerate(lines):
    if '"controls":' in l:
        lines[i] = '\t"controls": "WASD চলাচল • Shift দৌড় • Ctrl শুয়ে পড়া • C/Q উঁকি • বাম ক্লিক গুলি • ডান ক্লিক নিশানা • ১/২/৩ অস্ত্র • R রিলোড • E ইন্টারঅ্যাক্ট / ছবি / নথি / চার্জ • ৪ গ্রেনেড • ৫ মলোটভ • ৬ টাইম বোমা • T থার্মাল • N হেডফোন • Tab লক্ষ্য • M মানচিত্র • Esc বিরতি",'
    if '"faces_hint":' in l:
        lines[i] = '\t"faces_hint": "চরিত্র সাজানোর ব্যবস্থা এই সংস্করণে বাদ দেওয়া হয়েছে।",'
s = '\n'.join(lines)

s = s.replace('const PHOTO_ROLES := ["hero", "ally", "villain", "enemy", "boss", "hostage"]',
              'const PHOTO_ROLES := ["hero", "ally", "villain", "enemy", "boss"]')
s = s.replace('\tconst HOSTAGE_SLOTS := 36\n', '')
s = s.replace('const SCORE := {"hostage": 100, "visitor": 120, "police": 250, "takedown": 80, "leader": 500, "cache": 300, "stash": 150, "arrest": 150, "defuse": 200, "virus": 150}',
              'const SCORE := {"objective": 150, "leader": 500, "cache": 300, "stash": 150, "mission": 500}')
s = re.sub(r'static func takedown_becomes_hostage\(\) -> bool:\n(?:.*\n)*?\n\n', '', s, count=1)
s = re.sub(r'func hostage_slot\(index: int\) -> int:\n.*\n', '', s, count=1)
s = s.replace('\tif role == "hostage":\n\t\tvar shared := str(custom_for("hostage").get("gender", "mixed"))\n', '')
s = s.replace('\t\t"hostage":\n', '')
open(p, 'w', encoding='utf-8').write(s)
print('cleaned Game.gd')
