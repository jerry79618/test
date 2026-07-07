---
description: "Search LINE Bank internal Confluence Wiki by keyword and return relevant page summaries"
name: "Wiki-Search"
argument-hint: "search keyword (e.g. SZPYF031031, 約定帳戶轉帳, 數三帳戶限額)"
agent: "agent"
tools: ["run_in_terminal"]
---

Search the LINE Bank internal Confluence Wiki for: **$input**

## Environment

- OS: Windows (cmd)
- Auth: `Bearer "%WIKI_PAT%"`
- Base URL: `https://wiki.linebank.com.tw/rest/api`
- curl flags: `-k --max-time 15` (skip SSL verify, internal network)
- **Always save to file first (`-o result.json`), then parse — never pipe directly (output may be empty in cmd)**

## Steps

1. **Title search** — find pages whose title contains the keyword (most precise)
2. **Full-text search** — if title search returns nothing or too few results, broaden to body text
3. **Fetch top relevant pages** — download body.storage of the 2–3 most relevant pages
4. **Parse & summarize** — strip HTML tags, extract plain text, then produce a structured summary

## API Commands

### 1. Title search
```cmd
curl -k --max-time 15 -H "Authorization: Bearer "%WIKI_PAT%"" ^
  "https://wiki.linebank.com.tw/rest/api/content/search?cql=title~%22<KEYWORD_ENCODED>%22+AND+type%3Dpage&limit=10" ^
  -o search_title.json -w "HTTP:%{http_code}\n"
```

### 2. Full-text search
```cmd
curl -k --max-time 15 -H "Authorization: Bearer "%WIKI_PAT%"" ^
  "https://wiki.linebank.com.tw/rest/api/content/search?cql=text~%22<KEYWORD_ENCODED>%22+AND+type%3Dpage&limit=10" ^
  -o search_text.json -w "HTTP:%{http_code}\n"
```

### 3. List search results
```cmd
powershell -Command "chcp 65001 | Out-Null; $c=Get-Content search_title.json -Encoding UTF8 -Raw | ConvertFrom-Json; $c.results | ForEach-Object { Write-Host $_.id '|' $_.title }"
```

### 4. Fetch page body
```cmd
curl -k --max-time 15 -H "Authorization: Bearer "%WIKI_PAT%"" ^
  "https://wiki.linebank.com.tw/rest/api/content/<PAGE_ID>?expand=body.storage" ^
  -o page_<PAGE_ID>.json -w "HTTP:%{http_code}\n"
```

### 5. Extract plain text from page
```cmd
powershell -Command "chcp 65001 | Out-Null; $body=(Get-Content page_<PAGE_ID>.json -Encoding UTF8 -Raw | ConvertFrom-Json).body.storage.value; $text=[regex]::Replace($body,'<[^>]+>',''); $text=[regex]::Replace($text,'&nbsp;',' '); $text=[regex]::Replace($text,'&amp;','&'); $text=$text -replace '\s+',' '; $text.Substring(0,[Math]::Min(6000,$text.Length))"
```

> **Tip:** URL-encode Chinese keywords before using in CQL. e.g. 約定帳戶 → `%E7%B4%84%E5%AE%9A%E5%B8%B3%E6%88%B6`

## Search Strategy

- Start with **title search** for precise matches
- If < 3 results, run **full-text search** as fallback
- Fetch body of the **most relevant 2–3 pages** (prefer: FAQ, BRD, PRD, Feature definition pages)
- Cross-reference multiple pages if the topic spans policies + technical specs

## Output Format

Return a structured Mandarin summary with:

```
## {Topic} 摘要

### 1. {Section}
...

### 2. {Section}
...

---
*資料來源：wiki `{Page Title}`（頁面 ID: {ID}）*
```

Include:
- Key rules / policies (limits, conditions, eligibility)
- Tables for limit amounts or comparison data
- Any warnings or edge cases highlighted in original page
- Wiki page ID and title as source citation
