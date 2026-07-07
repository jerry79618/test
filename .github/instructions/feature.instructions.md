---
applyTo: "src/test/resources/features/*.feature"
---

# Gherkin 風格指南 (Gherkin Style Guide)

Cerberus 專案的 Gherkin 規範與最佳實踐指南。

---

## 📋 檔案結構與組織

### Feature 檔案位置
```
src/test/resources/features/
```

### 檔案命名規範
- 小寫，使用底線分隔
- 範例: `card_reissue.feature`, `transfer_domestic.feature`
- 禁止使用特殊符號或中文名稱

---

## 🔤 語言規則 (Language Rules)

### Gherkin 關鍵字
**必須使用英文**，禁止中文：

```gherkin
✓ Feature, Scenario, Background, Given, When, Then, And, But
✗ 功能, 場景, 背景, 假設, 當, 則, 並且, 但是
```

### Step 描述
- **必須使用英文** 描述業務行為
- **遵循 PM Voice**（非技術語言）
- **具體清晰**，避免模糊表述

**範例：❌ Bad vs ✓ Good**
```gherkin
❌ When call the service with parameters
✓ When the customer "Tester" requests card replacement with the following details

❌ Then check the response
✓ Then The response message code should be "LBNA000001"
```

### 測試資料 (DataTable)
- **DataTable 內** 的測試資料（姓名、地址等）可使用 **繁體中文**
- Header 保持英文
- 資料格式一致

```gherkin
✓ Given A Active TW account person call "Tester" with following fields
    | custNm   | birthDay | gender |
    | 測試用戶   | 19990101 | 1      |
```

---

## 📐 Feature 檔案結構

### 完整範本
```gherkin
# features/card/card_reissue.feature
Feature: Modify shipping address for card reissue
  As a Retail Banking Product Manager
  I want customers to be able to update their card shipping address when requesting a card reissue
  
  Background: Open Account
    Given A Active TW account person call "Tester" with following fields
      | custNm   | birthDay | gender |
      | Cucumber | 19990101 | 1      |

```

### 結構要求

#### 1. Feature 標題
- **簡潔清晰**，描述業務場景
- 使用動詞開頭（e.g., "Modify", "Request", "Query")
- 避免過長（< 80 字元）

#### 2. User Story (Optional)
```gherkin
Feature: [Title]
  As a [Role]
  I want to [Action]
  So that [Benefit]
```

#### 3. Background（視情況）

Background 的目的是建立「所有 Scenario 都必須依賴的前置條件」。  
**不是每個 Feature 都需要 Background — 請根據下表判斷。**

| Scenario 類型 | 是否需要 Background | 原因 |
|---|---|---|
| 呼叫線上 API 需要客戶帳號 | ✅ 需要 | Step 要從 context 取 custId / arrId |
| 批次參數驗證（批次啟動即失敗） | ❌ 不需要 | 批次不讀 .SAM，不需要客戶資料 |
| 批次 E2E 流程（需操作真實資料） | ✅ 需要 | .SAM 內容需要真實 custId / arrId |
| 純狀態查詢 / 系統參數測試 | ❌ 不需要 | 不依賴特定客戶資料 |

**判斷依據**：Step 實作裡有沒有用到 `context().get("Tester").getCustId()` 或 `getArrId()`？  
有用到 → 需要 Background；沒有 → 不需要。

⚠️ **若 Background 不需要，禁止加入佔位用的開帳步驟**（會造成不必要的資源浪費與測試執行時間增加）。

**✅ 正確範例 — 線上 API 場景（需要 Background）**:
```gherkin
Background: Open Account
  Given A Active TW account person call "Tester" with following fields
    | custNm   | birthDay | gender |
    | Cucumber | 19990101 | 1      |
```

**✅ 正確範例 — 批次參數驗證（不需要 Background）**:
```gherkin
@ARR_CND_BATCH_PARAM
Feature: Batch parameter validation for arrangement condition CC load
  # 不需要 Background — 批次在啟動時就因參數缺失而拒絕，不讀取任何客戶資料

  Scenario: CC Load batch rejects execution when baseDt parameter is missing
    When Execute batch that jobId is "BZDP0260005" on BXM with following fields
      ...
```

