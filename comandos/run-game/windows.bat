<# :
@echo off
rem ============================================================================================
rem  Arquivo duplo: este trecho e o cmd (clique duplo funciona). Ele pede admin quando precisa
rem  e roda o resto deste mesmo arquivo no PowerShell. A explicacao do comando vem logo depois deste trecho.
rem ============================================================================================
setlocal
set "MMO_ADMIN=0"
if not "%MMO_ADMIN%"=="1" goto run
net session >nul 2>&1
if not errorlevel 1 goto run
echo Pedindo permissao de administrador...
if "%~1"=="" goto elevate_noargs
powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -ArgumentList '%*' -Verb RunAs"
exit /b
:elevate_noargs
powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
exit /b
:run
chcp 65001 >nul
set "MMO_SELF=%~f0"
set "MMO_ARGS=%*"
powershell -NoProfile -ExecutionPolicy Bypass -Command "iex ([IO.File]::ReadAllText($env:MMO_SELF, [Text.Encoding]::UTF8))"
set "MMO_CODE=%errorlevel%"
if "%MMO_NO_PAUSE%"=="1" exit /b %MMO_CODE%
if "%MMO_ADMIN%"=="1" pause & exit /b %MMO_CODE%
if not "%MMO_CODE%"=="0" pause
exit /b %MMO_CODE%
#>
# Abre o jogo numa janela de teste no PC. Ver mmo-docs [CLI-05] e [PAD-05].
#
# Uso: clique duplo em comandos\run-game\windows.bat (abre na tela de login),
#      ou no terminal: comandos\run-game\windows.bat [Nome] [argumentos extras do jogo]
#   sem Nome   → abre na tela de login, como um jogador normal
#   com Nome   → entra direto como a conta de teste "Nome" (cria se não existir), com perfil próprio:
#                dá para abrir várias janelas ao mesmo tempo, uma por nome, sem uma derrubar a outra.
# Exemplos:
#   comandos\run-game\windows.bat Ana
#   comandos\run-game\windows.bat Bia --bot-fight=espada
# Não pede admin (o jogo não precisa). O servidor precisa estar no ar: ..\mmo-server\comandos\start-server\windows.bat
$ErrorActionPreference = 'Stop'
## Pasta deste arquivo (o trecho cmd passa o caminho em MMO_SELF).
$here = Split-Path -Parent $env:MMO_SELF
Set-Location (Join-Path $here '..\..')

$godot = $env:GODOT_PATH
if (-not $godot) { $godot = [Environment]::GetEnvironmentVariable('GODOT_PATH', 'User') }
if (-not $godot -and (Get-Command godot -ErrorAction SilentlyContinue)) { $godot = 'godot' }
if (-not $godot) {
    Write-Host 'Godot não encontrado. Rode: comandos\setup-windows.bat'
    exit 1
}

try {
    Invoke-WebRequest -Uri 'http://localhost:2567/health' -UseBasicParsing -TimeoutSec 2 | Out-Null
} catch {
    Write-Host 'AVISO: servidor local não respondeu (http://localhost:2567/health). Ligue: ..\mmo-server\comandos\start-server\windows.bat'
}

## Argumentos dados ao .bat (o trecho cmd passa em MMO_ARGS).
$rest = @("$env:MMO_ARGS" -split '\s+' | Where-Object { $_ -ne '' })
$gameArgs = @()
if ($rest.Count -gt 0 -and -not $rest[0].StartsWith('-')) {
    $gameArgs += "--profile=$($rest[0])", "--dev-user=$($rest[0])"
    $rest = @($rest | Select-Object -Skip 1)
}
$gameArgs += $rest

$godotArgs = @('--path', '.')
if ($gameArgs.Count -gt 0) { $godotArgs += @('--') + $gameArgs }
& $godot @godotArgs
exit $LASTEXITCODE
