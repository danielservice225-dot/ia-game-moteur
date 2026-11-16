$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root
$Python = "py"
& $Python -3.12 -m venv .venv-build
$VenvPython = Join-Path $Root ".venv-build\Scripts\python.exe"
& $VenvPython -m pip install --upgrade pip
& $VenvPython -m pip install -r requirements-windows.txt
if (Test-Path "build") { Remove-Item "build" -Recurse -Force }
if (Test-Path "dist") { Remove-Item "dist" -Recurse -Force }
if (Test-Path "IA_GAME_Trainer.spec") { Remove-Item "IA_GAME_Trainer.spec" -Force }
& $VenvPython -m PyInstaller --noconfirm --clean --onefile --windowed --name IA_GAME_Trainer --paths $Root --collect-all PySide6 --collect-all pandas --collect-all numpy --collect-all scipy --collect-all sklearn --collect-all joblib --hidden-import sklearn.ensemble._forest --hidden-import sklearn.neighbors._partition_nodes desktop_app/main.py
$Exe = Join-Path $Root "dist\IA_GAME_Trainer.exe"
if (-not (Test-Path $Exe)) { throw "Build failed: IA_GAME_Trainer.exe was not generated." }
Write-Host "Build successful: $Exe" -ForegroundColor Green