**❌ 錯誤範例（自創新 Background Step）**:
```gherkin
Background:
  Given An active TW account customer "TestCustomer" exists with following details
    | custId     | custNm   | status |
    | AC00000001 | Cucumber | ACTIVE |
```

**說明（需要 Background 時的標準做法）**：
- `A Active TW account person call {string} with following fields` 是 `CommonStep.java` 提供的通用 Step
- 這個 Step 會自動呼叫 `custClient.createCustomer()` 建立測試帳戶，並將以下欄位存入 `CIFData`：

| 自動建立的欄位 | 說明 | 在 Step 中取用方式 |
|---|---|---|
| `lineUid` | LINE UID | `context().get("Tester").getLineUid()` |
| `nid` | 身分證號 | `context().get("Tester").getNid()` |
| `custId` | 客戶 ID | `context().get("Tester").getCustId()` |
| `mainAcctNbr` | 主帳號號碼 | `context().get("Tester").getMainAcctNbr()` |
| `arrId` | 安排 ID | `context().get("Tester").getArrId()` |

⚠️ **以上欄位由 Background 自動建立，絕對不可出現在 Scenario DataTable 中。**  
Feature 的 DataTable 只放業務輸入參數（如 `zipCd`、`addrHrcyCd`、`amount` 等），技術 ID 由 Step 層自行從 context 取得。

**如何檢查現有通用 Step**：
1. 查看 `src/test/java/com/yhao/step/CommonStep.java`
2. 查看其他現有 Feature 文件（如 `sample.feature`）

#### 4. Scenario (業務場景)
- 每個 Scenario 測試**單一業務行為**
- 步驟數 **≤ 15**（避免過長）
- Scenario 名稱清晰且具體

**命名規範**:
```gherkin
✓ Scenario: Customer requests card replacement and updates shipping address
✗ Scenario: Card reissue
✗ Scenario: API call test
```

#### 5. Given, When, Then 步驟

**Given** (前置條件)
- 描述初始狀態
- 可複數個 Given，用 `And` 連接

```gherkin
Given A Active TW account person call "Tester" with following fields
  | custNm | birthDay | gender |
  | 小明    | 19990101 | 1      |
And the customer has a valid ID document
And the customer account balance is "10000"
```

**When** (業務行為)
- 描述使用者執行的操作或 API 呼叫
- 通常只有一個 When，但可用 `And` 延伸

```gherkin
When The customer "Tester" requests card replacement with the following details
  | addrId | zipCd |
  | 000001 | 302   |
And the request is submitted with IP address "10.0.0.1"
```

**Then** (預期結果)
- 描述預期的結果或驗證
- 複數個 Then 用 `And` 連接
- ⚠️ **優先使用現有通用驗證 Step**，不要自創新的驗證 Step

**✅ 正確範例（使用現有通用驗證）**:
```gherkin
Then Response should be "OK"
And the response should be contain following fields
  | mbleTelNbr |
  | 0912987654 |
```

**❌ 錯誤範例（自創驗證 Step）**:
```gherkin
Then Contact info should be updated with new phone "0912987654"
And Change audit log should be recorded with customer ID and timestamp
And Database should not be updated
```

**說明**：
- `Response should be "OK"` 和 `the response should be contain following fields` 是現有通用 Step
- 這些 Step 在 `ValidateStep.java`、`CustomerStep.java` 中已定義
- 避免為每個 Feature 撰寫專屬的驗證邏輯

**如何檢查現有驗證 Step**：
1. 查看 `src/test/java/com/yhao/step/ValidateStep.java`
2. 查看 `src/test/java/com/yhao/step/CustomerStep.java`
3. 搜尋 `@Then` 註解找到所有可用的驗證 Step

---

## ⭐ 黃金範本 (Gold Standard Example)

