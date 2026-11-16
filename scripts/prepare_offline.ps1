$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

if (Get-Command py -ErrorAction SilentlyContinue) {
    & py -3 -m venv (Join-Path $Root ".venv")
} elseif (Get-Command python -ErrorAction SilentlyContinue) {
    & python -m venv (Join-Path $Root ".venv")
} else {
    throw "Python 3 est introuvable. Installez Python 3.10 ou supérieur."
}

$Python = Join-Path $Root ".venv\Scripts\python.exe"
if (-not (Test-Path $Python)) {
    throw "L'environnement Python n'a pas pu être créé."
}

Write-Host "Installation des dépendances (cette étape nécessite Internet la première fois)..."
& $Python -m pip install --upgrade pip
if ($LASTEXITCODE -ne 0) { throw "Échec de mise à jour de pip." }
& $Python -m pip install -e .
if ($LASTEXITCODE -ne 0) { throw "Échec d'installation des dépendances IA GAME." }

Write-Host "Génération du jeu de données de démonstration synthétique..."
& $Python scripts/generate_demo_dataset.py
if ($LASTEXITCODE -ne 0) { throw "Échec de génération du dataset." }

Write-Host "Entraînement du modèle local..."
& $Python scripts/demo_train.py
if ($LASTEXITCODE -ne 0) { throw "Échec de l'entraînement du modèle." }

Write-Host "Préparation terminée. Le modèle local est prêt pour une utilisation hors ligne."
Write-Host "Lancez ensuite : .\scripts\run_offline.ps1"
