---
description: "從一個或多個 Confluence Wiki URL 與/或 JIRA issue URL 擷取需求內容，並抽取交易代碼（txCd）。"
name: "Fetch-Requirement"
argument-hint: "可輸入一個或多個 URL。支援分隔符號：換行、逗號、分號、或直線。範例：https://jira.../CEPRJ-1, https://wiki.../pages/123"
agent: "agent"
tools: ["run_in_terminal"]
---

從 URL 輸入擷取需求內容：**$input**

## 環境

- OS: Windows (PowerShell)
- JIRA Auth: `Bearer "$env:JIRA_PAT"`
- JIRA Base URL: `https://jira.linebank.com.tw/rest/api/2`
- Wiki Auth: `Bearer "$env:WIKI_PAT"`
- Wiki Base URL: `https://wiki.linebank.com.tw/rest/api`
- curl flags: `-k --max-time 15 --noproxy "*"`（略過 SSL 驗證，繞過 proxy）
- ⚠️ Token 由環境變數 `JIRA_PAT` / `WIKI_PAT` 提供（系統環境變數或 `@cerberus-init` 引導設定）。**禁止把 token 寫死在本檔或任何版控檔案**；未設定時提示使用者先設定再重試

## 輸入規則

- 第一個輸入可為單一或多個 URL。
- 接受分隔符號：換行、逗號、分號、直線。
- 支援主機：
  - `jira.linebank.com.tw` with `/browse/`
  - `wiki.linebank.com.tw`
- 不支援的主機應以 warning 略過，不可讓整體流程失敗。
- **⛔ 嚴格邊界：只處理 `$input` 明確提供的 URL。不得追蹤、抓取或探索擷取內容中的任何內嵌連結、相關 issue、子頁面、關聯 JIRA 或 wiki 參照。若處理完提供 URL 後仍找不到交易代碼，請輸出空的 `txCd_list: []` 並停止，不可再做進一步探索。**

## 步驟

### 0. 解析多 URL 輸入

```powershell
$rawInput = @"
$input
"@

$urls = $rawInput -split "[\r\n,;|]+" |
    ForEach-Object { $_.Trim() } |
    Where-Object { $_ -match '^https?://' }

if (-not $urls -or $urls.Count -eq 0) {
    Write-Error "No valid URL found in input."
    exit 1
}

Write-Host "Total URLs: $($urls.Count)"
$urls | ForEach-Object { Write-Host "- $_" }
```

### 0.5. 從 config.md 載入 txCd 掃描樣式

