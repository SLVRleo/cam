# cam.ps1 - sobe o servidor local e abre o HOST (webcam do PC) no navegador.
#
# Uso:  .\cam.ps1 [CHAVE] [-NoBrowser]   (ou duplo clique em cam.cmd)
# Chave, nesta ordem: argumento > $env:CAM_KEY > arquivo ~\.cam-key > pergunta.
# A chave nunca vai pro repositorio; fica so no ~\.cam-key se voce quiser salvar.

param([string]$Key, [switch]$NoBrowser)

$ErrorActionPreference = "Stop"
$Port     = 8765
$PagesUrl = "https://slvrleo.github.io/cam/"   # onde o celular abre o ?view
$KeyFile  = Join-Path $HOME ".cam-key"
$Root     = $PSScriptRoot

# ---- chave -----------------------------------------------------------------
if (-not $Key) { $Key = $env:CAM_KEY }
if (-not $Key -and (Test-Path $KeyFile)) { $Key = (Get-Content $KeyFile -Raw).Trim() }
if (-not $Key) {
    $sec = Read-Host "chave de acesso" -AsSecureString
    $Key = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
             [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)).Trim()
    if (-not $Key) { Write-Host "sem chave, saindo."; exit 1 }
    if ((Read-Host "salvar em $KeyFile ? (s/N)") -match '^[sS]') {
        Set-Content -Path $KeyFile -Value $Key -Encoding utf8 -NoNewline
    }
}
$Frag = [uri]::EscapeDataString($Key)

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
              -ArgumentList "-m", "http.server", "$Port", "--bind", "127.0.0.1"
    Start-Sleep -Milliseconds 800
}

# ---- navegador -------------------------------------------------------------
# abre Chrome/Edge direto: via associacao do Windows o #fragmento (chave) pode se perder
$HostUrl = "http://127.0.0.1:$Port/?host#$Frag"
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
Write-Host "CELULAR:       $PagesUrl`?view#$Frag"
Write-Host ""

if ($server) {
    Write-Host "servidor rodando. Ctrl+C ou feche esta janela pra parar."
    try { Wait-Process -Id $server.Id }
    finally { if (-not $server.HasExited) { Stop-Process -Id $server.Id -Force } }
}
