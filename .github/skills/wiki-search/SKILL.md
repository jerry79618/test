---
name: wiki-search
description: 'Search LINE Bank internal Confluence Wiki by keyword. USE THIS SKILL when the user says "@Wiki-Search", "search wiki", "查 wiki", "wiki 搜尋", or asks about internal policies, BRD, PRD, or business rules.'
allowed-tools: shell
---

# Fetch Requirement Skill

提供標準化的需求抓取流程。


# Wiki-Search Skill

## 觸發條件
當使用者提到搜尋 wiki、查 wiki、@Wiki-Search 時觸發。

## 執行方式
1. 讀取工具定義檔
2. 依照定義檔的 API Commands、Search Strategy、Output Format 逐步執行
3. 將使用者的關鍵字帶入搜尋（需 URL encode 中文）
