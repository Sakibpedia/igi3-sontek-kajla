import os
p = os.path.join(os.path.dirname(__file__), '..', 'scripts', 'autoload', 'Game.gd')
s = open(p, encoding='utf-8').read()
zones = ['north', 'south', 'park', 'highway', 'full']
for i, z in enumerate(zones, 1):
    marker = '"subtitle":'
    idx = s.index('const MISSIONS := [')
    # find the i-th mission block start
    pos = idx
    for _ in range(i - 1):
        pos = s.index('\n\t{', pos + 1)
    mi = s.index(marker, pos)
    s = s[:mi] + '"zone": "%s", ' % z + s[mi:]
open(p, 'w', encoding='utf-8').write(s)
print('zones added')
