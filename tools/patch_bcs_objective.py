import os
p = os.path.join(os.path.dirname(__file__), '..', 'scripts', 'autoload', 'Game.gd')
s = open(p, encoding='utf-8').read()
line = '\t\t\t{"type": "bcs_gate", "text": "BCS প্রশ্নের উত্তর দিয়ে গেট খুলুন", "label": "[E] গেট খুলুন", "count": 1},\n'
lines = s.split('\n')
out, n = [], 0
for l in lines:
    if '"type": "extract"' in l and n < 5:
        out.append(line.rstrip('\n'))
        n += 1
    out.append(l)
open(p, 'w', encoding='utf-8').write('\n'.join(out))
print('added BCS gate objective to', n, 'missions')
