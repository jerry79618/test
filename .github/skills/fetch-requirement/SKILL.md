---
name: fetch-requirement
description: '從一個或多個 Confluence Wiki URL 或 JIRA issue URL 取得需求內容，並擷取交易代碼（txCd）。當使用者提供單一或多個 URL 時使用此技能。'
allowed-tools: shell
---

# 需求擷取技能

此技能可從**單一或多個 URL**（Confluence Wiki 與/或 JIRA）擷取需求內容，抽取交易代碼（txCd），並準備 Cerberus 流程所需輸出。

## 運作方式

當以 URL 作為輸入觸發時，此技能會自動辨識各來源類型並執行既定流程。

多個 URL 支援以下分隔符號：
- newline
- comma `,`
- semicolon `;`
- pipe `|`

### 若 URL 是 JIRA issue（`jira.linebank.com.tw/browse/`）：
1. 透過 REST API（Bearer token）抓取 JIRA issue
2. 從描述內容擷取交易代碼（會忽略 wiki 連結）
3. 將 JIRA 描述儲存為需求來源

### 若 URL 是 Confluence Wiki 頁面：
1. 解析 pageId（支援 `pageId=`、`/pages/<id>/` 與短網址 `/x/`）
2. 抓取 Confluence 頁面內容，將 HTML 轉為純文字，並儲存至 `.cucb/requirement-specs/sources/<id>.md`
3. 掃描並擷取交易代碼

所有 URL 完成處理後：
4. 合併所有找到的交易代碼
5. 輸出單一整合的 `SKILL_OUTPUT:` JSON

輸出相容性：
- 保留第一個成功 URL 的舊版頂層欄位（`requirement_id`、`page_title`、`source_path`）
- 新增 `requirements` 陣列以包含所有已處理 URL
