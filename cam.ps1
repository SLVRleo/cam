# cam.ps1 - sobe o servidor local (server.py) e abre o HOST (webcam do PC) no navegador.
# Gravacoes do rec caem em .\gravacoes do projeto.
#
# Uso:  .\cam.ps1 [CHAVE] [-NoBrowser]   (ou duplo clique em cam.cmd)
# A chave fica guardada no navegador (gerada na 1a vez). Celular: botao "parear" no PC.
# Chave opcional forca uma especifica: argumento > $env:CAM_KEY > arquivo ~\.cam-key.

param([string]$Key, [switch]$NoBrowser)

$ErrorActionPreference = "Stop"
$Port     = 8765
$KeyFile  = Join-Path $HOME ".cam-key"
$Root     = $PSScriptRoot

# ---- chave -----------------------------------------------------------------
if (-not $Key) { $Key = $env:CAM_KEY }
if (-not $Key -and (Test-Path $KeyFile)) { $Key = (Get-Content $KeyFile -Raw).Trim() }
$Frag = if ($Key) { "#" + [uri]::EscapeDataString($Key) } else { "" }

# ---- python ----------------------------------------------------------------
$py = Get-Command py -ErrorAction SilentlyContinue
if (-not $py) { $py = Get-Command python -ErrorAction SilentlyContinue }
if (-not $py) { Write-Host "Python nao encontrado (precisa de python ou py no PATH)."; exit 1 }

# ---- servidor (reaproveita se a porta ja estiver ocupada) --------------------
$server = $null
$busy = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
if ($busy) {
    Write-Host "porta $Port ja em uso - usando o servidor que ja esta rodando."
} else {
    $server = Start-Process -FilePath $py.Source -WorkingDirectory $Root -NoNewWindow -PassThru `
              -ArgumentList "`"$(Join-Path $Root 'server.py')`"", "$Port"
    Start-Sleep -Milliseconds 800
}

# ---- navegador -------------------------------------------------------------
# abre Chrome/Edge direto: via associacao do Windows o #fragmento (chave) pode se perder
$HostUrl = "http://127.0.0.1:$Port/?host$Frag"
$browser = @(
    "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
    "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
    "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe",
    "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
    "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe"
) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1

if ($NoBrowser) { }
elseif ($browser) { Start-Process -FilePath $browser -ArgumentList "--new-window", $HostUrl }
else          { Start-Process $HostUrl }

Write-Host ""
Write-Host "HOST (PC):     $HostUrl"
Write-Host "CELULAR:       clique em parear no PC e escaneie o QR (so na 1a vez)"
Write-Host ""

if ($server) {
    Write-Host "servidor rodando. Ctrl+C ou feche esta janela pra parar."
    try { Wait-Process -Id $server.Id }
    finally { if (-not $server.HasExited) { Stop-Process -Id $server.Id -Force } }
}
