import subprocess, os
exe = r'G:\Softwares\Godot_v4.3-stable_win64.exe\Godot_v4.3-stable_win64_console.exe'
cmd = [exe, '--headless', '--path', r'G:\IGI_Sontek_Kajla', '--export-release', 'Android',
       r'G:\IGI_Sontek_Kajla\build\IGI_SontekKajla_unsigned.apk']
env = os.environ.copy()
env['JAVA_HOME'] = r'C:\Users\sakib\AppData\Local\Temp\opencode\android\jdk\jdk-17.0.21.1+2'
env['ANDROID_HOME'] = r'C:\Users\sakib\AppData\Local\Android\Sdk'
env['ANDROID_SDK_ROOT'] = env['ANDROID_HOME']
p = subprocess.run(cmd, capture_output=True, text=True, env=env)
print('EXIT', p.returncode)
print('--- STDOUT ---')
print(p.stdout)
print('--- STDERR ---')
print(p.stderr)
