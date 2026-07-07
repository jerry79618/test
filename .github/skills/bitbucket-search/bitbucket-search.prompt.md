---
description: "Search LINE Bank Bitbucket source code by class name, function name, or keyword across repos"
name: "Bitbucket-Search"
argument-hint: "class or function name (e.g. AtmBalInqrBiz, SZPYF031031, processTransfer)"
agent: "agent"
tools: ["run_in_terminal"]
---

Search LINE Bank Bitbucket source code for: **$input**

**Immediately execute the following steps using `run_in_terminal` without asking for confirmation.**

## Environment

- OS: Windows (PowerShell 5+)
- Auth Token: `"BBDC-NjU4MDk3MjYzNzM1OhQ2351kGsa7jHrUNQ5Hdig/v/VA"`
- Base URL: `https://bitbucket.linebank.com.tw/rest/api/1.0`
- Project: `LBTWCBCBK`
- **Use Invoke-WebRequest pattern** — Must bypass corporate proxy & skip SSL certificate check

## PowerShell Base Pattern (use for every API call)
```powershell
# Step 1: Clear proxy environment variables (to bypass corporate proxy)
$env:HTTP_PROXY = $null
$env:HTTPS_PROXY = $null

# Step 2: Enable TLS 1.2+
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12

# Step 3: Prepare authorization header
$headers = @{"Authorization" = "Bearer "BBDC-NjU4MDk3MjYzNzM1OhQ2351kGsa7jHrUNQ5Hdig/v/VA""}

# Step 4: Execute API call (with -SkipCertificateCheck to bypass SSL validation)
$response = Invoke-WebRequest -Uri "<URL>" -Headers $headers -UseBasicParsing -SkipCertificateCheck

# Step 5: Parse JSON response
$result = $response.Content | ConvertFrom-Json
```

## Steps (execute immediately)

### Step 1: Code Search (Bitbucket built-in search)
```powershell
$env:HTTP_PROXY = $null; $env:HTTPS_PROXY = $null
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12
$headers = @{"Authorization" = "Bearer "BBDC-NjU4MDk3MjYzNzM1OhQ2351kGsa7jHrUNQ5Hdig/v/VA""}
$r = (Invoke-WebRequest -Uri "https://bitbucket.linebank.com.tw/rest/search/1.0/search?query=<KEYWORD>&entities=code&limit=20" -Headers $headers -UseBasicParsing -SkipCertificateCheck).Content | ConvertFrom-Json
$r.code.values | ForEach-Object { Write-Host $_.file.path '|' $_.repository.slug }
```

> If search API returns 404/error, fall back to Step 2.

### Step 2: List all repos in LBTWCBCBK (if search unavailable)
```powershell
$env:HTTP_PROXY = $null; $env:HTTPS_PROXY = $null
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12
$headers = @{"Authorization" = "Bearer "BBDC-NjU4MDk3MjYzNzM1OhQ2351kGsa7jHrUNQ5Hdig/v/VA""}
$r = (Invoke-WebRequest -Uri "https://bitbucket.linebank.com.tw/rest/api/1.0/projects/LBTWCBCBK/repos?limit=50" -Headers $headers -UseBasicParsing -SkipCertificateCheck).Content | ConvertFrom-Json
$r.values | ForEach-Object { Write-Host $_.slug }
```

### Step 3: Find matching Java files in a specific repo (search by filename)
```powershell
$env:HTTP_PROXY = $null; $env:HTTPS_PROXY = $null
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12
$headers = @{"Authorization" = "Bearer "BBDC-NjU4MDk3MjYzNzM1OhQ2351kGsa7jHrUNQ5Hdig/v/VA""}
$r = (Invoke-WebRequest -Uri "https://bitbucket.linebank.com.tw/rest/api/1.0/projects/LBTWCBCBK/repos/<REPO>/files?limit=1000&at=refs/heads/main" -Headers $headers -UseBasicParsing -SkipCertificateCheck).Content | ConvertFrom-Json
$r.values | Where-Object { $_ -like "*<KEYWORD>*" } | ForEach-Object { Write-Host $_ }
```

### Step 4: Fetch raw source code of a file
```powershell
$env:HTTP_PROXY = $null; $env:HTTPS_PROXY = $null
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12
$headers = @{"Authorization" = "Bearer "BBDC-NjU4MDk3MjYzNzM1OhQ2351kGsa7jHrUNQ5Hdig/v/VA""}
(Invoke-WebRequest -Uri "https://bitbucket.linebank.com.tw/rest/api/1.0/projects/LBTWCBCBK/repos/<REPO>/raw/<FILE_PATH>" -Headers $headers -UseBasicParsing -SkipCertificateCheck).Content
```

### Step 5: Search inside file content for function/method name
After fetching raw source, use PowerShell to find relevant lines:
```powershell
$code = "<raw source from step 4>"; $lines = $code -split "`n"; $lines | Select-String -Pattern "<KEYWORD>" | ForEach-Object { Write-Host $_.LineNumber ':' $_.Line }
```

## Search Strategy

1. Try **code search API** (Step 1) first — fastest, searches all repos at once
2. If unavailable, **identify likely repo** from keyword naming pattern:
   - `SZPY*` → look in repos with `cbzpy`, `zpy` in slug
   - `CBK*` / `CCB*` → look in `cbbxp`, `cbbst`, `cbcbk` repos
   - Class name → match filename (e.g. `AtmBalInqrBiz` → `AtmBalInqrBiz.java`)
3. Fetch raw source of matched files
4. Extract and analyze relevant methods/classes

## Output Format

Return a structured Mandarin summary:

```
## `$input` 原始碼分析

### 所在位置
- Repo: `<repo-slug>`
- 檔案路徑: `<path>`
- Bitbucket URL: https://bitbucket.linebank.com.tw/projects/LBTWCBCBK/repos/<repo>/browse/<path>

### 類別 / 方法摘要
...

### 主要邏輯
...

### 呼叫的外部服務 / Interface
...
```
