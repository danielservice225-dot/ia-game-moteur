param(
    [string]$GodotExe = ""
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$Python = Join-Path $Root ".venv\Scripts\python.exe"
$SharedArtifacts = Join-Path $env:LOCALAPPDATA "IA GAME\artifacts"
$LocalModel = Join-Path $SharedArtifacts "model.joblib"
$Model = Join-Path $Root "artifacts\model.joblib"
if (Test-Path $LocalModel) {
    $env:IA_GAME_ARTIFACT_DIR = $SharedArtifacts
    $Model = $LocalModel
} else {
    $env:IA_GAME_ARTIFACT_DIR = Join-Path $Root "artifacts"
}

if (-not (Test-Path $Python) -or -not (Test-Path $Model)) {
    throw "Préparation absente. Exécutez d'abord .\scripts\prepare_offline.ps1 avec Internet."
}

if ([string]::IsNullOrWhiteSpace($GodotExe)) {
    if ($env:GODOT_EXE -and (Test-Path $env:GODOT_EXE)) {
        $GodotExe = $env:GODOT_EXE
    } else {
        $GodotCommand = Get-Command godot -ErrorAction SilentlyContinue
        if ($GodotCommand) {
            $GodotExe = $GodotCommand.Source
        }
    }
}
if ([string]::IsNullOrWhiteSpace($GodotExe) -or -not (Test-Path $GodotExe)) {
    throw "Godot est introuvable. Passez son chemin avec le paramètre -GodotExe ou définissez GODOT_EXE."
}

$Server = $null
try {
    Write-Host "Démarrage de l'API ML locale..."
    $Server = Start-Process -FilePath $Python -ArgumentList @(
        "-m", "uvicorn", "backend.main:app",
        "--host", "127.0.0.1", "--port", "8000"
    ) -WorkingDirectory $Root -PassThru -WindowStyle Hidden

    $Ready = $false
    for ($Attempt = 0; $Attempt -lt 30; $Attempt++) {
        if ($Server.HasExited) {
            throw "Le serveur Python s'est arrêté. Vérifiez les dépendances et le modèle."
        }
        try {
            $Health = Invoke-RestMethod -Uri "http://127.0.0.1:8000/health" -TimeoutSec 2
            if ($Health.status -eq "ok" -and $Health.model_available) {
                $Ready = $true
                break
            }
        } catch {
            Start-Sleep -Seconds 1
        }
    }
    if (-not $Ready) {
        throw "L'API ML n'a pas répondu dans le délai prévu."
    }

    Write-Host "API prête. Lancement de la simulation Godot..."
    $GamePath = Join-Path $Root "godot_game"
    $QuotedGamePath = '"' + $GamePath + '"'
    Start-Process -FilePath $GodotExe -ArgumentList @("--path", $QuotedGamePath) -Wait
} finally {
    if ($Server -and -not $Server.HasExited) {
        Stop-Process -Id $Server.Id -Force
    }
}
