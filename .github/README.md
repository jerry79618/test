# Cerberus 操作教學文件

本文件整理 Cerberus 專案在 `.github` 下的主要流程與操作方式。
內容涵蓋流程角色分工、規範文件定位、常用操作步驟、輸出結果檢核與補充驗證說明。
本文採用一致的章節化結構，目的在於提供可追溯、可維護、可交付的流程說明基準，作為需求實作與流程溝通的共同參考。

## 章節導覽

- [1. 主題](#1-主題)
- [2. 項目說明](#2-項目說明)
- [3. 主題結構](#3-主題結構)
- [4. 使用流程說明](#4-使用流程說明)
- [5. 中斷點與互動機制](#5-中斷點與互動機制)
- [6. 常用指令](#6-常用指令)
- [7. 常見問題](#7-常見問題)
- [8. 維護建議](#8-維護建議)
- [9. 執行摘要](#9-執行摘要)
- [10. 多網址流程](#10-多網址流程)
- [11. 完整流程圖（P1 到 P7）](#11-完整流程圖p1-到-p7)
- [12. 補充說明：P8 測試驗證](#12-補充說明p8-測試驗證)

## 1. 主題

本文件主題為 Cerberus 自動化需求流程的執行方式與維護重點。

---

## 2. 項目說明

在這個專案裡，`.github` 是「AI 協作規範中心」，主要分三塊：

- `agents/`: 定義每一個 AI Agent 的工作內容
- `instructions/`: 定義寫 Feature 與 Java Step 時的程式規範
- `skills/`: 定義可直接呼叫的工具能力（查需求、查 Wiki、跑測試、查 Bitbucket）

你可以把它想成：

- Agent = 角色分工
- Instructions = 寫作規範
- Skills = 工具箱

---

## 3. 主題結構

## 3.1 `agents/`

目前有以下角色：

| Agent 檔案 | 角色說明 | 對應步驟 |
|-----------|---------|---------|
| `orchestrator.agent.md` | 流程指揮中心，協調所有 sub-agent | — |
| `core.p2-quality-gate.agent.md` | 需求品質審查，評估 operationId / 內容 / 業務意圖 | P2 |
| `core.p3-code-analysis.agent.md` | 原始碼分析，萃取業務規則與驗證規則 | P3 |
| `core.p4-organize.agent.md` | 需求整理，產出結構化 requirement-spec.md | P4 |
| `core.p5-feature.agent.md` | 測試情境設計，產出 `.feature` 檔 | P5 |
| `core.p6-step.agent.md` | Step 實作與重用，產出或更新 Java Step | P6 |
| `core.p7-review.agent.md` | 產出審查，確認 Feature / Step / Alias 一致性 | P7 |
| `core.p8-verify.agent.md` | 測試執行驗證（選用）| P8 |

主流程步驟依序為：

1. **P1** 需求抓取（fetch-requirement skill）
2. **P2** 品質審查（Quality Gate）
3. **P3** 原始碼分析
4. **P4** 需求整理
5. **P5** Feature 設計
6. **P6** Step 實作
7. **P7** 產出審查

## 3.2 `instructions/`

- **Feature 撰寫規範**（`feature.instructions.md`）
  - 規範 `.feature` 檔寫法
  - 重點：Gherkin 關鍵字必須英文（Feature, Scenario, Given, When, Then）
  - 重點：需要外部資料但現在沒有時，使用 `@Pending` tag 標記情境（不是單純 comment）
  - 重點：盡量重用既有通用 Step，不要每次都造新句型

- **Java Step 程式規範**（`stepCode.instructions.md`）
  - 規範 Java 測試程式碼風格
  - 重點：Step 類別繼承 `CucumberBase`
  - 重點：業務邏輯放 private helper method，不要塞在 `@When/@Then`
  - 重點：使用 `ServiceCode` alias 綁定 operationId，不可硬寫字串

## 3.3 `skills/`

Skills 是可以直接在 CLI 呼叫的工具能力，每個 Skill 有自己的輸入規則與輸出格式。

---

### 🔵 `fetch-requirement` — 需求抓取

**觸發方式**：由 Orchestrator 在 P1 階段自動呼叫；使用者也可直接輸入需求 URL 啟動。

**支援的 URL 類型**：
- JIRA issue：`https://jira.linebank.com.tw/browse/CEPRJ-XXXX`
- Confluence Wiki：`https://wiki.linebank.com.tw/...`（支援 `pageId=`、`/pages/<id>/`、短網址 `/x/`）

**支援一次多 URL**（分隔符：換行 / 逗號 / 分號 / `|`）：

```text
https://jira.linebank.com.tw/browse/CEPRJ-3612
https://wiki.linebank.com.tw/pages/123456
```

**執行流程**：

| 步驟 | JIRA 路徑 | Wiki 路徑 |
|------|---------|---------|
| 1 | 呼叫 JIRA REST API，取得 summary + description | 解析 pageId，呼叫 Confluence REST API |
| 2 | 將 description 存為 `.cucb/requirement-specs/sources/<issueKey>.md` | 將頁面 HTML 轉純文字，存為 `.cucb/requirement-specs/sources/<pageId>.md` |
| 3 | 從 description 掃描 operationId（支援 CBK 11 碼 `SZ*`，可在 config.md 自訂規則） | 從頁面內容掃描 operationId |
| 4 | 偵測 Java Class hints（如 `EdwProcBizProc`） | 偵測 Java Class hints |

**重要規則**：
- ⛔ **嚴禁追蹤**：只處理使用者明確提供的 URL，不追蹤內嵌連結、關聯 JIRA、子頁面
- 若 URL 中找不到 operationId，輸出空 `txCd_list: []`，後續 P2 進入 Block 補件流程
- 多 URL 的 operationId 會合併去重後一起輸出

**輸出格式**（`SKILL_OUTPUT:` JSON）：

```json
{
  "requirement_id": "CEPRJ-3612",
  "page_title": "...",
  "env": "dev",
  "source_path": ".cucb/requirement-specs/sources/CEPRJ-3612.md",
  "txCd_list": ["SZCUA015041"],
  "class_hints": ["EdwProcBizProc"],
  "requirements": [
    {
      "requirement_id": "CEPRJ-3612",
      "page_title": "...",
      "source_type": "JIRA",
      "source_url": "https://jira...",
      "source_path": ".cucb/requirement-specs/sources/CEPRJ-3612.md",
      "txCd_list": ["SZCUA015041"],
      "class_hints": ["EdwProcBizProc"]
    }
  ]
}
```

---

### 🟢 `mvn-test` — Maven 測試執行

**觸發方式**：流程完成後，需要驗證 Feature / Step 實作是否可執行時使用。

```text
@mvn-test SZCUA015041 dev
```

**輸入格式**：`<Tag> <EnvProfile>`（空格分隔）

**執行流程**：

1. **環境設定**：自動偵測 `JAVA_HOME` 與 Maven 路徑（若終端未設定則自動補足）
2. **執行指令**：`mvn test "-Dcucumber.filter.tags=@<Tag>" -P <EnvProfile>`
3. **讀取報告**：優先讀 `target/cucumberReportJsonFiles/cucumber-report.json`；若不存在，fallback 讀 `target/surefire-reports/*.txt`
4. **摘要輸出**：顯示通過 / 失敗 / 跳過的 Scenario 數量，對失敗項列出 Scenario 名稱與錯誤訊息

**結果判斷**：
- Exit code `0` = 全部通過
- Exit code 非 `0` = 有失敗，需查看錯誤訊息

**範例輸出**：

```
✅ 3 passed / ❌ 1 failed / ⏭️ 0 skipped

失敗項目：
- Scenario: "When customer does not exist" 
  Error: AAPATE0008 - 客戶不存在
```

---

## 4. 使用流程說明

本節說明實際執行流程。
目前採用 `sub-agent` 模式，由 `orchestrator` 負責指揮不同 agent 執行任務。

### 步驟 1：準備需求網址

你需要其中一種：

- JIRA issue，例如：`https://jira.linebank.com.tw/browse/CEPRJ-3612`
- Confluence Wiki 頁面網址

### 步驟 2：切換流程 Agent 並啟動

在 CLI 中先完成以下操作：

1. 於專案路徑開啟 Copilot CLI
2. 若出現資料夾信任提示，選擇 `Yes`
3. 先執行 `/allow-all`
4. 輸入 `/agent` 並按 Enter，開啟 agent 清單
5. 選擇 `cucb.orchestrator`

指令範例：

```text
/allow-all
/agent
```

切換完成後，會顯示已選擇 `cucb.orchestrator`。

接著輸入需求網址啟動流程：

```text
@cucb.orchestrator https://jira.linebank.com.tw/browse/CEPRJ-3612
```

若已有進行中的 plan，可直接輸入：

```text
@cucb.orchestrator
```

### CLI 操作重點

- 先完成 `/allow-all`，避免流程中途卡在權限詢問
- 使用 `/agent` 選定 `cucb.orchestrator` 後再開始輸入需求
- 完成 agent 切換後，建議固定由 orchestrator 啟動流程，避免手動跳步

### 步驟 3：主流程自動執行（P1 到 P7）

流程啟動後，`cucb.orchestrator` 會依序自動執行 P1 到 P7，並在關鍵節點暫停等待使用者確認。

| 步驟 | Agent | 自動 / 互動 | 說明 |
|------|-------|------------|------|
| P1 | fetch-requirement（skill） | 自動 | 解析需求內容、找出 operationId、產生來源檔 |
| P2 | core.p2-quality-gate | **互動**（必停） | 審查 operationId 是否存在、需求內容是否有實質內容、業務意圖是否可辨識；通過後需使用者確認再繼續 |
| P3 | core.p3-code-analysis | 自動（P2 Pass 後，有 API 內容或語意命中時執行；設定異動需詢問；否則跳過 P3=[~]） | 讀取本機原始碼，萃取驗證規則與業務規則 |
| P4 | core.p4-organize | 自動（P3 後） | 整理需求規格，有 Open Question 時需逐一確認 |
| P5 | core.p5-feature | 自動（P4 確認後） | 依規格產出 `.feature` 檔 |
| P6 | core.p6-step | 自動（P5 後） | 產出或補充 Java Step 定義 |
| P7 | core.p7-review | 自動（P6 後） | 審查所有產出，發現問題自動修正 |

### 步驟 4：確認輸出結果

流程完成後，常見產出如下：

| 產出 | 路徑 |
|------|------|
| 執行計畫 | `.cucb/plans/*_active.plan.md` |
| 程式碼分析報告 | `.cucb/code-analysis/<operationId>-analysis.md` |
| 結構化需求規格 | `.cucb/requirement-specs/<id>_<operationId>.md` |
| Feature 測試情境 | `src/test/resources/features/<operationId>.feature` |
| Java Step 定義 | `src/test/java/com/yhao/step/*Step.java` |
| Step 業務對應表 | `.cucb/step-business-map.md` |

### 步驟 5（選用）：執行測試驗證（P8）

可透過 skill 或 Maven 直接執行。

執行方式：

- 透過 `mvn-test` skill，輸入格式為 `<Tag> <EnvProfile>`，例如 `SZCUA015041 dev`
- 或直接在終端執行：`mvn test "-Dcucumber.filter.tags=@<Tag>" -P <EnvProfile>`

---

## 5. 中斷點與互動機制

流程在以下時機會主動暫停，等待使用者以**互動選單**回應（不需要記指令格式）。

> 💡 **自然語言也可以**：流程暫停時，你也可以直接用文字回答，Orchestrator 會語意解讀後繼續。
> 例：「這個功能是讓客戶補發金融卡的」→ 等同 `補充目標: 客戶補發金融卡`

### 📐 operationId 格式定義

系統支援兩種 operationId 格式，辨識規則適用於所有補件情境：

| 類型 | 格式規則 | 長度 | 範例 |
|------|---------|------|------|
| **CBK Service Code** | 全大寫英數字，固定 **11** 碼，開頭 `SZ` | 11 | `SZCUA01G001` |


---

### 🔴 P2 強制停止（缺少 operationId 或需求內容為空）

> ⚠️ **沒有 operationId 不一定會停止。** 若 P2 判定需求為「設定異動」（例如：修改參數值、新增 Enum 成員、切換開關），則不需要 operationId，流程照常繼續。
> 只有在需求明確是 API/功能行為修改，卻找不到交易代碼時，才會強制停止。

**觸發條件**（以下任一）：
- 需求是 API 或功能行為修改，但找不到 operationId（交易代碼）
- 需求頁面沒有實質內容（空白、只有標題、或無法讀取）

**行為**：強制停止，等使用者補充缺漏資訊。**不接受 continue**。

系統會依實際缺漏的內容，**動態顯示對應的補充選項**（只顯示真正缺少的項目）：
- 🔑 直接輸入 operationId（交易代碼）
- 🔍 讓系統從原始碼搜尋受影響的模組（當完全不知道 operationId 時使用）
- 📝 貼上需求摘要文字（當頁面為空時）
- 🔗 提供正確的需求文件 URL

### 🔍 從原始碼搜尋受影響模組（不知道 operationId 時）

當使用者選擇「讓系統搜尋原始碼」時，可透過以下方式縮小搜尋範圍：

1. 輸入 **Repo 名稱**（如 `lbtwcbcbk_zcusvc`）→ 只搜尋該 Repo
2. 輸入 **Class 或檔名關鍵字** → 只搜尋符合名稱的檔案
3. 什麼都不輸入 → 掃描 `config.md` 設定的所有本機路徑

搜尋完成後，系統顯示找到的模組與 operationId，使用者確認後重新進行 P2 審查。

### 🟡 Quality Gate Warn（P2 — 業務意圖不明）

**觸發**：需求文件無法辨識「使用對象」或「業務目的」。

補充後重新評分，通過則繼續；使用者也可選擇暫停。

### 🔵 P2 通過後確認點

**觸發**：P2 審查通過，需使用者確認需求摘要正確再繼續 P3。

顯示摘要表格（Requirement ID、operationId、需求摘要、既有實作、品質評估），使用者選擇：
- ✅ 確認正確，繼續 P3
- ➕ 補充遺漏的 operationId
- 📝 附加背景說明
- ⏸️ 暫停流程

> **⚙️ 設定異動需求的特殊路由**：若 P2 判定需求為「設定異動」（`requirement_type: "config_change"`），代表這是修改參數值、Enum 成員或系統開關的需求，**不需要 operationId**。P2 通過後，系統會詢問是否有已知的 Class / Enum 名稱：
> - 有 → 以原始碼搜尋模式呼叫 P3 定位原始碼
> - 沒有 → 跳過 P3，直接進入 P4

### 🟠 P3 執行條件

P2 Pass 後，Orchestrator 依下列條件決定是否執行 P3：

| 條件 | P3 路徑 |
|------|---------|
| 需求含 API/欄位描述（Request/Response/欄位等關鍵字） | 執行 P3 — **API 路徑**：找 API 對應 input/output 規則 |
| 語意搜尋命中既有 Feature 或 Step | 執行 P3 — **語意路徑**：從命中的程式碼追溯業務規則 |
| 判定為設定異動需求（無 operationId） | 詢問是否有 Class/Enum 名稱後決定（原始碼搜尋路徑） |
| 以上皆無 | **跳過 P3**，直接進入 P4 |

### 🟠 P3 找不到原始碼

**觸發**：P3 在本機路徑找不到對應的 operationId 原始碼（`SourceNotFound`）。

選項（最多重試 2 次，超過自動跳過）：
- 🔍 指定 Repo slug
- 📄 指定檔名關鍵字
- ⏭️ 跳過，直接用需求文件繼續

> **⚠️ LocalPathNotConfigured**：若 `.cucb/config.md` 尚未設定本機路徑，P3 會顯示提示訊息，等待使用者補充 config.md 後重試（與 SourceNotFound 不同，此情況**不計入重試次數**）。

### ⚠️ P3 規則確認關口（P3 → P4 前）

**觸發**：P3 補充業務規則中有標記 ⚠️ 的項目（程式碼行為與需求文件有差異）。

逐一確認每條 ⚠️ 規則：
- ✅ 以程式碼行為為準
- ❌ 程式碼有誤，以需求書為準（標記待修正）
- 📝 補充說明

確認結果傳給 P4，確保 Feature 不包含猜測性內容。

---

### 📝 P4 需求整理（三種結果）

P4（core.p4-organize）執行後會回傳以下三種狀態之一：

| 狀態 | 觸發條件 | 後續行為 |
|------|---------|---------|
| `Validated` | 需求規格整理完成，無待確認事項 | 直接呼叫 P5（待確認問題確認關口暫時停用） |
| `NeedsInput` | 有需要使用者確認的欄位或規則 | 進入**多輪確認循環**（見下方） |
| `Manual-Review-Required` | 需求與程式碼有嚴重衝突，無法自動解決 | 流程強制停止，顯示衝突清單，等待人工處理 |

#### 🔁 NeedsInput 多輪確認循環

**觸發**：P4 回傳 `NeedsInput`，表示仍有欄位定義、業務規則或邊界值需要確認。

流程會依序逐一詢問每個待確認問題（顯示進度 `第 N 輪，共 M 個問題`），收集使用者回答後重新呼叫 P4。

- **循環無次數上限**：所有問題都必須獲得明確回答，才能離開確認循環
- **答案會累積**：每輪的答案合併後一起傳給下一輪 P4，不會遺失
- **直到 `Validated` 才結束**：若 P4 回傳新一批 `NeedsInput` 問題，繼續循環

#### ⛔ Manual-Review-Required（強制停止）

**觸發**：需求書與程式碼之間存在無法自動裁決的衝突。例如：同一欄位在兩份文件中有互斥的驗證規則，或業務邏輯有根本矛盾。

行為：
- 流程**完全停止**，不會進入 P5
- 顯示所有衝突項目清單
- 使用者必須手動解決衝突後，重新提供釐清資訊，再次觸發 P4

> ⚠️ 這個狀態無法用 `continue` 跳過，必須實際解決衝突。

---

## 6. 常用指令

CLI 流程指令：

- `/allow-all`
- `/agent`
- `@cucb.orchestrator https://jira.linebank.com.tw/browse/CEPRJ-3612`

### 文字指令（可直接輸入，Orchestrator 會語意解讀）

| 指令 / 輸入方式 | 用途 | 適用時機 |
|---------------|------|----------|
| `continue` | 確認無誤，繼續下一步 | P2 通過後確認點 |
| `補充目標: <說明>` | 補充業務目標說明 | P2 業務意圖不明（Warn） |
| `補 txCd: <代碼>` | 補充缺漏的 operationId | P2 強制停止（Block） |
| `補來源: <內容或URL>` | 補充需求來源內容 | P2 強制停止（Block） |
| `txCd add <txCd>` | 加入 operationId 後繼續 | P2 通過後確認點 |
| `note <說明>` | 附加背景補充說明 | P2 通過後確認點 |
| `repo <repo-slug>` | 指定 Repo 提示（重試 P3） | P3 找不到原始碼 |
| `file <關鍵字>` | 指定檔案名稱關鍵字（重試 P3） | P3 找不到原始碼 |
| `stop` | 暫停流程 | 任何中斷點 |

> ❌ P2 強制停止（operationId 缺漏 / 頁面為空）屬於強制停止，不接受 `continue`。
> ✅ P3 完成後自動繼續 P4，不需要使用者回應。

---

## 7. 常見問題

### Q1. 需要先理解每個 Agent 的內部規則嗎？

不需要。先以 orchestrator 執行完整流程即可。
若後續需要除錯，再回頭檢視 `agents/` 細節。

### Q2. operationId 找不到時怎麼辦？

流程會自動停止並顯示補充選單。最常見的做法是選「🔍 讓系統從原始碼搜尋」，
輸入 Repo 名稱或 Class 名稱，讓 P3 在本機原始碼中自動找到受影響的模組與 operationId。

### Q3. 為什麼 Feature 內容需要使用英文？

因為 `feature.instructions.md` 明確規定 Gherkin 關鍵字與步驟敘述用英文，
這樣較有利於跨角色協作與維護。

### Q4. 需要外部資料的測試情境怎麼處理？

使用 `@Pending` tag 標記，並加上 `# TODO:` 說明需要的資料或環境條件。
**不要**用純 comment 隱藏整個 Scenario，這樣 Cucumber 執行報告會看不到 Pending 計數。

### Q5. Step 可以直接撰寫大量 if/else 嗎？

不建議。`stepCode.instructions.md` 的原則如下：

- Step 只做參數解析、呼叫方法、存取 context
- 業務邏輯放在 private helper method，不要塞在 `@When/@Then`

### Q6. 測試失敗時應如何處理？

建議先判斷錯誤類型：

- 設定或環境錯誤（例如連線、Class not found）通常要先修環境
- Undefined/Ambiguous step 才適合自動補或修
- 後端業務未實作時，通常要回需求方或後端確認

---

## 8. 維護建議

- 改規範前，先看 `instructions/` 是否已經有同類規定，避免重複
- 新增 skill 時，保持輸入格式固定，讓使用方式更容易記憶
- Agent 的責任要單一，不要把太多事情塞到同一個 agent
- 所有新規範都建議附一段「正確範例」
- `config.md` 的本機 Repo 路徑設定要保持最新，否則 P3 Discovery 模式會失敗

---

## 9. 執行摘要

建議操作順序如下：

1. 執行 `/allow-all` + `/agent` 切換到 `cucb.orchestrator`
2. 輸入需求 URL 啟動流程（P1 自動執行）
3. **P2 通過後確認點**：確認需求摘要與 operationId 正確後繼續
4. P3 ~ P4 自動執行，有 ⚠️ 規則或 Open Question 時配合確認
5. P5 ~ P7 自動執行完成
6. 若需要，執行 P8 測試驗證

---


## 10. 補充說明：P8 測試驗證

主流程涵蓋 P1 到 P7。`P8` 屬於額外驗證流程，通常在以下情境使用：

- 需要確認 Feature / Step 實作是否可執行
- 需要整理 failed scenario 與錯誤訊息
- 需要重試並驗證修正是否生效

常見做法：

- 使用 `mvn-test` skill（`<Tag> <EnvProfile>`），例如：`SZCUA015041 dev`
- 或直接執行：`mvn test "-Dcucumber.filter.tags=@<Tag>" -P <EnvProfile>`
