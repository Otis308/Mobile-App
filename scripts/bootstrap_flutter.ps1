# Sinh thư mục android/ cho mobile_app (cần Flutter SDK + Python 3).
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$App = Join-Path $Root 'mobile_app'
$Tmp = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
flutter create --org com.workflow --project-name workflow_mobile --platforms=android $Tmp
if (Test-Path (Join-Path $App 'android')) { Remove-Item -Recurse -Force (Join-Path $App 'android') }
Copy-Item -Recurse (Join-Path $Tmp 'android') (Join-Path $App 'android')
Remove-Item -Recurse -Force $Tmp
python (Join-Path $Root 'scripts/prepare_android.py') $App
Set-Location $App
flutter pub get
Write-Host 'Hoàn tất. Chạy: flutter run (hoặc flutter build apk --release)'
