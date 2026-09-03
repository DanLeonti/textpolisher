# Converts a source PNG into a multi-resolution .ico (PNG-compressed frames).
param(
    [Parameter(Mandatory = $true)][string]$Source,
    [Parameter(Mandatory = $true)][string]$Destination
)

Add-Type -AssemblyName System.Drawing

$sizes = @(16, 24, 32, 48, 64, 128, 256)
$src = [System.Drawing.Image]::FromFile((Resolve-Path $Source))

$pngStreams = @()
foreach ($size in $sizes) {
    $bmp = New-Object System.Drawing.Bitmap $size, $size
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.DrawImage($src, 0, 0, $size, $size)
    $g.Dispose()

    $ms = New-Object System.IO.MemoryStream
    $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    $pngStreams += , @{ Size = $size; Bytes = $ms.ToArray() }
    $ms.Dispose()
}
$src.Dispose()

$dir = Split-Path -Parent $Destination
if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

$fs = [System.IO.File]::Create((New-Item -ItemType File -Path $Destination -Force).FullName)
$bw = New-Object System.IO.BinaryWriter $fs

# ICONDIR
$bw.Write([UInt16]0)                    # reserved
$bw.Write([UInt16]1)                    # type = icon
$bw.Write([UInt16]$pngStreams.Count)    # image count

# Directory entries
$offset = 6 + (16 * $pngStreams.Count)
foreach ($img in $pngStreams) {
    $w = if ($img.Size -ge 256) { 0 } else { $img.Size }
    $bw.Write([byte]$w)                  # width
    $bw.Write([byte]$w)                  # height
    $bw.Write([byte]0)                   # palette
    $bw.Write([byte]0)                   # reserved
    $bw.Write([UInt16]1)                 # color planes
    $bw.Write([UInt16]32)                # bits per pixel
    $bw.Write([UInt32]$img.Bytes.Length) # size of image data
    $bw.Write([UInt32]$offset)           # offset
    $offset += $img.Bytes.Length
}

# Image data
foreach ($img in $pngStreams) {
    $bw.Write($img.Bytes)
}

$bw.Flush()
$bw.Close()
$fs.Close()

Write-Host "Wrote $Destination ($($pngStreams.Count) frames)"
