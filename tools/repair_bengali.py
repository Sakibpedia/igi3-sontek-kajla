"""Repair text that was saved as UTF-8 bytes decoded through Windows-1252.
Moji-bake like 'à¦Ÿà¦¿à¦ªà¦¸' -> 'টিপস'.  Only for the two UI files that were
rewritten with the wrong PowerShell encoding.
"""
import os

rev = {}
for b in range(256):
    try:
        ch = bytes([b]).decode('cp1252')
    except Exception:
        ch = '?'
    rev[ch] = b


def repair(path):
    s = open(path, encoding='utf-8').read()
    out = bytearray()
    for ch in s:
        if ch in rev:
            out.append(rev[ch])
        elif ord(ch) < 256:
            out.append(ord(ch))
        else:
            out.append(ord('?'))
    fixed = bytes(out).decode('utf-8', errors='replace')
    open(path, 'w', encoding='utf-8', newline='').write(fixed)
    bad = fixed.count('à¦')
    print(os.path.basename(path), 'remaining mojibake markers:', bad)
    i = fixed.find('var tips :=')
    if i >= 0:
        print('  tips preview:', ascii(fixed[i:i + 120]))


root = os.path.join(os.path.dirname(__file__), '..', 'scripts', 'ui')
repair(os.path.join(root, 'HUD.gd'))
repair(os.path.join(root, 'SontekMenu.gd'))
