<#
  make-icon.ps1 — generate windows/LittlePup/app.ico from the shared macOS app icon.

  The Windows exe icon is built from the SAME art as the macOS app
  (LittlePup/Resources/Assets.xcassets/AppIcon.appiconset). ImageMagick isn't a
  dependency here, so the multi-resolution .ico is assembled by hand with
  System.Drawing: small sizes (16/32/48/64/128) as 32-bpp BMP/DIB entries and the
  256 px entry as PNG-in-ICO (the most shell-compatible mix).

  Re-run this whenever the macOS icon art changes:
    powershell -ExecutionPolicy Bypass -File windows/tools/make-icon.ps1
#>
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$root    = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)   # repo root (…/LittlePup)
$iconDir = Join-Path $root 'LittlePup\Resources\Assets.xcassets\AppIcon.appiconset'
$outIco  = Join-Path $PSScriptRoot '..\LittlePup\app.ico'
$outIco  = [System.IO.Path]::GetFullPath($outIco)

# Target size -> best native source PNG (exact size preferred; 48 is downscaled from 256).
$sources = [ordered]@{
  16  = 'icon_16x16.png'
  32  = 'icon_32x32.png'
  48  = 'icon_256x256.png'   # no native 48; nearest-neighbour downscale keeps pixels crisp
  64  = 'icon_32x32@2x.png'
  128 = 'icon_128x128.png'
  256 = 'icon_256x256.png'
}

# Render a source PNG to an exact-size 32bpp ARGB bitmap (nearest-neighbour, like IconRenderer.Scaled).
function Get-SizedBitmap([string]$path, [int]$size) {
  $src = [System.Drawing.Image]::FromFile($path)
  try {
    $bmp = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    try {
      $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
      $g.PixelOffsetMode   = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
      $g.DrawImage($src, 0, 0, $size, $size)
    } finally { $g.Dispose() }
    return $bmp
  } finally { $src.Dispose() }
}

# Encode a bitmap as a 32bpp bottom-up DIB (BITMAPINFOHEADER + BGRA pixels + zeroed AND mask).
function Get-DibBytes([System.Drawing.Bitmap]$bmp) {
  $w = $bmp.Width; $h = $bmp.Height
  $rect = New-Object System.Drawing.Rectangle(0, 0, $w, $h)
  $data = $bmp.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  try {
    $stride = $data.Stride
    $buf = New-Object byte[] ($stride * $h)
    [System.Runtime.InteropServices.Marshal]::Copy($data.Scan0, $buf, 0, $buf.Length)
  } finally { $bmp.UnlockBits($data) }

  $ms = New-Object System.IO.MemoryStream
  $bw = New-Object System.IO.BinaryWriter($ms)
  # BITMAPINFOHEADER — biHeight is doubled (XOR image + AND mask).
  $bw.Write([int]40); $bw.Write([int]$w); $bw.Write([int]($h * 2))
  $bw.Write([int16]1); $bw.Write([int16]32); $bw.Write([int]0)
  $bw.Write([int]0); $bw.Write([int]0); $bw.Write([int]0); $bw.Write([int]0); $bw.Write([int]0)
  # XOR pixels, bottom-up (GDI gives top-down rows, so emit them in reverse).
  for ($y = $h - 1; $y -ge 0; $y--) { $bw.Write($buf, $y * $stride, $w * 4) }
  # AND mask: 1bpp, rows padded to 32-bit; all-zero (alpha channel handles transparency).
  $maskRow = [math]::Floor((($w + 31) / 32)) * 4
  $bw.Write((New-Object byte[] ($maskRow * $h)), 0, ($maskRow * $h))
  $bw.Flush()
  return $ms.ToArray()
}

function Get-PngBytes([System.Drawing.Bitmap]$bmp) {
  $ms = New-Object System.IO.MemoryStream
  $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
  return $ms.ToArray()
}

# Build the per-size image payloads.
$entries = @()
foreach ($kv in $sources.GetEnumerator()) {
  $size = [int]$kv.Key
  $bmp = Get-SizedBitmap (Join-Path $iconDir $kv.Value) $size
  try {
    $bytes = if ($size -ge 256) { Get-PngBytes $bmp } else { Get-DibBytes $bmp }
    $entries += [pscustomobject]@{ Size = $size; Bytes = $bytes }
  } finally { $bmp.Dispose() }
}

# Assemble the .ico: ICONDIR + ICONDIRENTRY[] + concatenated image data.
$fs = New-Object System.IO.FileStream($outIco, [System.IO.FileMode]::Create)
$bw = New-Object System.IO.BinaryWriter($fs)
try {
  $bw.Write([int16]0); $bw.Write([int16]1); $bw.Write([int16]$entries.Count)   # reserved, type=1(icon), count
  $offset = 6 + (16 * $entries.Count)
  foreach ($e in $entries) {
    $dim = if ($e.Size -ge 256) { 0 } else { $e.Size }   # 0 means 256
    $bw.Write([byte]$dim); $bw.Write([byte]$dim)
    $bw.Write([byte]0); $bw.Write([byte]0)               # colors, reserved
    $bw.Write([int16]1); $bw.Write([int16]32)            # planes, bitcount
    $bw.Write([int]$e.Bytes.Length); $bw.Write([int]$offset)
    $offset += $e.Bytes.Length
  }
  foreach ($e in $entries) { $bw.Write($e.Bytes, 0, $e.Bytes.Length) }
  $bw.Flush()
} finally { $bw.Dispose(); $fs.Dispose() }

Write-Host "Wrote $outIco ($([math]::Round((Get-Item $outIco).Length / 1KB, 1)) KB, sizes: $($sources.Keys -join ', '))"
