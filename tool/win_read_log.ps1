param(
  [int]$Tail = 50,
  # Default log path: getApplicationSupportDirectory() on Windows resolves to
  # %APPDATA%\<OrgName>\<AppName> — for this app that is FinanceCopilot\FinanceCopilot,
  # NOT the net.bazzani.financecopilot bundle id. Override with -LogPath if needed.
  [string]$LogPath = "$env:APPDATA\FinanceCopilot\FinanceCopilot\app.log",
  [string]$OutPath = 'C:\fc_applog.txt'
)
# Read a log file that the running app holds open for writing.
# Get-Content returns nothing on such a file; open with FileShare.ReadWrite to
# share the live handle, then emit the last $Tail lines to $OutPath so it can be
# retrieved with `utmctl file pull`.
#
# NOTE: when launched via `utmctl exec` this runs as nt authority\system, whose
# own %APPDATA% is NOT the interactive user's. Pass the interactive user's
# absolute path via -LogPath in that case, e.g.:
#   -LogPath 'C:\Users\<USER>\AppData\Roaming\FinanceCopilot\FinanceCopilot\app.log'
try {
  $fs = [System.IO.File]::Open($LogPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
  $sr = New-Object System.IO.StreamReader($fs)
  $all = $sr.ReadToEnd()
  $sr.Close()
  $fs.Close()
  $lines = $all -split "`r?`n"
  $start = [Math]::Max(0, $lines.Length - $Tail)
  $lines[$start..($lines.Length - 1)] | Set-Content -Encoding UTF8 $OutPath
  Add-Content $OutPath 'READLOG_DONE'
} catch {
  "READLOG_ERROR: $_" | Set-Content $OutPath
  Add-Content $OutPath 'READLOG_DONE'
}
