# يبني نسخة الويب من التطبيق ويحطها في app/build/web_release (السيرفر يقدّمها).
# البناء يصير في مسار قصير لأن Flutter يفشل مع مسارات ويندوز الطويلة.
$ErrorActionPreference = 'Stop'
$env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')
$src = Join-Path $PSScriptRoot 'app'
$tmp = Join-Path $env:USERPROFILE 'flutter-download\kb'
if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp -Confirm:$false }
New-Item -ItemType Directory $tmp | Out-Null
foreach ($i in 'lib', 'web', 'assets', 'pubspec.yaml', 'pubspec.lock', 'analysis_options.yaml') { Copy-Item (Join-Path $src $i) -Destination $tmp -Recurse }
Push-Location $tmp
$ErrorActionPreference = 'Continue' # flutter يكتب ملاحظات على stderr
try {
  flutter pub get | Out-Null
  flutter build web --release
  if ($LASTEXITCODE -ne 0) { throw 'flutter build failed' }
} finally { Pop-Location }
$out = Join-Path $src 'build\web_release'
if (Test-Path $out) { Remove-Item -Recurse -Force $out -Confirm:$false }
Copy-Item -Recurse (Join-Path $tmp 'build\web') $out
# نسخة ثانية داخل مجلد السيرفر عشان تنرفع معاه على الاستضافة (Render)
$pub = Join-Path $PSScriptRoot 'server\public'
if (Test-Path $pub) { Remove-Item -Recurse -Force $pub -Confirm:$false }
Copy-Item -Recurse (Join-Path $tmp 'build\web') $pub
$apk = Join-Path $src 'build\batta.apk'
if (Test-Path $apk) { Copy-Item $apk $pub }
"Built -> $out (+ server\public)"
