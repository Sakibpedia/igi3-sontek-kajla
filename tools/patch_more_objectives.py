import os
p = os.path.join(os.path.dirname(__file__), '..', 'scripts', 'autoload', 'Game.gd')
s = open(p, encoding='utf-8').read()
extra = ('\t\t\t{"type": "infiltrate", "text": "ভেতরের ঘরে প্রবেশ করুন", "pos_y": 4, "radius": 7.0},\n'
         '\t\t\t{"type": "survive", "text": "অবস্থান ধরে ২৫ সেকেন্ড টিকে থাকুন", "time": 25.0, "pos_y": 4, "radius": 12.0},\n')
lines = s.split('\n')
out = []
count = 0
for l in lines:
    if '"type": "extract"' in l and count < 5:
        out.append(extra.rstrip('\n').split('\n')[0])
        out.append(extra.rstrip('\n').split('\n')[1])
        count += 1
    out.append(l)
s = '\n'.join(out)
open(p, 'w', encoding='utf-8').write(s)
print('inserted extra objectives before', count, 'extract steps')
