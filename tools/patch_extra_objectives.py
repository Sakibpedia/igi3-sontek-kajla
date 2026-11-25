import os
p = os.path.join(os.path.dirname(__file__), '..', 'scripts', 'autoload', 'Game.gd')
s = open(p, encoding='utf-8').read()
extra = ('\t\t\t{"type": "photo", "text": "নির্দিষ্ট যানবাহন চিহ্নিত করুন", "label": "[E] যানবাহন চিহ্নিত", "count": 1},\n'
         '\t\t\t{"type": "sabotage", "text": "শত্রুদের অস্ত্রের গুদাম ধ্বংস করুন", "label": "[E] চার্জ লাগান", "count": 1},\n')
lines = s.split('\n')
out, added = [], 0
for l in lines:
    if '"type": "extract"' in l and added < 5:
        out.extend(extra.rstrip('\n').split('\n'))
        added += 1
    out.append(l)
open(p, 'w', encoding='utf-8').write('\n'.join(out))
print('added', added, 'extra objectives')
