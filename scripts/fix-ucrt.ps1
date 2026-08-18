# fix-ucrt.ps1
#
# Auto-repair missing Universal CRT (UCRT) forwarding DLLs on Windows.
#
# Problem
#   MoonBit's moonrun.exe (and other MSVC-built binaries) depend on the
#   "API-set" forwarding DLLs named api-ms-win-crt-*.dll. On some Windows images
#   these files exist only under C:\Windows\System32\downlevel\ and are absent
#   from C:\Windows\System32\. When the loader cannot find them, the process
#   dies immediately with exit code 0xC0000139 (STATUS_ENTRYPOINT_NOT_FOUND)
#   and prints nothing.
#
# This script detects the gap and repairs it by copying the missing DLLs from
# the downlevel directory. It tries, in order:
#   1. Copy into C:\Windows\System32     (needs admin; system-wide fix)
#   2. Copy next to the target binary    (no admin; local workaround, the
#      directory containing the .exe is searched first by the loader)
#
# Usage
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts/fix-ucrt.ps1
#   powershell ... -File scripts/fix-ucrt.ps1 -Target C:\path\to\moonrun.exe
#   powershell ... -File scripts/fix-ucrt.ps1 -Force
#   powershell ... -File scripts/fix-ucrt.ps1 -WhatIf
#
# Exit codes: 0 = all good / fixed, 1 = could not fully repair.

param(
    [string]$Target = "",
    [switch]$Force,
    [switch]$WhatIf,
    [switch]$NoElevate
)

$ErrorActionPreference = "Stop"

# Auto-elevate: UCRT forwarder DLLs MUST live in C:\Windows\System32 to be
# resolved by the loader, so a system-wide fix requires administrator rights.
# When we detect missing DLLs and are not elevated, re-launch self with a UAC
# prompt so the repair is fully automatic (unless -NoElevate is given).
if (-not $NoElevate) {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $pr = New-Object Security.Principal.WindowsPrincipal($id)
    $isAdmin = $pr.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Info "Not elevated. Re-launching with administrator rights (UAC)..."
        $argList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $MyInvocation.MyCommand.Path)
        if ($Target)  { $argList += @("-Target", $Target) }
        if ($Force)   { $argList += "-Force" }
        if ($WhatIf)  { $argList += "-WhatIf" }
        $argList += "-NoElevate"
        try {
            Start-Process -FilePath "powershell.exe" -Verb RunAs -ArgumentList $argList -Wait
        } catch {
            Write-Err "Elevation was cancelled or failed: $_"
            Write-Err "Re-run this script as Administrator for a system-wide fix."
            exit 1
        }
        exit 0
    }
}

function Write-Info($m) { Write-Host "[fix-ucrt] $m" }
function Write-Ok($m)   { Write-Host "[fix-ucrt] OK   $m" -ForegroundColor Green }
function Write-Warn($m) { Write-Host "[fix-ucrt] WARN $m" -ForegroundColor Yellow }
function Write-Err($m)  { Write-Host "[fix-ucrt] ERR  $m" -ForegroundColor Red }

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $pr = New-Object Security.Principal.WindowsPrincipal($id)
    return $pr.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Copy-IfMissing($src, $dstDir, $name) {
    $dst = Join-Path $dstDir $name
    if ((-not $Force) -and (Test-Path $dst)) {
        Write-Ok "present: $dst"
        return $true
    }
    if ($WhatIf) {
        Write-Info "WhatIf: would copy $name -> $dstDir"
        return $true
    }
    try {
        Copy-Item -Path $src -Destination $dst -Force
        Write-Ok "copied: $name -> $dstDir"
        return $true
    } catch {
        Write-Warn "failed to copy $name -> $dstDir : $_"
        return $false
    }
}

