import os
p = os.path.join(os.path.dirname(__file__), '..', 'scripts', 'ui', 'HUD.gd')
s = open(p, encoding='utf-8').read().split('\n')
print('lines', len(s))
for i, l in enumerate(s):
    if '?' in l:
        print(i + 1, ascii(l[:120].replace('\t', ' ')))