```gherkin
Feature: Apply for card reissue with updated shipping address
  As a Retail Banking Customer
  I want to request a card reissue and update my shipping address at the same time
  So that the new card will be delivered to my preferred location

  Background: Establish baseline account
    Given A Active TW account person call "TestCustomer" with following fields
      | custNm          | birthDay | gender |
      | 陳小明           | 19900515 | 1      |
    And the customer has an active debit card with status "ACTIVE"
    And the customer's current shipping address in the system
      | addrHrcyCd | zipCd | bsicAddrCont | dtlAddrCont    |
      | 07         | 302   | 新竹縣竹北市  | 成功路100號    |

  Scenario: Customer successfully applies for card reissue with new shipping address
    When The customer "TestCustomer" requests card replacement and provides new shipping address with following fields
      | addrHrcyCd | addrId          | zipCd | bsicAddrCont | dtlAddrCont   | shpgAddrTpCd | ipAddr   |
      | 07         | 000000000000063 | 300   | 新竹市東區    | 民雄路50號    | 01           | 192.168.1.1 |
    Then The response message code should be "LBNA000001"
    And the response should be contain following fields
      | messageId  | cardStatus        |
      | LBNA000001 | PENDING_DELIVERY  |
    And the card order should be created with status "PROCESSING"
    And the shipping address should be updated in the system

  Scenario: Card reissue request fails with invalid shipping address format
    When The customer "TestCustomer" requests card replacement with invalid address
      | zipCd     | bsicAddrCont | dtlAddrCont |
      | INVALID   | 無效地區      | 無效街道    |
    Then The response message code should be "LBNA000002"
    And the error message should indicate "Invalid address format"
    And no card order should be created
```



## ✅ 最佳實踐 (Best Practices)

### Do's
- ✓ 每個 Scenario 驗證**單一業務行為**
- ✓ 使用 **DataTable** 組織複雜資料
- ✓ Step 名稱要**具體清晰**，用動詞開頭
- ✓ **優先重用既有 Step**，避免重複定義
- ✓ Background 包含所有 Scenario 需要的前置條件
- ✓ 註釋 DataTable 欄位的含義（如需要）

### Don'ts
- ✗ 使用中文 Gherkin 關鍵字
- ✗ Scenario 超過 15 個步驟（過於複雜，應拆分）
- ✗ 硬編碼測試資料在 Step 中（應用 DataTable）
- ✗ 技術細節滲入 Step 描述（應使用業務語言）
- ✗ 建立過度相似的 Scenario（合併或使用 Scenario Outline）
- ✗ 在 Feature 檔案中混雜多個業務場景（應按功能分檔）
- ✗ 自創新的 Given Step 來模擬外部系統狀態（EDW、第三方 HTTP、DB 資料）
- ✗ 為無法在整合測試中控制的前置條件硬寫假 Given（應改用 `@Pending`）
- ✗ 斷言無法從 API 回應表面觀察的內部行為（例如「某服務沒有被呼叫」）
- ✗ 在 DataTable 填入 `lineUid`、`nid`、`custId`、`mainAcctNbr`、`arrId`——這些由 Background CommonStep 自動建立，Step 層透過 `context().get(name).getXxx()` 取得

---

## 🚦 整合測試限制與 @Pending 使用規則

Cerberus 是**整合測試框架**，測試直接打後端 API，不支援 mock 外部系統。

### 可自動化 vs 需 @Pending 的判斷標準

| 情境 | 判斷 | 做法 |
|------|------|------|
| 輸入驗證（custId 為空、格式錯誤） | ✅ 可自動化 | 正常寫 Scenario |
| 查無資料（新建帳號天然無記錄） | ✅ 可自動化 | 正常寫 Scenario |
| 需要外部系統有特定資料（EDW 有通報記錄） | ⏸ 需預存測試資料 | `@Pending` + `# TODO: 需要...` |
| 需要外部系統回傳錯誤（EDW 呼叫失敗） | ⏸ 需 WireMock/stub | `@Pending` + `# TODO: 需要 WireMock...` |
| 驗證某個內部呼叫「沒有發生」 | 🚫 無法觀察 | 註解說明，不寫 Scenario |

### @Pending Scenario 範本

