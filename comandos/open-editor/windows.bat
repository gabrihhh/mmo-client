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
# Abre o projeto no editor do Godot (solto do terminal). Ver mmo-docs [CLI-01] e [PAD-05].
# Uso: clique duplo em comandos\open-editor\windows.bat, ou no terminal: comandos\open-editor\windows.bat
# Não pede admin (o editor não precisa).
$ErrorActionPreference = 'Stop'
## Pasta deste arquivo (o trecho cmd passa o caminho em MMO_SELF).
$here = Split-Path -Parent $env:MMO_SELF
Set-Location (Join-Path $here '..\..')

$godot = $env:GODOT_PATH
if (-not $godot) { $godot = [Environment]::GetEnvironmentVariable('GODOT_PATH', 'User') }
if (-not $godot -and (Get-Command godot -ErrorAction SilentlyContinue)) { $godot = (Get-Command godot).Source }
if (-not $godot) {
    Write-Host 'Godot não encontrado. Rode: comandos\setup-windows.bat'
    exit 1
}
# O GODOT_PATH aponta para o *_console.exe; o editor abre melhor sem a janela de console.
$noConsole = $godot -replace '_console\.exe$', '.exe'
if (Test-Path $noConsole) { $godot = $noConsole }

Start-Process -FilePath $godot -ArgumentList '--path', '.', '--editor' -WorkingDirectory (Get-Location)
Write-Host 'Editor do Godot abrindo...'
