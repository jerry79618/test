---
name: bitbucket-search
description: 'Search LINE Bank Bitbucket source code by class name, function name, or keyword. USE THIS SKILL when the user says "@Bitbucket-Search", "search bitbucket", "搜尋程式碼", "找原始碼", or asks about Java classes or service codes.'
---

# Bitbucket-Search Skill

## 觸發條件
當使用者提到搜尋 bitbucket、找原始碼、@Bitbucket-Search 時觸發。

## 執行方式
1. 讀取工具定義檔，確認 API Command、Search Strategy、Output Format。
2. 依照定義檔的 Steps、Search Strategy、Output Format 逐步執行
3. 將使用者的關鍵字帶入搜尋
4. 立即執行，不要詢問確認

## 注意事項
- 使用 PowerShell Invoke-WebRequest
- 內網連線需清除 proxy
- 需 -SkipCertificateCheck
- Token 在工具定義檔內（含 BBDC- prefix）