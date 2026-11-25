import os
p = os.path.join(os.path.dirname(__file__), '..', 'export_presets.cfg')
s = open(p, encoding='utf-8').read()
head = s[:s.index('[preset.1]')]
tail = '''[preset.1]

name="Android"
platform="Android"
runnable=true
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter=""
exclude_filter=""
export_path="G:/IGI_Sontek_Kajla/build/IGI_SontekKajla_unsigned.apk"
patches=PackedStringArray()
encryption_include_filters=""
encryption_exclude_filters=""
seed=0
encrypt_pck=false
encrypt_directory=false
script_export_mode=2

[preset.1.options]

custom_template/debug=""
custom_template/release=""
package/unique_name="com.sakib.igisontekkajla"
'''
open(p, 'w', encoding='utf-8').write(head + tail)
print('preset simplified')
