$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$runtime = Join-Path $repo 'src\AutoHotkey\AutoHotkey64.exe'
if (-not (Test-Path -LiteralPath $runtime)) { throw 'Install the official AutoHotkey v2 runtime at src/AutoHotkey/AutoHotkey64.exe first.' }

function Invoke-Ahk([string]$Script, [string]$Extra = '', [switch]$Validate) {
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $runtime
    $start.Arguments = '/ErrorStdOut=UTF-8 /CP65001 ' + $(if ($Validate) { '/validate ' }) + '"' + $Script + '" ' + $Extra
    $start.WorkingDirectory = $repo
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $start.StandardOutputEncoding = [Text.Encoding]::UTF8
    $start.StandardErrorEncoding = [Text.Encoding]::UTF8
    $process = [Diagnostics.Process]::Start($start)
    $stdout = $process.StandardOutput.ReadToEndAsync()
    $stderr = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit(15000)) {
        $process.Kill()
        throw "Timed out: $Script"
    }
    $output = $stdout.GetAwaiter().GetResult() + $stderr.GetAwaiter().GetResult()
    if ($output) { Write-Output $output.TrimEnd() }
    if ($process.ExitCode -ne 0) { throw "AHK exited $($process.ExitCode): $Script" }
    if ($Validate) { Write-Output "PASS: syntax $([IO.Path]::GetFileName($Script))" }
    $process.Dispose()
}

foreach ($name in @('InputTip.ahk', 'InputTip.updater.ahk', 'InputTip.JAB.JetBrains.ahk')) {
    Invoke-Ahk (Join-Path $repo "src\$name") -Validate
}
Invoke-Ahk (Join-Path $PSScriptRoot 'chinese-script.ahk')
$fixtureDir = Join-Path ([IO.Path]::GetTempPath()) ('InputTip-tests-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $fixtureDir | Out-Null
Invoke-Ahk (Join-Path $PSScriptRoot 'rules.ahk') ('"' + (Join-Path $fixtureDir 'config.ini') + '"')
Invoke-Ahk (Join-Path $PSScriptRoot 'ui-smoke.ahk') ('"' + (Join-Path $fixtureDir 'ui.ini') + '"')
Write-Output "Fixture retained for inspection: $fixtureDir"