```powershell
chcp 65001 | Out-Null
$configPath = ".cucb/config.md"
$txcdPattern = 'SZ[A-Z0-9]{9}'  # fallback default: CBK 11-char only
$txcdValidationPattern = "^($txcdPattern)$"  # fallback validation pattern

if (Test-Path $configPath) {
    $configContent = Get-Content $configPath -Raw -Encoding UTF8
    # Extract regex patterns from ALL 掃描規則 tables (txCd + 批次 + any future tables):
    # Matches lines of the form: | SystemName | `<regex>` | ... |
    $patternMatches = [regex]::Matches($configContent, '\|\s*\w+\s*\|\s*`([^`]+)`\s*\|')
    $patterns = $patternMatches | ForEach-Object { $_.Groups[1].Value } | Where-Object { $_ -ne "" }
    if ($patterns.Count -gt 0) {
        $txcdPattern = "($($patterns -join '|'))"
        $txcdValidationPattern = "^($($patterns -join '|'))$"
        Write-Host "Loaded txCd patterns from config: $txcdPattern"
    } else {
        Write-Warning "No txCd patterns found in config.md — using fallback: $txcdPattern"
    }
} else {
    Write-Warning "config.md not found — using fallback pattern: $txcdPattern"
}
```

### 1. 逐一處理 URL

```powershell
$itemResults = @()

foreach ($currentUrl in $urls) {
    if ($currentUrl -match "jira\.linebank\.com\.tw/browse/") {
        Write-Host "Processing JIRA: $currentUrl"
        # Run Path A
    }
    elseif ($currentUrl -match "wiki\.linebank\.com\.tw") {
        Write-Host "Processing Wiki: $currentUrl"
        # Run Path B
    }
    else {
        Write-Warning "Unsupported host, skipped: $currentUrl"
    }
}
```

---

## 路徑 A - JIRA URL（每個 URL）

### A1. 擷取 Issue Key

```powershell
$issueKey = if ($currentUrl -match "/browse/([A-Z]+-\d+)") { $matches[1] } else { "" }
if (-not $issueKey) { Write-Warning "Could not extract JIRA issue key from: $currentUrl"; continue }
Write-Host "Issue Key: $issueKey"
```

### A2. 取得 JIRA Issue

```powershell
curl -k --max-time 15 --noproxy "*" `
  -H "Authorization: Bearer $env:JIRA_PAT" `
  "https://jira.linebank.com.tw/rest/api/2/issue/$issueKey" `
  -o "jira_$issueKey.json" -w "HTTP:%{http_code}\n"
```

### A3. 解析並儲存來源內容

```powershell
chcp 65001 | Out-Null
$jiraContent = Get-Content "jira_$issueKey.json" -Encoding UTF8 -Raw | ConvertFrom-Json
$summary     = $jiraContent.fields.summary
$description = $jiraContent.fields.description

$text        = [regex]::Replace($description, '\{[^}]+\}', ' ')
$text        = $text -replace '\s+', ' '
$text        = "# $summary`n`n$text"

$sourceId    = $issueKey
$sourceTitle = $summary

$sourceDir = ".cucb/requirement-specs/sources"
if (-not (Test-Path $sourceDir)) { New-Item -ItemType Directory -Path $sourceDir -Force | Out-Null }
$sourcePath = Join-Path $sourceDir "$sourceId.md"
Set-Content -Path $sourcePath -Value $text -Encoding UTF8

$txcds = [regex]::Matches($description, $txcdPattern) |
    ForEach-Object { $_.Value } |
    Where-Object { $_ -match $txcdValidationPattern } |
    Sort-Object -Unique

# Extract Java class name hints (suffix-based: matches CamelCase identifiers ending with known Java class suffixes)
$classHintPattern = '\b[A-Z][a-zA-Z]{5,}(?:Svc|BizProc|Ctrl|Mgr|Util|Helper|Impl|Enum|Repository|Config|Dao)\b'
$classHints = [regex]::Matches($description, $classHintPattern) | ForEach-Object { $_.Value } | Sort-Object -Unique
if ($classHints.Count -gt 0) { Write-Host "💡 偵測到 Class hints（JIRA）：$($classHints -join ', ')" }

$itemResults += [PSCustomObject]@{
    requirement_id = $sourceId
    page_title     = $sourceTitle
    source_type    = "JIRA"
    source_url     = $currentUrl
    source_path    = $sourcePath.Replace('\\', '/')
    txCd_list      = @($txcds)
    class_hints    = @($classHints)
}

Remove-Item "jira_$issueKey.json" -ErrorAction SilentlyContinue
```

---

## 路徑 B - Confluence Wiki URL（每個 URL）

### B1. 解析 pageId

```powershell
chcp 65001 | Out-Null
$resolvedPageId = ""

if ($currentUrl -match "pageId=(\d+)")      { $resolvedPageId = $matches[1] }
elseif ($currentUrl -match "/pages/(\d+)/") { $resolvedPageId = $matches[1] }
else {
    $redirectHeaders = curl -k --max-time 15 --noproxy "*" -s -D - -o NUL -L `
        -H "Authorization: Bearer $env:WIKI_PAT" `
        $currentUrl 2>&1 | Out-String
    if ($redirectHeaders -match "/pages/(\d+)/")        { $resolvedPageId = $matches[1] }
    elseif ($redirectHeaders -match "pageId=(\d+)")     { $resolvedPageId = $matches[1] }
}

if (-not $resolvedPageId) { Write-Warning "Could not resolve pageId from: $currentUrl"; continue }
Write-Host "pageId: $resolvedPageId"
```

### B2. 取得並解析頁面內容

```powershell
curl -k --max-time 15 --noproxy "*" `
  -H "Authorization: Bearer $env:WIKI_PAT" `
  "https://wiki.linebank.com.tw/rest/api/content/$resolvedPageId?expand=body.storage,title" `
  -o "page_$resolvedPageId.json" -w "HTTP:%{http_code}\n"

chcp 65001 | Out-Null
$pageId      = $resolvedPageId
$pageContent = Get-Content "page_$pageId.json" -Encoding UTF8 -Raw | ConvertFrom-Json
$sourceTitle = $pageContent.title
$body        = $pageContent.body.storage.value
$text        = [regex]::Replace($body, '<[^>]+>', ' ')
$text        = [System.Net.WebUtility]::HtmlDecode($text)
$text        = $text -replace '\s+', ' '

$sourceDir  = ".cucb/requirement-specs/sources"
if (-not (Test-Path $sourceDir)) { New-Item -ItemType Directory -Path $sourceDir -Force | Out-Null }
$sourcePath = Join-Path $sourceDir "$pageId.md"
Set-Content -Path $sourcePath -Value $text -Encoding UTF8

$txcds = [regex]::Matches($text, $txcdPattern) |
    ForEach-Object { $_.Value } |
    Where-Object { $_ -match $txcdValidationPattern } |
    Sort-Object -Unique

# Extract Java class name hints (suffix-based: matches CamelCase identifiers ending with known Java class suffixes)
$classHintPattern = '\b[A-Z][a-zA-Z]{5,}(?:Svc|BizProc|Ctrl|Mgr|Util|Helper|Impl|Enum|Repository|Config|Dao)\b'
$classHints = [regex]::Matches($text, $classHintPattern) | ForEach-Object { $_.Value } | Sort-Object -Unique
if ($classHints.Count -gt 0) { Write-Host "💡 偵測到 Class hints（Wiki）：$($classHints -join ', ')" }

$itemResults += [PSCustomObject]@{
    requirement_id = $pageId
    page_title     = $sourceTitle
    source_type    = "WIKI"
    source_url     = $currentUrl
    source_path    = $sourcePath.Replace('\\', '/')
    txCd_list      = @($txcds)
    class_hints    = @($classHints)
}

Remove-Item "page_$pageId.json" -ErrorAction SilentlyContinue
```

---

## 共通步驟（所有 URL）

### C1. 合併 txCd 清單

```powershell
$allTxcds = @()
foreach ($it in $itemResults) {
    if ($it.txCd_list) { $allTxcds += $it.txCd_list }
}
$txcds = $allTxcds | Where-Object { $_ -and $_.Trim() -ne "" } | Sort-Object -Unique

if ($txcds.Count -eq 0) {
    Write-Warning "⚠️ 未在需求文件中找到任何交易代碼，後續 P2 將進入補件流程（Q1 Block）。"
} else {
    Write-Host "✅ 找到交易代碼：$($txcds -join ', ')"
}

# Merge class hints across all items
$allClassHints = @()
foreach ($it in $itemResults) {
    if ($it.class_hints) { $allClassHints += $it.class_hints }
}
$mergedClassHints = $allClassHints | Where-Object { $_ -and $_.Trim() -ne "" } | Sort-Object -Unique
if ($mergedClassHints.Count -gt 0) {
    Write-Host "💡 合併後 Class hints：$($mergedClassHints -join ', ')"
} else {
    Write-Host "ℹ️ 未偵測到 Class hints（需求文件中無符合 Java 命名慣例的 Class 識別碼）"
}
```

### C2. 輸出整合 JSON

```powershell
chcp 65001 | Out-Null

$primary = $itemResults | Select-Object -First 1
if (-not $primary) {
    Write-Error "No supported URL was processed successfully."
    exit 1
}

$output = @{
    requirement_id = $primary.requirement_id
    page_title     = $primary.page_title
    env            = "dev"
    source_path    = $primary.source_path
    txCd_list      = $txcds
    class_hints    = $mergedClassHints
    api_spec_paths = @()
    requirements   = @($itemResults)
}

Write-Host "SKILL_OUTPUT:$($output | ConvertTo-Json -Depth 6 -Compress)"
Write-Host "Processed URLs: $($itemResults.Count)"
Write-Host "Merged txCd count: $($txcds.Count)"
Write-Host "Merged class_hints count: $($mergedClassHints.Count)"
```
