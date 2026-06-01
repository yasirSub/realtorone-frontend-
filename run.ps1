# Run Flutter app from this repo (fixes PATH for this session)
$flutterBin = 'F:\CODEING\flutter\flutter\bin'
if (Test-Path $flutterBin) { $env:Path = "$flutterBin;$env:Path" }
Set-Location $PSScriptRoot
$dev = flutter devices --machine 2>$null | ConvertFrom-Json | Where-Object { $_.category -ne 'web' } | Select-Object -First 1
if (-not $dev) { $dev = flutter devices --machine 2>$null | ConvertFrom-Json | Select-Object -First 1 }
if ($dev) { flutter run -d $dev.id } else { flutter run }
