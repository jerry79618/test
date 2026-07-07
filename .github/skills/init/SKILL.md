---
name: cerberus-init
description: >
  Cerberus 環境初始化精靈。引導使用者完成專案設定，自動產生 config.md 與 *.conf，
  不需要手動編輯設定檔。第一次使用 Cerberus 或加入新系統時執行。
allowed-tools: shell, ask_user
---

# Cerberus Init 精靈

此技能以**互動問答方式**收集專案環境資訊，自動寫入：
- 環境變數 `JIRA_PAT` / `WIKI_PAT`（需求來源憑證，使用者層級，**不寫入檔案**）
- `.cucb/config.md`（P3 原始碼路徑、txCd Pattern）
- `src/test/resources/dev.conf`（API endpoint 設定）
- `.cucb/db-config.md`（選用，DB 查詢功能設定）
- `.cucb/db-queries/`（選用，SQL 查詢存放資料夾）

---

## 執行流程

### Phase 1 — 確認現有設定

讀取現有的 `.cucb/config.md` 與 `src/test/resources/dev.conf`：
- 若已存在 → 顯示現有內容，詢問是要**新增系統**或**完整重設**
- 若不存在 → 直接進入 Phase 2 全新設定

同時檢查需求來源憑證是否已設定（只檢查存在與否，**不顯示值**）：

```powershell
[bool]$env:JIRA_PAT; [bool]$env:WIKI_PAT
```

- 兩者皆已設定 → 跳過 Step 2-0（使用者可主動要求更新）
- 任一缺 → Phase 2 從 Step 2-0 開始

---

### Phase 2 — 收集系統資訊（逐步問答）

#### Step 2-0：需求來源憑證（JIRA / Wiki Token）

> P1（fetch-requirement）與 wiki-search 需要 JIRA / Confluence 的 Personal Access Token。
> Token 以**使用者層級環境變數**保存（`JIRA_PAT` / `WIKI_PAT`），**嚴禁寫入任何專案檔案或版控**。

```
ask_user(
  question: "需要設定需求來源的存取憑證（存在你個人的 Windows 環境變數，不會寫入專案檔案）：
  (1) JIRA Personal Access Token（JIRA 個人設定 → Personal Access Tokens 產生）
  (2) Confluence Wiki Personal Access Token
  請依序貼上兩個 token；只用其中一種來源的話，另一個可填「跳過」。",
  allow_freeform: true
)
```

收到後立即寫入（同時設定目前 session 與永久值），**不回顯 token 內容**，完成只回報「已設定」：

```powershell
[Environment]::SetEnvironmentVariable('JIRA_PAT', '<token>', 'User'); $env:JIRA_PAT = '<token>'
[Environment]::SetEnvironmentVariable('WIKI_PAT', '<token>', 'User'); $env:WIKI_PAT = '<token>'
```

> 使用者層級變數對**新開的**終端機生效；目前 session 由 `$env:` 補上，設定完即可直接使用。
> 使用者選「跳過」→ 記錄該來源未設定，提醒對應功能（JIRA 抓取 / Wiki 抓取）暫不可用。

#### Step 2-1：系統識別與 txCd Pattern

```
ask_user(
  question: "請告訴我這個系統的識別資訊：
  - 系統名稱（例如：CU Service、LO Service）
  - 交易代碼前綴（例如：SZCU、SZLO、BZCU）
  - 交易代碼格式（例如：SZ 開頭固定 11 碼；BZ 開頭固定 11 碼）
  若有多個系統，請一次說明所有系統。",
  allow_freeform: true
)
```

從回應中萃取：
- 每個系統的 `系統名稱`、`交易代碼前綴`、`Regex Pattern`

#### Step 2-2：原始碼本機路徑

```
ask_user(
  question: "P3 程式碼分析需要讀取後端原始碼。請告訴我每個系統的本機 git clone 路徑，以及它的 LBSystem 歸屬（測試程式呼叫 API 時綁定的系統代碼，例如 CBK、MBK、EAI）：
  格式：<交易代碼前綴> → <本機路徑> → <LBSystem>
  例如：SZCU → D:\git\lbtwcbcbk_zcusvc\ZCUSvc\src → CBK
  
  若尚未 clone，路徑可先填空白，之後手動補充。",
  allow_freeform: true
)
```

