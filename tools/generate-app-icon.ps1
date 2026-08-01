param(
    [string]$ProjectRoot = (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
)

$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Drawing

$pngPath = Join-Path $ProjectRoot "assets\app-icon.png"
$icoPath = Join-Path $ProjectRoot "launcher\DeltaMap.ico"
$bitmap = New-Object Drawing.Bitmap 256, 256, ([Drawing.Imaging.PixelFormat]::Format32bppArgb)
$graphics = [Drawing.Graphics]::FromImage($bitmap)

try {
    $graphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.Clear([Drawing.Color]::Transparent)

    $shape = New-Object Drawing.Drawing2D.GraphicsPath
    $shape.AddArc(12, 12, 42, 42, 180, 90)
    $shape.AddArc(202, 12, 42, 42, 270, 90)
    $shape.AddArc(202, 202, 42, 42, 0, 90)
    $shape.AddArc(12, 202, 42, 42, 90, 90)
    $shape.CloseFigure()

    $graphics.FillPath((New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(255, 12, 15, 12))), $shape)
    $graphics.SetClip($shape)

    $gridPen = New-Object Drawing.Pen ([Drawing.Color]::FromArgb(32, 213, 242, 73)), 2
    foreach ($position in 48, 88, 128, 168, 208) {
        $graphics.DrawLine($gridPen, $position, 12, $position, 244)
        $graphics.DrawLine($gridPen, 12, $position, 244, $position)
    }

    $accent = [Drawing.Color]::FromArgb(255, 213, 242, 73)
    $accentPen = New-Object Drawing.Pen $accent, 18
    $accentPen.StartCap = [Drawing.Drawing2D.LineCap]::Round
    $accentPen.EndCap = [Drawing.Drawing2D.LineCap]::Round
    $accentPen.LineJoin = [Drawing.Drawing2D.LineJoin]::Round
    $graphics.DrawLines($accentPen, @(
        (New-Object Drawing.Point 62, 188),
        (New-Object Drawing.Point 126, 57),
        (New-Object Drawing.Point 195, 188),
        (New-Object Drawing.Point 88, 188),
        (New-Object Drawing.Point 126, 112),
        (New-Object Drawing.Point 159, 177)
    ))

    $routePen = New-Object Drawing.Pen ([Drawing.Color]::FromArgb(235, 242, 245, 238)), 7
    $routePen.DashStyle = [Drawing.Drawing2D.DashStyle]::Dash
    $graphics.DrawArc($routePen, 74, 77, 110, 92, 205, 235)
    $graphics.FillEllipse((New-Object Drawing.SolidBrush $accent), 172, 67, 22, 22)
    $graphics.ResetClip()

    $borderPen = New-Object Drawing.Pen ([Drawing.Color]::FromArgb(210, 213, 242, 73)), 5
    $graphics.DrawPath($borderPen, $shape)
    $bitmap.Save($pngPath, [Drawing.Imaging.ImageFormat]::Png)

    $memory = New-Object IO.MemoryStream
    $bitmap.Save($memory, [Drawing.Imaging.ImageFormat]::Png)
    $png = $memory.ToArray()
    $stream = [IO.File]::Create($icoPath)
    $writer = New-Object IO.BinaryWriter $stream
    try {
        $writer.Write([UInt16]0)
        $writer.Write([UInt16]1)
        $writer.Write([UInt16]1)
        $writer.Write([Byte]0)
        $writer.Write([Byte]0)
        $writer.Write([Byte]0)
        $writer.Write([Byte]0)
        $writer.Write([UInt16]1)
        $writer.Write([UInt16]32)
        $writer.Write([UInt32]$png.Length)
        $writer.Write([UInt32]22)
        $writer.Write($png)
    }
    finally {
        $writer.Dispose()
    }
}
finally {
    $graphics.Dispose()
    $bitmap.Dispose()
}

Write-Host "App icon generated: $icoPath" -ForegroundColor Green