```gherkin
@Pending
Scenario: Operator retrieves VASP broadcast records when EDW has data
  # TODO: Requires pre-existing test customer with known VASP broadcast records in EDW.
  #       Contact DA team to set up test data with custId="TEST_VASP_01" before enabling.
  # Covers: AC-S-04
  When the operator queries VASP broadcast history for customer "Tester" using "QRY_VASP_BROADCAST"
  Then the response message code should be "LBNA000001"
  And the response data list "broadCastList" should not be empty
```

### 核心原則
- `@Pending` **不是跳過**，是「已設計、待環境就緒」的標記
- 每個 `@Pending` 必須附上 `# TODO:` 說明缺少什麼（測試資料 / WireMock / 環境設定）
- 不要為了讓 Coverage 100% 而自創無法執行的 Given Step

---

## 📌 需求 ID 對應規則（Covers 標記）

### 每個 Scenario 必須標記對應的需求 ID

需求文件中的驗收條件（AC）和測試案例（TC）ID，**必須原樣**對應到 Feature Scenario：

```gherkin
Scenario: CC Load batch rejects execution when baseDt parameter is missing
  # Covers: AC-L-02
  When Execute batch that jobId is "BZDP0260005" on BXM with following fields
    ...
```

### ID 命名格式來自需求文件，不自行發明

| 需求文件 ID 格式 | 說明 | 範例 |
|---|---|---|
| `AC-S-XX` | Service 驗收條件 | `AC-S-01`（qryLmtCd 更新成功） |
| `AC-L-XX` | CC Load Batch 驗收條件 | `AC-L-02`（缺少 baseDt） |
| `AC-D-XX` | Daemon 驗收條件 | `AC-D-01`（單檔派送成功） |
| `AC-R-XX` | Result Reply 驗收條件 | `AC-R-01`（EAI 成功） |
| `TC-L-XX` | CC Load 測試案例 | `TC-L-01`（完整流程） |
| `S-BR-XX` | Service 業務規則 | `S-BR-03`（冪等設計） |

> 中段前綴（`S-`、`L-`、`D-`…）是各需求文件自己的分類，不同需求書可能不同，一律沿用原文件。

**程式碼補充 AC（P4 新建，非需求文件自帶）**：P3 從原始碼萃取、需求書未提及的規則，由 P4 以驗證方向命名並標 `[CODE-DERIVED]`：

| ID 格式 | 說明 | 範例 |
|---|---|---|
| `AC-POSITIVE-XX` | 正向情境（成功路徑、合法分支） | `AC-POSITIVE-01`（主帳戶查詢成功） |
| `AC-NEGATIVE-XX` | 反向情境（拒絕條件、錯誤碼） | `AC-NEGATIVE-02`（重複請求被拒） |
| `AC-BOUNDARY-XX` | 邊界情境（上下限、格式極值、空值） | `AC-BOUNDARY-01`（金額為 0） |

⚠️ **禁止自行發明 `BR-01`、`AC-04` 這類沒有對應需求文件、也非 CODE-DERIVED 規範的 ID。**

---

### 多 Scenario ↔ 需求 ID 的對應關係

需求 ID 與 Scenario 並非一對一。以下三種關係都是合法且常見的：

#### 關係 1：多個 Scenario → 同一個 AC（同一驗收條件有多個測試維度）

當一條 AC 涵蓋多種輸入組合，每種組合各寫一個 Scenario，全部標同一個 `Covers`：

```gherkin
# AC-S-08: 任一必填欄位為空 → LBEA000083
# 需要 4 個 Scenario 分別驗證各欄位

Scenario: Service rejects when custId is empty
  # Covers: AC-S-08
  ...

Scenario: Service rejects when arrId is empty
  # Covers: AC-S-08
  ...

Scenario: Service rejects when pdCndCd is empty
  # Covers: AC-S-08
  ...
```

**Coverage Table 中只出現一次，標記「Covered（3 scenarios）」：**
```
| AC-S-08 | ✅ | Service rejects when required field is empty (×3 scenarios) | ✅ Covered |
```

#### 關係 2：一個 Scenario → 多個 AC/TC（一個測試同時驗證多條規則）