#### Step 2-3：API Endpoint 設定

```
ask_user(
  question: "請告訴我測試環境的 API endpoint 設定。
  
  你需要哪些系統的 API？（可多選）
  例如：CBK（主業務）、MBK（行動銀行）、EAI、BXM、UMS、EDMS...
  
  對每個系統，請提供：
  - 環境名稱（dev / stg）
  - 完整 URL（含 port）
  - 帳號密碼（若需要，密碼將加密儲存）
  - 請求信封格式：這個系統用的是原生 CBK header，還是 MCA 或其他格式？（不確定就填 CBK）",
  allow_freeform: true
)
```

> 若使用者回應「沒有 API」或「不走 API」→ 進入 Step 2-3b
> 若任一系統的信封格式**不是 CBK** → 完成本步後進入 Step 2-3c

#### Step 2-3c（信封非 CBK 時）：收集介接契約

對每個非 CBK 信封的系統：

```
ask_user(
  question: "<系統> 使用 <格式> 信封，需要介接契約才能讓測試程式正確組請求。請提供：
  (1) Header 欄位清單（欄位名、必填與否、值來源，例如交易序號怎麼產生、認證怎麼帶）
  (2) 一份實際的 request/response 範例（可直接貼 JSON/XML，或介接文件連結）
  (3) 錯誤碼在 response 的哪個欄位？（例如 body.rtnCode）
  現在拿不到完整資料也可以先說，我會在協定表標注待補。",
  allow_freeform: true
)
```

- 有完整契約 → 寫入協定表，範例存到 `.cucb/protocol-samples/<LBSystem>.md`
- 資料不全 → 協定表該列的 Header Helper 欄填 `⚠️ 待補`，P6 遇到時會以 `NeedsInput` 要求補齊，不會猜格式

#### Step 2-3b（無 API 時）：補充驗證機制

```
ask_user(
  question: "你提到沒有 API endpoint，那測試如何驗證結果？
  
  請告訴我驗證機制：
  - 透過資料庫查詢驗證？（如查 Oracle / MySQL 確認資料有寫入）
  - 透過檔案輸出驗證？（如批次產出 CSV / 檢查 SFTP）
  - 透過其他介面？（如 MQ、SOAP、Log 比對）
  
  請盡量詳細說明，這會影響 P3~P5 怎麼設計測試案例。",
  allow_freeform: true
)
```

將回應記錄至 `.cucb/config.md` 的 `## 驗證機制補充` 區塊，供 P4 可行性預審參考。

#### Step 2-4：DB Agent 設定（選用）

```
ask_user(
  question: "Cerberus 支援 DB 查詢功能：當測試前置資料需要從資料庫取得，或需要用 SQL 驗證資料狀態時，DB Agent 可以幫你執行查詢。
  
  你需要這項功能嗎？
  如果需要，請告訴我：
  - 資料庫類型（Oracle / MySQL / PostgreSQL / 其他）
  - 連線資訊（JDBC URL 或 host:port/schema）
  - 帳號（密碼將加密儲存）
  - 主要使用的 Schema 或 Table 範圍",
  allow_freeform: true
)
```

若使用者確認需要 DB Agent：
- 將連線設定寫入 `.cucb/db-config.md`
- 建立 `.cucb/db-queries/` 資料夾（若不存在）
- 在資料夾內建立 `README.md`，說明使用方式

#### Step 2-4b：DB 驗證情境收集（DB Agent 啟用時執行）

```
ask_user(
  question: "DB Agent 已啟用。為了讓 P5/P6 知道什麼時候需要用 DB 驗證，請告訴我你的業務情境：

  常見情境例子：
  - 「存款成功後，用 DB 確認帳戶餘額真的更新了」
  - 「事故登錄後，用 DB 確認記錄有寫入」
  - 「測試前，先用 DB 確認前置資料存在」

  請描述你的情境（可多個），包含：
  1. 對應的服務代碼（如 SZDPF023011），若通用請說「全部」
  2. 什麼時候查（成功後 / 失敗後 / 測試前）
  3. 查什麼、驗證什麼

  若現在還不確定，可跳過，之後在 .cucb/db-usage-scenarios.md 手動新增。",
  allow_freeform: true
)
```

依回應，在 `.cucb/db-usage-scenarios.md` 的「情境清單」表格填入對應列：

