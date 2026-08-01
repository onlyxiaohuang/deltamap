param(
  [string]$Cookie = "",
  [int]$PageSize = 30
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$headers = @{
  "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/131 Safari/537.36"
  "Referer" = "https://www.bilibili.com/"
}
if ($Cookie) { $headers.Cookie = $Cookie }

$accounts = @(
  @{ mid = "3632320479234568"; name = "索菲亚堂主直播回放" },
  @{ mid = "3546610380311501"; name = "天堂的手比赛解说" }
)

function Get-TeamMatch([string]$text) {
  $pattern = '(?i)(?<a>[A-Z0-9一-龥]{2,16})(?:战队)?\s*(?:VS|V|对阵)\s*(?<b>[A-Z0-9一-龥]{2,16})(?:战队)?'
  $match = [regex]::Match($text, $pattern)
  if (-not $match.Success) { return $null }
  @($match.Groups['a'].Value.Trim(), $match.Groups['b'].Value.Trim())
}

function Get-Score([string]$text) {
  foreach ($pattern in @('(?i)(?:比分|最终|赛果)\D{0,8}(\d{1,2})\s*[:：-]\s*(\d{1,2})', '(?<!\d)(\d{1,2})\s*[:：]\s*(\d{1,2})(?!\d)')) {
    $match = [regex]::Match($text, $pattern)
    if ($match.Success) { return "$($match.Groups[1].Value):$($match.Groups[2].Value)" }
  }
  return $null
}

$videos = [System.Collections.Generic.List[object]]::new()
foreach ($account in $accounts) {
  $page = 1
  do {
    $url = "https://api.bilibili.com/x/space/arc/search?mid=$($account.mid)&pn=$page&ps=$PageSize&order=pubdate"
    try { $response = Invoke-RestMethod -Uri $url -Headers $headers }
    catch {
      throw "采集 $($account.name) 失败。B站返回风控错误时，请通过 -Cookie 传入浏览器中 bilibili.com 的 Cookie。原始错误：$($_.Exception.Message)"
    }
    if ($response.code -ne 0) { throw "B站接口错误 $($response.code)：$($response.message)" }
    $items = @($response.data.list.vlist)
    foreach ($item in $items) {
      $teams = Get-TeamMatch $item.title
      if (-not $teams) { continue }
      $description = [string]$item.description
      try {
        $detail = Invoke-RestMethod -Uri "https://api.bilibili.com/x/web-interface/view?bvid=$($item.bvid)" -Headers $headers
        if ($detail.code -eq 0) { $description = [string]$detail.data.desc }
      } catch { }
      $score = Get-Score "$($item.title)`n$description"
      $published = [DateTimeOffset]::FromUnixTimeSeconds([long]$item.created).ToOffset([TimeSpan]::FromHours(8)).ToString('o')
      $videos.Add([ordered]@{
        bvid = $item.bvid
        title = $item.title
        publishedAt = $published
        account = $account.name
        accountMid = $account.mid
        teams = $teams
        score = $score
        url = "https://www.bilibili.com/video/$($item.bvid)/"
      })
    }
    $total = [int]$response.data.page.count
    $page++
    Start-Sleep -Milliseconds 450
  } while ((($page - 1) * $PageSize) -lt $total)
}

$unique = @($videos | Group-Object bvid | ForEach-Object { $_.Group[0] } | Sort-Object publishedAt -Descending)
$output = [ordered]@{
  schema = "deltamap-related-matches/v1"
  updatedAt = [DateTimeOffset]::Now.ToString('o')
  accounts = $accounts
  videos = $unique
}
$json = $output | ConvertTo-Json -Depth 8
$jsonPath = Join-Path $root "sources\related-matches.json"
$jsPath = Join-Path $root "sources\related-matches.js"
[IO.File]::WriteAllText($jsonPath, $json, [Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText($jsPath, "window.DELTAMAP_MATCHES=$json;", [Text.UTF8Encoding]::new($false))
Write-Host "已收集 $($unique.Count) 场包含队名对阵的投稿。"
Write-Host "页面数据：$jsPath"
