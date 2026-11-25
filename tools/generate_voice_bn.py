"""Generate real Bengali voice clips for IGI: Sontek Kajla announcements.

Uses gTTS (Google TTS) to write assets/voice/<md5-16>.mp3, the same key scheme
as the proven TauntONomics Speech.gd mechanism.  MP3s are loaded as raw bytes
at runtime, so no Godot import step is needed.
"""
import hashlib, os
from gtts import gTTS

OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'voice')
os.makedirs(OUT, exist_ok=True)

LINES = [
	# control-room PA announcements
	"অপারেশন সনটেক কাজলা শুরু। অপারেটিভ, কাজলা এলাকায় প্রবেশ করুন। শত্রুদের চোখ এড়িয়ে চলুন।",
	"লক্ষ্য সম্পন্ন। পরবর্তী নির্দেশের জন্য অপেক্ষা করুন। সাবধানে এগোন।",
	"সতর্ক! নিরাপত্তা ব্যবস্থা সক্রিয় হয়েছে। অবিলম্বে এলাকা ত্যাগ করুন।",
	"ভেতরের ঘরে পাহারাদার আছে। থার্মাল ভিশন ব্যবহার করে সাবধানে এগোন।",
	"যানবাহন প্রবেশযোগ্য। দ্রুত পলায়নের জন্য ব্যবহার করুন।",
	"এক্সট্রাকশন পয়েন্ট প্রস্তুত। নির্ধারিত স্থানে ফিরে আসুন।",
	"মিশন সফল। অপারেটিভ, আপনি এখন নিরাপদ।",
	"গেট খুলতে নিচের প্রশ্নের সঠিক উত্তর দিন।",
	# extra field lines
	"কাজলা বাস স্টপ এলাকায় প্রবেশ করুন।",
	"তিনটি লক্ষ্যের ছবি তুলুন।",
	"দুটি নথির গুচ্ছ সংগ্রহ করুন।",
	"চিহ্নিত কমান্ডারকে বাদ দিন।",
	"দুটি লক্ষ্যে চার্জ লাগান।",
	"অ্যালার্ম সিস্টেম অক্ষম করুন।",
	"ভেতরের ঘরে প্রবেশ করুন।",
	"অবস্থান ধরে পঁচিশ সেকেন্ড টিকে থাকুন।",
	"নির্দিষ্ট যানবাহন চিহ্নিত করুন।",
	"শত্রুদের অস্ত্রের গুদাম ধ্বংস করুন।",
	"মিশন ব্যর্থ। দ্রুত পুনরায় চেষ্টা করুন।",
	"চেকপয়েন্ট সংরক্ষিত হয়েছে।",
	"থার্মাল ভিশন চালু আছে। দেয়ালের ওপারের শত্রু দেখতে পাবেন।",
	"পোস্টার: এস এম নাজমুজ সাকিব। কাজলা অপারেশনের লক্ষ্য।",
]

for text in LINES:
    key = hashlib.md5(text.encode('utf-8')).hexdigest()[:16]
    path = os.path.join(OUT, key + '.mp3')
    if os.path.exists(path) and os.path.getsize(path) > 256:
        continue
    try:
        gTTS(text=text, lang='bn').save(path)
        print(key, text[:40])
    except Exception as e:
        print('FAILED', key, e)

with open(os.path.join(OUT, 'voice_lines_map.txt'), 'w', encoding='utf-8') as f:
    f.write('key,text\n')
    for text in LINES:
        f.write('%s,%s\n' % (hashlib.md5(text.encode('utf-8')).hexdigest()[:16], text))
print('voice bank ready:', len(LINES), 'lines')
