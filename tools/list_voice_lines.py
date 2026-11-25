"""Lists every fixed Bengali line in the game with the file name a recording must have.

Run from the project folder:  python tools/list_voice_lines.py
Writes tools/voice/voice_lines.csv (a .gdignore folder, so Godot does not import it as a translation): key, file, speaker hint, text, where. Record each line as <key>.ogg (or
<key>_f.ogg / <key>_m.ogg for a woman's / man's take) and put the files in a "voice_bn" folder next
to SilentRescueDhaka.exe (no rebuild) or in assets/audio/voice_bn (rebuild). The game plays the
recording instead of text-to-speech. key = "line_" + first 10 hex digits of MD5(UTF-8 text), the same
as AudioManager.voice_key(). Lines with %s / %d placeholders are filled in at run time and stay on TTS.
"""
import csv, hashlib, os, re

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
BENGALI = re.compile(r"[ঀ-৿]")
LIT = re.compile(r'"((?:[^"\\]|\\.)*)"')
VOICE_CALLS = ("say(", "_voice(", "_say_confirm", "shout(", "CHATTER", "_CONFIRM", "NAMES")


def main():
    rows, seen = [], set()
    for d, _, files in os.walk(os.path.join(ROOT, "scripts")):
        for f in sorted(files):
            if not f.endswith(".gd"):
                continue
            path = os.path.join(d, f)
            rel = os.path.relpath(path, ROOT)
            for n, line in enumerate(open(path, encoding="utf-8"), 1):
                if not any(c in line for c in VOICE_CALLS) and not line.strip().startswith('"'):
                    continue
                for m in LIT.finditer(line):
                    text = m.group(1).encode().decode("unicode_escape").encode("latin-1").decode("utf-8") if "\\" in m.group(1) else m.group(1)
                    if not BENGALI.search(text) or text in seen:
                        continue
                    seen.add(text)
                    dynamic = "%" in text
                    key = "line_" + hashlib.md5(text.encode("utf-8")).hexdigest()[:10]
                    rows.append([key, "" if dynamic else key + ".ogg", "TTS only (filled in at run time)" if dynamic else "", text, "%s:%d" % (rel, n)])
    out = os.path.join(ROOT, "tools", "voice", "voice_lines.csv")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w", newline="", encoding="utf-8-sig") as fh:
        w = csv.writer(fh)
        w.writerow(["key", "file", "note", "text", "where"])
        w.writerows(rows)
    print("%d lines -> %s" % (len(rows), out))


if __name__ == "__main__":
    main()