當同一個 Scenario 的執行結果可以同時驗證 AC 和其對應的 TC：

```gherkin
Scenario: CC Load batch fails when arrId is empty in data row
  # Covers: AC-L-08, TC-L-02
  # AC-L-08: arrId 為空 → FAILED + err/ 有 .ERR
  # TC-L-02: 檔中某筆 arrId 為空的具體測試案例
  ...
```

**Coverage Table 中兩個 ID 各出現一次，都標記 Covered，並指向同一個 Scenario：**
```
| AC-L-08 | ✅ | CC Load fails when arrId is empty             | ✅ Covered |
| TC-L-02 | ✅ | CC Load fails when arrId is empty (same scen) | ✅ Covered |
```

#### 關係 3：一個 Scenario → 一個 AC（標準一對一）

最常見的情況，一個具體場景對應一條驗收條件：

```gherkin
Scenario: CC Load batch rejects execution when baseDt parameter is missing
  # Covers: AC-L-02
  ...
```

---

### Coverage Table 格式（Feature 檔結尾必填）

Coverage Table 的 `Requirement` 欄位必須使用需求文件的**實際 ID**，且每條需求只出現一次。
**必須有「說明」欄**——一句話業務描述（沿用需求規格 AC 條目的說明文字），讓不熟編號的人也能看懂每列在驗什麼：

```
| Requirement | 說明                         | Testability | Scenario Name                                                 | Coverage                                      |
|-------------|------------------------------|-------------|---------------------------------------------------------------|-----------------------------------------------|
| AC-L-02     | 缺少 baseDt 參數時批次拒絕執行 | ✅          | CC Load batch rejects when baseDt is missing                  | ✅ Covered                                    |
| AC-S-08     | 任一必填欄位為空即拒絕         | ✅          | Service rejects when required field is empty (×4 scenarios)   | ✅ Covered                                    |
| AC-L-08     | 資料列 arrId 為空產出 ERR 檔   | ⏸️          | —                                                             | ⏸️ Not Written — TODO: needs .SAM file upload |
| L-BR-06     | CC 路由為內部行為              | 🚫          | —                                                             | 🚫 Not Observable — writer is internal no-op  |
```

### Coverage Summary 格式（Coverage Table 之後必填，雙分母）

涵蓋率必須用**兩個分母**呈現，避免「需求文件涵蓋率高、但程式碼規則漏掉」的虛高假象：

```
# ============ COVERAGE SUMMARY ============
# Requirement coverage : 8/10 ACs covered (2 Not Written)
#   — denominator: all AC/TC/BR IDs in requirement spec
# Code-rule coverage   : 11/12 P3 rules traced (missing: BV3)
#   — denominator: all P3 source IDs (V/B/E/BV) referenced by CODE-DERIVED ACs
# ==========================================
```

- **Requirement coverage**：分母 = 需求規格中所有 AC / TC / BR 條目數
- **Code-rule coverage**：分母 = 需求規格中 `[CODE-DERIVED]` AC 標注的 P3 來源編號（V/B/E/BV）去重總數；分子 = 已被 Scenario 或 MANUAL TEST GUIDE 覆蓋的來源編號數
- 任一來源編號未覆蓋 → 在 `missing:` 列出，並說明原因

### MANUAL TEST GUIDE 區塊格式（Not Written 的 AC 必填）

無法自動化的 AC（`⏸️ Not Written`）不寫 Scenario，改在 feature 檔加入手動測試指引，步驟需具體到 QA 不看原始需求文件也能執行：

```gherkin
# =========================================================
# NOT WRITTEN: <AC ID> — <reason: 依賴什麼外部基礎設施>
#
# MANUAL TEST GUIDE:
#   Prerequisite: <測試前需要準備什麼：帳號狀態、外部傳檔、DB seeding 等>
#   Test Steps:
#     1. <第一步>
#     2. <第二步>
#     3. <第三步>
#   Expected Result: <預期系統行為或回應>
#   Note: <任何需要特別注意的環境條件或操作限制>
# =========================================================
```