| 欄位 | 如何從回應中萃取 |
|------|----------------|
| `scenario_id` | 自動遞增（DB-01、DB-02...） |
| `txCd` | 使用者提到的服務代碼，未指定填 `*` |
| `trigger` | 「成功後」→ `after_success`；「失敗後」→ `after_failure`；「測試前」→ `before_test` |
| `purpose` | 使用者描述的驗證目的 |
| `query_file` | 以 `verify_<業務名>.sql` 格式命名（檔案稍後建立）|
| `key_params` | 根據業務情境推斷（如需帳號 → `context.acctNbr`）|
| `then_step_template` | 從 purpose 生成英文步驟文字 |

> 若使用者跳過此步驟，保持 `.cucb/db-usage-scenarios.md` 的「尚未設定」預設列不變，Phase 4 完成訊息中提醒使用者手動補充。

---

### Phase 3 — 產生設定檔

依收集到的資訊，**覆寫或追加**以下檔案：

#### `.cucb/config.md`

依現有格式追加或更新 `txCd 掃描規則` 與 `本機 Repo 路徑設定` 表格：

```markdown
| 系統識別 | Regex Pattern    | 範例        | 說明           |
|---------|------------------|-------------|----------------|
| <系統>  | `<Regex>`        | <txCd範例>  | <說明>         |
```

```markdown
| txCd 前綴  | 本機路徑 | LBSystem | 說明       |
|-----------|---------|----------|------------|
| `<前綴>*` | `<路徑>` | <系統代碼> | <系統名稱> |
```

以及 `## 系統協定設定` 表格（每個出現在 endpoint 設定的 LBSystem 都要有一列；信封格式使用者沒特別說就填 CBK 預設列）：

```markdown
## 系統協定設定
| LBSystem | HeaderType | Header Helper | Response 類型 | 錯誤碼位置 | 說明 |
|----------|-----------|---------------|--------------|-----------|------|
| CBK      | CBK       | CBKHeaderHelper | CBKResponse | header.msgCd | 原生核心 |
| <系統>   | <格式>    | <Helper 類名或 ⚠️ 待補> | <Response 類名> | <欄位路徑> | <說明> |
```

> 此表是 P6 選擇 Header/Client 的依據；gate-p2 會檢查每個 txCd 的 LBSystem 是否在表內（缺列 → `protocol_not_configured`，BP-P2 要求補件）。**舊 config.md 沒有此表時，一律視為原生 CBK**（相容既有行為）。

#### `src/test/resources/dev.conf`

追加或更新 endpoint 設定（JSON 格式與現有設定保持一致）：

```
<system>Endpoints={"<LBSystem>":"<URL>"}
```

密碼欄位：提示使用者此處為明文，建議使用加密後的值（與現有 `.conf` 格式一致）。

#### `.cucb/db-config.md`（僅 DB Agent 啟用時）

```markdown
# DB Agent 設定

## 連線資訊
| 欄位 | 值 |
|------|---|
| DB 類型 | <Oracle/MySQL/...> |
| JDBC URL | <jdbc:...> |
| Schema | <schema名稱> |

## 使用說明
SQL 查詢檔案請放置於 `.cucb/db-queries/` 資料夾。
Agent 呼叫時可指定檔案名稱或直接傳入 SQL 字串。
```

---

### Phase 4 — 確認與完成

顯示所有即將寫入的設定摘要，確認後執行寫入：

```
ask_user(
  question: "以上設定即將寫入，請確認：
  <摘要列表>
  
  確認後按繼續，或告訴我需要修改哪裡。",
  allow_freeform: true
)
```

寫入完成後輸出：

```
✅ Cerberus 環境設定完成

已設定：
- 環境變數 JIRA_PAT / WIKI_PAT  ← 需求來源憑證（僅在你的使用者環境，未寫入任何檔案）

已產生：
- .cucb/config.md          ← P3 原始碼路徑
- src/test/resources/dev.conf  ← API endpoint
<若有 DB>
- .cucb/db-config.md       ← DB 連線設定
- .cucb/db-queries/        ← SQL 查詢存放位置

下一步：
- 若有批次系統，請確認 BAT server 連線設定
- 若有 DB 查詢需求，可將 .sql 檔案放入 .cucb/db-queries/
- 執行第一個需求：提供 JIRA 或 Wiki URL 開始
```
