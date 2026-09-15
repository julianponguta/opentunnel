# OpenTunnel - SSH via Pinggy TCP tunnel para Windows
# Sin instalar nada (usa el OpenSSH del sistema), sin cuenta, sin email.
#
# Uso (PowerShell como Administrador):
#   irm https://raw.githubusercontent.com/julianponguta/opentunnel/main/connect.ps1 -OutFile $env:TEMP\ot.ps1
#   & $env:TEMP\ot.ps1 -Minutes 60 -User tunneluser
#   & $env:TEMP\ot.ps1 -Minutes 60 -User Administrator -SshKey "ssh-ed25519 AAAA..."
#
# NOTA: la llave SSH debe ir SIN comentario/email. Solo "ssh-ed25519 AAAA...".

param(
    [int]$Minutes = 60,
    [string]$User = "tunneluser",
    [string]$SshKey = ""
)

$ErrorActionPreference = "Stop"

function Write-Info($msg) { Write-Host "[+] $msg" -ForegroundColor Green }
function Write-ErrMsg($msg) { Write-Host "[x] $msg" -ForegroundColor Red }

# --- Soporte de args flexibles ---
foreach ($a in $args) {
    if ($a -match '^ssh-') { $SshKey = "$a" }
    elseif ($a -match '^[0-9]+$') { $Minutes = [int]$a }
    elseif ($a -ne "") { $User = "$a" }
}

# --- Sanitizar llave: solo tipo + base64, sin comentario/email ---
if ($SshKey -ne "") {
    $parts = ($SshKey -split '\s+')
    if ($parts.Count -ge 2) {
        $SshKey = $parts[0] + " " + $parts[1]
    }
}

# --- Requiere admin ---
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-ErrMsg "Ejecuta PowerShell como Administrador"
    exit 1
}

$TempPassword = ""

Write-Info "OpenTunnel v7.2 - $Minutes min, user: $User"

# --- Usuario local ---
$existingUser = $null
try { $existingUser = Get-LocalUser -Name $User -ErrorAction Stop } catch { $existingUser = $null }

if ([string]::IsNullOrEmpty($SshKey)) {
    if ($null -ne $existingUser) {
        Write-Info "Sin llave SSH - usa la contrasena existente de $User"
    } else {
        $chars = (48..57) + (65..90) + (97..122)
        $TempPassword = -join ($chars | Get-Random -Count 16 | ForEach-Object { [char]$_ })
        $secPass = ConvertTo-SecureString $TempPassword -AsPlainText -Force
        New-LocalUser -Name $User -Password $secPass -FullName "OpenTunnel temp user" -Description "Temporary user by OpenTunnel" | Out-Null
        Add-LocalGroupMember -Group "Users" -Member $User -ErrorAction SilentlyContinue
        Write-Info "Usuario temporal $User creado con contrasena"
    }
} else {
    if ($null -eq $existingUser) {
        $randPass = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 24 | ForEach-Object { [char]$_ })
        $secPass = ConvertTo-SecureString $randPass -AsPlainText -Force
        New-LocalUser -Name $User -Password $secPass -FullName "OpenTunnel temp user" -Description "Temporary user by OpenTunnel" | Out-Null
        Add-LocalGroupMember -Group "Users" -Member $User -ErrorAction SilentlyContinue
        Write-Info "Usuario $User creado"
    }
}

# --- OpenSSH Server ---
Write-Info "Verificando OpenSSH Server..."
$cap = Get-WindowsCapability -Online | Where-Object { $_.Name -like 'OpenSSH.Server*' }
if ($null -ne $cap -and $cap.State -ne "Installed") {
    Write-Info "Instalando OpenSSH Server..."
    Add-WindowsCapability -Online -Name $cap.Name | Out-Null
}
Start-Service sshd -ErrorAction SilentlyContinue
Set-Service -Name sshd -StartupType Automatic -ErrorAction SilentlyContinue

