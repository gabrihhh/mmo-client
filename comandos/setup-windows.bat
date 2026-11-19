<# :
@echo off
rem ============================================================================================
rem  Arquivo duplo: este trecho e o cmd (clique duplo funciona). Ele pede admin quando precisa
rem  e roda o resto deste mesmo arquivo no PowerShell. A explicacao do comando vem logo depois deste trecho.
rem ============================================================================================
setlocal
set "MMO_ADMIN=1"
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
# Prepara uma máquina Windows 10/11 para rodar o cliente do jogo (rodar uma vez; pode repetir sem medo).
# Ver mmo-docs [IA-03], [CLI-01] e [PAD-05].
#
# Uso: clique duplo em comandos\setup-windows.bat (pede admin), ou no terminal: comandos\setup-windows.bat
#   1. Git (winget Git.Git) — traz o Git Bash, usado por tools/*.sh (publicar pacote, gerar APK)
#   2. Godot 4.7.2 padrão, não .NET (winget GodotEngine.GodotEngine) e a variável de usuário GODOT_PATH
#      apontando para o executável de console (usada pelos scripts e pelo MCP do Godot; reabra o Claude Code depois)
#   3. importa o projeto (gera a pasta .godot e acusa erros de script)
# Não inclui o que só quem gera APK precisa (JDK 17, Android SDK, export templates): ver [CLI-06].
# Depois: comandos\run-game\windows.bat   (o servidor precisa estar no ar: ..\mmo-server\comandos\start-server\windows.bat)
$ErrorActionPreference = 'Stop'
## Pasta deste arquivo (o trecho cmd passa o caminho em MMO_SELF).
$here = Split-Path -Parent $env:MMO_SELF
Set-Location (Join-Path $here '..')

$GodotVersion = '4.7.2'

function Write-Step([string]$text) { Write-Host ''; Write-Host "=== $text ===" }

## Relê o PATH do Windows (programas recém-instalados aparecem sem reabrir o terminal).
function Update-SessionPath {
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
}

## True se o executável é o Godot da versão certa.
function Test-RightGodot([string]$exe) {
    if (-not $exe -or -not (Test-Path $exe)) { return $false }
    $out = & $exe --version 2>$null
    return ("$out" -like "$GodotVersion.stable*")
}

## Procura o Godot de console instalado pelo winget.
function Find-WingetGodot {
    $root = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages'
    if (-not (Test-Path $root)) { return $null }
    $found = Get-ChildItem -Path $root -Filter "Godot_v$GodotVersion-stable_win64_console.exe" -Recurse -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($found) { return $found.FullName }
    return $null
}

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Host 'winget não encontrado. Instale o "App Installer" pela Microsoft Store e rode de novo.'
    exit 1
}

# --- 1. Git ---
Write-Step '1/3 Git'
if (Get-Command git -ErrorAction SilentlyContinue) {
    Write-Host (git --version)
} else {
    winget install --id Git.Git --exact --accept-source-agreements --accept-package-agreements
    Update-SessionPath
}

# --- 2. Godot ---
Write-Step "2/3 Godot $GodotVersion"
$godot = [Environment]::GetEnvironmentVariable('GODOT_PATH', 'User')
if (-not (Test-RightGodot $godot)) {
    $godot = Find-WingetGodot
    if (-not $godot) {
        winget install --id GodotEngine.GodotEngine --exact --version $GodotVersion --accept-source-agreements --accept-package-agreements
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Versão $GodotVersion não achada no winget; instalando a mais nova do canal..."
            winget install --id GodotEngine.GodotEngine --exact --accept-source-agreements --accept-package-agreements
        }
        $godot = Find-WingetGodot
    }
    if (-not $godot) {
        Write-Host "Não achei o Godot $GodotVersion depois de instalar. Baixe em https://godotengine.org e aponte GODOT_PATH para o *_console.exe."
        exit 1
    }
    [Environment]::SetEnvironmentVariable('GODOT_PATH', $godot, 'User')
    Write-Host 'GODOT_PATH gravado (reabra terminais e o Claude Code para valer neles).'
}
$env:GODOT_PATH = $godot
Write-Host "Godot: $godot"

# --- 3. Importar o projeto ---
Write-Step '3/3 Importando o projeto (pode demorar na primeira vez)'
$errors = & $godot --path . --headless --editor --quit 2>&1 | ForEach-Object { "$_" } | Where-Object { $_ -match '^(ERROR|SCRIPT ERROR)' }
if ($errors) { $errors | ForEach-Object { Write-Host $_ } } else { Write-Host 'ok, sem erros' }

Write-Host ''
Write-Host 'Pronto! Abrir o jogo: clique duplo em comandos\run-game\windows.bat   |   editor: comandos\open-editor\windows.bat'
