$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$releaseDir = Join-Path $projectRoot "release"
$launcherDir = Join-Path $projectRoot "launcher"
$packagePath = Join-Path $launcherDir "DeltaMap.package.zip"
$responsePath = Join-Path $launcherDir "build.rsp"
$outputPath = Join-Path $releaseDir "DeltaMap.exe"
$iconPath = Join-Path $launcherDir "DeltaMap.ico"
$compiler = "$env:WINDIR\Microsoft.NET\Framework64\v4.0.30319\csc.exe"

if (-not (Test-Path $compiler)) {
    $compiler = "$env:WINDIR\Microsoft.NET\Framework\v4.0.30319\csc.exe"
}
if (-not (Test-Path $compiler)) {
    throw "Windows C# compiler was not found. Enable .NET Framework 4.x."
}

New-Item -ItemType Directory -Force -Path $releaseDir | Out-Null
& (Join-Path $projectRoot "tools\generate-app-icon.ps1") -ProjectRoot $projectRoot
if (Test-Path $packagePath) { Remove-Item -LiteralPath $packagePath -Force }
if (Test-Path $outputPath) { Remove-Item -LiteralPath $outputPath -Force }

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::Open($packagePath, [IO.Compression.ZipArchiveMode]::Create)
try {
    $webFiles = @(
        (Join-Path $projectRoot "index.html")
        (Join-Path $projectRoot "app.js")
        (Join-Path $projectRoot "styles.css")
        (Join-Path $projectRoot "marker-tools.css")
        (Join-Path $projectRoot "measure.css")
        (Join-Path $projectRoot "callouts.css")
        (Join-Path $projectRoot "gadgets.css")
        (Join-Path $projectRoot "collaboration.css")
        (Join-Path $projectRoot "collaboration.js")
    )
    $files = @(Get-Item -LiteralPath $webFiles)
    $files += @(Get-ChildItem (Join-Path $projectRoot "assets") -File -Recurse)
    foreach ($file in $files) {
        $relative = $file.FullName.Substring($projectRoot.Length + 1).Replace("\", "/")
        [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $file.FullName, $relative, [IO.Compression.CompressionLevel]::Optimal) | Out-Null
    }
}
finally {
    $zip.Dispose()
}

$program = Join-Path $launcherDir "Program.cs"
$frameworkDir = Split-Path -Parent $compiler
$references = @(
    (Join-Path $frameworkDir "System.IO.Compression.dll")
    (Join-Path $frameworkDir "System.IO.Compression.FileSystem.dll")
    (Join-Path $frameworkDir "System.Windows.Forms.dll")
)
$arguments = @(
    "/nologo",
    "/target:winexe",
    "/platform:anycpu",
    "/optimize+",
    "/win32icon:`"$iconPath`"",
    "/out:`"$outputPath`"",
    ('/resource:"{0}",DeltaMap.package.zip' -f $packagePath)
)
$arguments += $references | ForEach-Object { "/reference:`"$_`"" }
$arguments += "`"$program`""
[IO.File]::WriteAllLines($responsePath, $arguments, [Text.UTF8Encoding]::new($false))

& $compiler "@$responsePath"
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $outputPath)) {
    throw "DeltaMap.exe build failed."
}

Remove-Item -LiteralPath $packagePath, $responsePath -Force
$size = [math]::Round((Get-Item $outputPath).Length / 1MB, 1)
Write-Host ""
Write-Host "Build complete: $outputPath ($size MB)" -ForegroundColor Green
Write-Host "The EXE contains all maps, icons, scripts, and styles."
