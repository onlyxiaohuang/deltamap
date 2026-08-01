param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^BV[0-9A-Za-z]+$')]
    [string]$Bvid,

    [ValidateRange(1, 100)]
    [int]$SampleCount = 24,

    [string]$OutputDir = "",

    [int]$Seed = 0
)

$ErrorActionPreference = "Stop"
$headers = @{
    "User-Agent" = "Mozilla/5.0"
    "Referer" = "https://www.bilibili.com/video/$Bvid/"
}

if (-not $OutputDir) {
    $OutputDir = Join-Path (Get-Location) ("storyboard-" + $Bvid)
}
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

$view = Invoke-RestMethod -Uri ("https://api.bilibili.com/x/web-interface/view?bvid=" + $Bvid) -Headers $headers
if ($view.code -ne 0) { throw ("Unable to read video metadata: " + $view.message) }
$cid = $view.data.pages[0].cid
$shot = Invoke-RestMethod -Uri ("https://api.bilibili.com/x/player/videoshot?bvid=" + $Bvid + "&cid=" + $cid + "&index=1") -Headers $headers
if ($shot.code -ne 0 -or -not $shot.data.image) { throw "This video has no public storyboard." }

$frameCount = $shot.data.index.Count
$count = [Math]::Min($SampleCount, $frameCount)
$random = if ($Seed) { New-Object Random($Seed) } else { New-Object Random }
$selected = New-Object 'System.Collections.Generic.HashSet[int]'
$selected.Add(0) | Out-Null
if ($frameCount -gt 1) { $selected.Add($frameCount - 1) | Out-Null }
while ($selected.Count -lt $count) { $selected.Add($random.Next(0, $frameCount)) | Out-Null }
$indices = @($selected) | Sort-Object

Add-Type -AssemblyName System.Drawing
$sheetCache = @{}
$frames = @()
foreach ($index in $indices) {
    $sheetIndex = [Math]::Floor($index / 100)
    $cellIndex = $index % 100
    if (-not $sheetCache.ContainsKey($sheetIndex)) {
        $imageUrl = [string]$shot.data.image[$sheetIndex]
        if ($imageUrl.StartsWith("//")) { $imageUrl = "https:" + $imageUrl }
        $sheetPath = Join-Path $OutputDir ("sheet-" + ($sheetIndex + 1).ToString("0000") + ".jpg")
        Invoke-WebRequest -Uri $imageUrl -Headers $headers -OutFile $sheetPath
        $sheetCache[$sheetIndex] = $sheetPath
    }

    $bitmap = [Drawing.Bitmap]::FromFile($sheetCache[$sheetIndex])
    try {
        $x = ($cellIndex % [int]$shot.data.img_x_len) * [int]$shot.data.img_x_size
        $y = [Math]::Floor($cellIndex / [int]$shot.data.img_x_len) * [int]$shot.data.img_y_size
        $rectangle = New-Object Drawing.Rectangle($x, $y, [int]$shot.data.img_x_size, [int]$shot.data.img_y_size)
        $crop = $bitmap.Clone($rectangle, $bitmap.PixelFormat)
        try {
            $seconds = [int]$shot.data.index[$index]
            $fileName = "frame-{0:0000}-{1:000000}s.jpg" -f $index, $seconds
            $framePath = Join-Path $OutputDir $fileName
            $crop.Save($framePath, [Drawing.Imaging.ImageFormat]::Jpeg)
            $frames += [ordered]@{ index = $index; seconds = $seconds; file = $fileName }
        }
        finally { $crop.Dispose() }
    }
    finally { $bitmap.Dispose() }
}

$manifest = [ordered]@{
    schema = "deltamap-storyboard-sample/v1"
    bvid = $Bvid
    cid = $cid
    title = $view.data.title
    owner = $view.data.owner.name
    ownerMid = [string]$view.data.owner.mid
    duration = [int]$view.data.duration
    sampledAt = (Get-Date).ToString("o")
    sampleCount = $frames.Count
    fullVideoDownloaded = $false
    frames = $frames
}
$manifest | ConvertTo-Json -Depth 5 | Set-Content -Encoding UTF8 (Join-Path $OutputDir "manifest.json")

Write-Host ("Sampled {0} frames without downloading the full video." -f $frames.Count) -ForegroundColor Green
Write-Host ("Output: " + (Resolve-Path $OutputDir))