# 1. locate the failing binary
if (-not $Target) {
    $moon = (Get-Command moon -ErrorAction SilentlyContinue).Source
    if ($moon) {
        $Target = Join-Path (Split-Path $moon) "moonrun.exe"
    }
}
if (-not $Target -or -not (Test-Path $Target)) {
    Write-Err "Cannot locate target binary (moonrun.exe). Pass -Target <path>."
    exit 1
}
Write-Info "Target binary: $Target"

$binDir = Split-Path $Target

# 2. enumerate required CRT dlls
$needed = @(
    "api-ms-win-crt-conio-l1-1-0.dll",
    "api-ms-win-crt-convert-l1-1-0.dll",
    "api-ms-win-crt-environment-l1-1-0.dll",
    "api-ms-win-crt-filesystem-l1-1-0.dll",
    "api-ms-win-crt-heap-l1-1-0.dll",
    "api-ms-win-crt-locale-l1-1-0.dll",
    "api-ms-win-crt-math-l1-1-0.dll",
    "api-ms-win-crt-multibyte-l1-1-0.dll",
    "api-ms-win-crt-private-l1-1-0.dll",
    "api-ms-win-crt-process-l1-1-0.dll",
    "api-ms-win-crt-runtime-l1-1-0.dll",
    "api-ms-win-crt-stdio-l1-1-0.dll",
    "api-ms-win-crt-string-l1-1-0.dll",
    "api-ms-win-crt-time-l1-1-0.dll",
    "api-ms-win-crt-utility-l1-1-0.dll",
    "ucrtbase.dll",
    "vcruntime140.dll",
    "msvcp140.dll"
)

$sysRoot = $env:SystemRoot
if (-not $sysRoot) { $sysRoot = "C:\Windows" }
$sys32        = Join-Path $sysRoot "System32"
$downlevel    = Join-Path $sys32  "downlevel"
$sysWow64     = Join-Path $sysRoot "SysWOW64"
$downlevelWOW = Join-Path $sysWow64 "downlevel"

# 3. build a source map for every missing dll
# IMPORTANT: UCRT api-ms-win-crt-* forwarder DLLs only resolve correctly from
# C:\Windows\System32. A copy sitting next to the .exe does NOT satisfy the
# loader (verified: moonrun.exe still crashes with 0xC0000139). So a DLL is
# considered "present" ONLY when it exists in System32.
$missing = @()
foreach ($dll in $needed) {
    if (Test-Path (Join-Path $sys32 $dll)) { continue }
    $src = $null
    foreach ($cand in @($downlevel, $downlevelWOW, $sysWow64, $sys32)) {
        $p = Join-Path $cand $dll
        if (Test-Path $p) { $src = $p; break }
    }
    if (-not $src) {
        Write-Warn "No source for $dll anywhere; skipping (install VC++ redist)."
        continue
    }
    $missing += @{ Name = $dll; Src = $src }
}

if ($missing.Count -eq 0) {
    Write-Ok "All required CRT DLLs are already present. Nothing to do."
    exit 0
}
Write-Info "Missing $($missing.Count) DLL(s); attempting repair."

# 4. repair: UCRT forwarder DLLs MUST go to System32 (system-wide, admin only)
$admin = Test-Admin
if (-not $admin) {
    Write-Err "Administrator rights are required to write $sys32."
    Write-Err "Re-run this script as Administrator (it can auto-elevate via UAC)."
    exit 1
}
Write-Info "Running as Administrator -> repairing system-wide in $sys32"
foreach ($item in $missing) {
    Copy-IfMissing $item.Src $sys32 $item.Name | Out-Null
}

# 5. verify
$bad = 0
foreach ($item in $missing) {
    if (-not (Test-Path (Join-Path $sys32 $item.Name))) { $bad++ }
}
if ($bad -gt 0) {
    Write-Err "$bad DLL(s) could not be repaired. Install the VC++ 2015-2022"
    Write-Err "Redistributable (x64) from Microsoft, or copy the DLLs manually."
    Write-Err "Download: https://aka.ms/vs/17/release/vc_redist.x64.exe"
    exit 1
}

Write-Ok "Repair complete. Try running 'moon test' again."
exit 0
