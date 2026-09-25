# Rebuilds windows/runner/resources/app_icon.ico from the app icon SVG.
#
#   pwsh windows\packaging\make-app-icon.ps1
#
# That .ico is what Windows shows for the window, the taskbar button, Alt+Tab
# and the .exe. Run this whenever assets/app-icon/tide-app-icon.svg changes —
# the .ico is a build artifact that happens to be checked in (the resource
# compiler can't read SVG).
#
# 🔑 Not the tray icon. assets/tray/tide-tray.ico stops at 32px because that
# is all the notification area ever asks for; the taskbar asks for up to 256
# and would upscale that into a smudge.
#
# Rasterising is done by headless Edge because it is the only SVG renderer
# certain to be on a Windows dev machine. One screenshot per size, straight
# to PNG, and the PNGs are packed into the .ico as-is (Vista and later read
# PNG-compressed icon entries).

$ErrorActionPreference = 'Stop'

$repo = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$svg = Join-Path $repo 'assets\app-icon\tide-app-icon.svg'
$outIco = Join-Path $repo 'windows\runner\resources\app_icon.ico'
$work = Join-Path $repo '.dist-scratch\icon'

$edge = @(
  "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
  "C:\Program Files\Microsoft\Edge\Application\msedge.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $edge) { throw "Microsoft Edge not found — needed to rasterise the SVG." }

New-Item -ItemType Directory -Force -Path $work | Out-Null
New-Item -ItemType Directory -Force -Path (Split-Path $outIco) | Out-Null

# The SVG is dropped into a page that sizes it to exactly the pixels wanted.
# `--window-size` and the captured image are 1:1 here, whatever the display
# scaling of the machine running this.
$inner = (Get-Content $svg -Raw) -replace '<\?xml[^>]*\?>', ''
$page = @"
<!doctype html><html><head><meta charset="utf-8"><style>
html,body{margin:0;padding:0;background:transparent;overflow:hidden}
svg{display:block}
</style></head><body>
$inner
<script>
var px = parseInt((location.hash || '#256').slice(1), 10);
var s = document.querySelector('svg');
s.removeAttribute('width'); s.removeAttribute('height');
s.style.width = px + 'px'; s.style.height = px + 'px';
</script>
</body></html>
"@
$html = Join-Path $work 'wrapper.html'
Set-Content -Path $html -Value $page -Encoding utf8

$sizes = 16, 20, 24, 32, 40, 48, 64, 128, 256
$url = "file:///$(($html -replace '\\','/'))"
foreach ($s in $sizes) {
  $png = Join-Path $work "icon-$s.png"
  if (Test-Path $png) { Remove-Item $png -Force }
  # No stderr redirection: Edge reports "N bytes written to file" on stderr,
  # and redirecting a native command's stderr in Windows PowerShell wraps
  # every line in an ErrorRecord, which $ErrorActionPreference turns into a
  # failure even though the screenshot was written.
  & $edge --headless --disable-gpu --hide-scrollbars --default-background-color=00000000 `
    --screenshot="$png" --window-size="$s,$s" "$url#$s" | Out-Null
  if (-not (Test-Path $png)) { throw "Edge produced no image for ${s}px." }
}

# ICONDIR (6 bytes) + one 16-byte ICONDIRENTRY per size + the PNGs.
$streams = @{}
foreach ($s in $sizes) { $streams[$s] = [IO.File]::ReadAllBytes((Join-Path $work "icon-$s.png")) }

$out = New-Object IO.MemoryStream
$w = New-Object IO.BinaryWriter($out)
$w.Write([uint16]0); $w.Write([uint16]1); $w.Write([uint16]$sizes.Count)
$offset = 6 + 16 * $sizes.Count
foreach ($s in $sizes) {
  $bytes = $streams[$s]
  # 256 is written as 0: the field is one byte wide.
  $dim = if ($s -eq 256) { 0 } else { $s }
  $w.Write([byte]$dim); $w.Write([byte]$dim); $w.Write([byte]0); $w.Write([byte]0)
  $w.Write([uint16]1); $w.Write([uint16]32)
  $w.Write([uint32]$bytes.Length); $w.Write([uint32]$offset)
  $offset += $bytes.Length
}
foreach ($s in $sizes) { $w.Write($streams[$s]) }
$w.Flush()
[IO.File]::WriteAllBytes($outIco, $out.ToArray())
$w.Dispose()

"{0} — {1:N0} bytes, {2} sizes: {3}" -f $outIco, (Get-Item $outIco).Length, $sizes.Count, ($sizes -join ', ')