# Config sshd: llaves si, password si (para modo sin llave)
$sshdConfig = "$env:ProgramData\ssh\sshd_config"
if (Test-Path $sshdConfig) {
    $cfg = Get-Content $sshdConfig -Raw
    if ($cfg -notmatch '(?m)^PubkeyAuthentication\s+yes') {
        if ($cfg -match '(?m)^#?PubkeyAuthentication.*') {
            $cfg = $cfg -replace '(?m)^#?PubkeyAuthentication.*', 'PubkeyAuthentication yes'
        } else {
            $cfg += "`r`nPubkeyAuthentication yes`r`n"
        }
    }
    if ([string]::IsNullOrEmpty($SshKey)) {
        if ($cfg -match '(?m)^#?PasswordAuthentication.*') {
            $cfg = $cfg -replace '(?m)^#?PasswordAuthentication.*', 'PasswordAuthentication yes'
        } else {
            $cfg += "`r`nPasswordAuthentication yes`r`n"
        }
    }
    Set-Content -Path $sshdConfig -Value $cfg -Encoding ASCII
    Restart-Service sshd -ErrorAction SilentlyContinue
}

# --- Instalar llave autorizada (sin email) ---
if ($SshKey -ne "") {
    $userProfile = $null
    try {
        $acc = New-Object System.Security.Principal.NTAccount($User)
        $sid = $acc.Translate([System.Security.Principal.SecurityIdentifier]).Value
        $regPath = "Registry::HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$sid"
        $userProfile = (Get-ItemProperty -Path $regPath -Name ProfileImagePath -ErrorAction Stop).ProfileImagePath
        $userProfile = [System.Environment]::ExpandEnvironmentVariables($userProfile)
    } catch { $userProfile = $null }
    if ([string]::IsNullOrEmpty($userProfile)) {
        $userProfile = Join-Path "C:\Users" $User
    }

    $sshDir = Join-Path $userProfile ".ssh"
    New-Item -ItemType Directory -Path $sshDir -Force | Out-Null
    $authKeys = Join-Path $sshDir "authorized_keys"
    $existing = ""
    if (Test-Path $authKeys) { $existing = Get-Content $authKeys -Raw }
    if ($existing -notmatch [regex]::Escape($SshKey)) {
        Add-Content -Path $authKeys -Value $SshKey -Encoding ASCII
    }

    # Si es admin, Windows exige tambien administrators_authorized_keys
    $isTargetAdmin = $false
    try {
        $members = Get-LocalGroupMember -Group "Administrators" -ErrorAction Stop | ForEach-Object { $_.Name }
        foreach ($m in $members) { if ($m -like "*\$User" -or $m -eq $User) { $isTargetAdmin = $true } }
    } catch { $isTargetAdmin = $false }

    if ($isTargetAdmin) {
        $adminKeys = "$env:ProgramData\ssh\administrators_authorized_keys"
        $adminExisting = ""
        if (Test-Path $adminKeys) { $adminExisting = Get-Content $adminKeys -Raw }
        if ($adminExisting -notmatch [regex]::Escape($SshKey)) {
            Add-Content -Path $adminKeys -Value $SshKey -Encoding ASCII
        }
        icacls $adminKeys /inheritance:r /grant "Administrators:F" /grant "SYSTEM:F" | Out-Null
    }

    icacls $sshDir /inheritance:r /grant:r "$($User):(OI)(CI)F" /grant "SYSTEM:F" /grant "Administrators:F" 2>$null | Out-Null
    Write-Info "Llave SSH agregada para $User (sin comentario/email)"
}

# --- Cliente SSH (viene con Windows 10+/Server 2019+) ---
$sshExe = (Get-Command ssh -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -ErrorAction SilentlyContinue)
if ([string]::IsNullOrEmpty($sshExe)) {
    Write-Info "Instalando OpenSSH Client..."
    $cliCap = Get-WindowsCapability -Online | Where-Object { $_.Name -like 'OpenSSH.Client*' }
    if ($null -ne $cliCap) { Add-WindowsCapability -Online -Name $cliCap.Name | Out-Null }
    $sshExe = (Get-Command ssh -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -ErrorAction SilentlyContinue)
}
if ([string]::IsNullOrEmpty($sshExe)) {
    Write-ErrMsg "No se encontro el cliente ssh"
    exit 1
}

