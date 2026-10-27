# يبني ملف APK للجوال ويحطه في app/build/batta.apk
# الاستخدام: .\build-apk.ps1 -Server ws://192.168.0.100:8080
param([string]$Server = '')
$ErrorActionPreference = 'Stop'
$env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')
$src = Join-Path $PSScriptRoot 'app'
# البناء من مسار قصير لأن Gradle و Flutter يفشلون مع مسارات ويندوز الطويلة
$tmp = Join-Path $env:USERPROFILE 'flutter-download\kb-android'
if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp -Confirm:$false }
New-Item -ItemType Directory $tmp | Out-Null
foreach ($i in 'lib', 'android', 'assets', 'pubspec.yaml', 'pubspec.lock', 'analysis_options.yaml') { Copy-Item (Join-Path $src $i) -Destination $tmp -Recurse }
Push-Location $tmp
$ErrorActionPreference = 'Continue' # flutter يكتب ملاحظات على stderr
try {
  flutter pub get | Out-Null
  $defines = @()
  if ($Server) { $defines += "--dart-define=SERVER_URL=$Server" }
  flutter build apk --release @defines
  if ($LASTEXITCODE -ne 0) { throw 'flutter build apk failed' }
} finally { Pop-Location }
$out = Join-Path $src 'build\batta.apk'
New-Item -ItemType Directory -Force (Split-Path $out) | Out-Null
Copy-Item (Join-Path $tmp 'build\app\outputs\flutter-apk\app-release.apk') $out -Force
"APK -> $out"
