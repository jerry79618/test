---
name: cerberus-init
description: >
  Cerberus 環境初始化精靈。引導使用者完成專案設定，自動產生 config.md 與 *.conf，
  不需要手動編輯設定檔。第一次使用 Cerberus 或加入新系統時執行。
allowed-tools: shell, ask_user
---

# Cerberus Init 精靈

此技能以**互動問答方式**收集專案環境資訊，自動寫入：
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

---

### Phase 2 — 收集系統資訊（逐步問答）

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
  - 帳號密碼（若需要，密碼將加密儲存）",
  allow_freeform: true
)
```

> 若使用者回應「沒有 API」或「不走 API」→ 進入 Step 2-3b

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
