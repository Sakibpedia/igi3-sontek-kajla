"""Assemble a signed Android APK from Godot's official 4.3 release template + PCK.

Used as a fallback when the Android export preset reports configuration errors:
the template contains the Godot engine natives; the PCK contains the game.
"""
import os, shutil, zipfile

ROOT = os.path.join(os.path.dirname(__file__), '..')
TPL = r'C:\Users\sakib\AppData\Roaming\Godot\export_templates\4.3.stable\android_release.apk'
PCK = os.path.join(ROOT, 'build', 'game.pck')
OUT = os.path.join(ROOT, 'build', 'IGI_SontekKajla_unsigned.apk')

if os.path.exists(OUT):
    os.remove(OUT)
with zipfile.ZipFile(TPL, 'r') as zin, zipfile.ZipFile(OUT, 'w', zipfile.ZIP_DEFLATED) as zout:
    for item in zin.infolist():
        if item.filename.startswith('META-INF/') and item.filename.endswith(('.RSA', '.SF', '.MF')):
            continue
        data = zin.read(item.filename)
        zout.writestr(item, data)
    zout.write(PCK, 'assets/main.pck')
print('assembled', OUT, os.path.getsize(OUT), 'bytes')
