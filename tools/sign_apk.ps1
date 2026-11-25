$ErrorActionPreference = 'Stop'
$base='C:\Users\sakib\AppData\Local\Temp\opencode\android'
$jdk=(Get-ChildItem "$base\jdk" -Directory | Select-Object -First 1).FullName
$sdk='C:\Users\sakib\AppData\Local\Android\Sdk'
$env:JAVA_HOME=$jdk
$env:PATH="$jdk\bin;$sdk\build-tools\34.0.0;$env:PATH"
$dir='G:\IGI_Sontek_Kajla\build'
$unsigned=Join-Path $dir 'IGI_SontekKajla_unsigned.apk'
$aligned=Join-Path $dir 'IGI_SontekKajla_aligned.apk'
$signed=Join-Path $dir 'IGI_SontekKajla_signed.apk'
$ks=Join-Path $dir 'igi_release.keystore'
if(-not (Test-Path $ks)){
  & "$jdk\bin\keytool.exe" -genkeypair -v -keystore $ks -alias igi -keyalg RSA -keysize 2048 -validity 10000 -storepass igisontek -keypass igisontek -dname "CN=S M Nazmuz Sakib, OU=IGI, O=Sontek Kajla, L=Dhaka, C=BD" | Out-Null
}
& "$sdk\build-tools\34.0.0\zipalign.exe" -f -p 4 $unsigned $aligned
& "$sdk\build-tools\34.0.0\apksigner.bat" sign --ks $ks --ks-key-alias igi --ks-pass pass:igisontek --key-pass pass:igisontek --out $signed $aligned
Copy-Item $signed 'G:\GTA\Code\IGI_SontekKajla.apk' -Force
Get-Item 'G:\GTA\Code\IGI_SontekKajla.apk' | Select-Object FullName,Length,LastWriteTime | Format-List