# --- Tunel TCP via Pinggy (tcp@free no pide auth, sin cuenta ni email) ---
$logOut = Join-Path $env:TEMP "ot_pinggy.out.log"
$logErr = Join-Path $env:TEMP "ot_pinggy.err.log"
$emptyIn = Join-Path $env:TEMP "ot_pinggy.empty"
Set-Content -Path $emptyIn -Value "" -Encoding Ascii -NoNewline
foreach ($f in @($logOut, $logErr)) { if (Test-Path $f) { Remove-Item $f -Force } }

Write-Info "Abriendo tunel TCP via Pinggy (solo ssh, sin instalar nada)..."
# 127.0.0.1 en vez de localhost: bug conocido del ssh de Windows.
# IMPORTANTE: sin -N. Pinggy anuncia la URL tcp:// por el canal de shell;
# con -N nunca la imprime y el parseo falla (stdin ya viene de archivo vacio).
$Endpoints = @("tcp@free.pinggy.io", "tcp@a.pinggy.io")
$Tunnel = ""
$proc = $null
foreach ($ep in $Endpoints) {
    Write-Info "Trying $ep ..."
    foreach ($f in @($logOut, $logErr)) { if (Test-Path $f) { Remove-Item $f -Force } }
    $proc = Start-Process -FilePath $sshExe -ArgumentList "-T","-o","StrictHostKeyChecking=no","-o","UserKnownHostsFile=NUL","-o","ServerAliveInterval=30","-o","ServerAliveCountMax=3","-o","ConnectTimeout=15","-o","BatchMode=yes","-o","LogLevel=ERROR","-p","443","-R0:127.0.0.1:22",$ep -RedirectStandardOutput $logOut -RedirectStandardError $logErr -RedirectStandardInput $emptyIn -WindowStyle Hidden -PassThru

    for ($i = 0; $i -lt 20; $i++) {
        Start-Sleep -Seconds 1
        foreach ($f in @($logOut, $logErr)) {
            if (Test-Path $f) {
                $content = Get-Content $f -Raw -ErrorAction SilentlyContinue
                if ($null -ne $content) {
                    $m = [regex]::Match($content, 'tcp://([A-Za-z0-9.-]+):([0-9]+)')
                    if ($m.Success) {
                        $Tunnel = $m.Groups[1].Value + ":" + $m.Groups[2].Value
                        break
                    }
                }
            }
        }
        if ($Tunnel -ne "") { break }
        if ($proc.HasExited) { break }
    }
    if ($Tunnel -ne "") {
        Write-Info "Tunnel ready via ${ep}: $Tunnel"
        break
    }
    try { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue } catch {}
    Write-Host "[x] No URL from $ep, probando siguiente..." -ForegroundColor Red
}

if ([string]::IsNullOrEmpty($Tunnel)) {
    Write-ErrMsg "No se pudo establecer el tunel (timeout)"
    foreach ($f in @($logOut, $logErr)) { if (Test-Path $f) { Get-Content $f | Write-Host } }
    try { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue } catch {}
    exit 1
}

$parts = $Tunnel -split ':'
$TunHost = $parts[0]
$TunPort = $parts[1]

Write-Host ""
Write-Host "========================================================"
Write-Host "              CONNECTED" -ForegroundColor Green
Write-Host "========================================================"
Write-Host ""
Write-Host "Tunnel: $Tunnel"
Write-Host "User: $User"
if ($TempPassword -ne "") {
    Write-Host "Password: $TempPassword"
}
if (([string]::IsNullOrEmpty($SshKey)) -and ($TempPassword -eq "")) {
    Write-Host "Password: (usa tu contrasena existente de $User)"
}
Write-Host ""
Write-Host "COPY TO YOUR LOCAL MACHINE:"
Write-Host "  $Tunnel"
Write-Host ""
Write-Host "CONNECT FROM LOCAL (plain ssh, nada que instalar):"
if ($SshKey -ne "") {
    Write-Host "  ssh -i ~/.ssh/id_ed25519 -p $TunPort ${User}@${TunHost}"
} else {
    Write-Host "  ssh -p $TunPort ${User}@${TunHost}"
}
Write-Host ""
Write-Host "========================================================"

try {
    Start-Sleep -Seconds ($Minutes * 60)
} finally {
    try { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue } catch {}
    foreach ($f in @($logOut, $logErr, $emptyIn)) { if (Test-Path $f) { Remove-Item $f -Force -ErrorAction SilentlyContinue } }
}
