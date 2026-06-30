# GitHub Copilot 提問參數卡 (Cerberus Project)

本文件提供「填空式」Prompt 範本。請複製對應區塊，填寫 `[ ]` 內的內容後發送給 Copilot。
**注意**：Copilot 已透過 `.github/copilot-instructions.md` 了解專案規範`，並且回應內容皆須回應中文


---

## 🌟 任務一：撰寫 Feature (BDD Step 1)
*請選擇 A 或 B 填寫，Copilot 將自動產生/修改 Feature 檔案。*

### Option A: 新增 Feature 檔 (Create New)
```markdown
**Create New Feature File**:
- **需求說明**: [例如：APP 使用者登入]
- **資料欄位**:
  - [欄位: birthDt]

```

### Option B: 修改既有 Feature 檔 (Modify Existing)
```markdown
**Modify Existing Feature File**:
- **目標檔案**: [例如: login.feature]
- **修改需求**:
  - [例如: 新增一個 Scenario 測試密碼過期]
  - [例如: 修改 Scenario "Login Success" 的輸入資料]
- **業務規則**: [補充新的規則]
```

---

## 🌟 任務二：實作程式碼 (BDD Step 2)
*請在 Copilot 產生 Feature 後，選擇 A 或 B 填寫並發送。*

### Option A: 全新功能實作 (New Feature)
```markdown
**New Feature Implementation**:
- **API 代碼**: [例如: SZCUA01L001]
- **欄位對應**: Feature `[Gherkin Field]` -> RequestBO `[Java Field]`
- **特殊邏輯**: [例如: 密碼需加密]

**執行指令**:
1. **Enum**: 在 `CBKServiceCode` 新增代碼。
2. **RequestBO**: 建立新物件 (繼承 `CBKRequestBody`)。
3. **Helper**: 建立新 Helper `[FeatureName]Helper`，實作靜態建構方法 (輸入 `CIFData`)。
4. **Step**: 建立 `[StepClassName]`，繼承 `CucumberBase`。
   - 使用 `DataTableHelper` 處理輸入。
   - 使用 `context().get(name)` 取得 `CIFData`。
   - 呼叫 Helper 與 `clientHelper`。
```

### Option B: 修改既有實作 (Modify Existing)
```markdown
**Modify Existing Implementation**:
- **目標 API**: [Service Code]
- **新增欄位**: Feature `[New Field]` -> RequestBO `[Java Field]`
- **邏輯變更**: [說明變更點]

**執行指令**:
1. **RequestBO**: 更新 `[ExistingRequestBO]`。
2. **Helper**: 更新 `[HelperClass]` 的 `[MethodName]` (確保不影響舊測試)。
3. **Step**: 更新 `[StepClass]` 的 `[StepMethod]`。
```

---

## ⚡ 任務三：快速實作 (Code First)
*不寫 Feature，直接寫 Code。*

```markdown
**Code First Implementation**:
- **API 名稱**: [Name]
- **API 代碼**: [Service Code]
- **Request 欄位**: [列出關鍵欄位]
- **特殊邏輯**: [說明]

**執行指令**:
請依照 `copilot-instructions.md` 規範，按順序實作：
1. **Enum**: 新增代碼。
2. **RequestBO**: 建立物件。
3. **Helper**: 建立新 Helper `[FeatureName]Helper`。
4. **Step**: 建立 `[StepClassName]` (繼承 `CucumberBase`)。
```

---

## 🛠️ 任務四：輔助指令

### 修正錯誤 (Fix)
```markdown
🛑 **Correction Needed**:
- **錯誤類型**: 違反專案規範 (Project Pattern Violation)

**修正指令**:
1. **Helper**: 邏輯移到 `[HelperClass]`。
2. **繼承**: Step 必須繼承 `CucumberBase`。
3. **Client**: 只能使用 `clientHelper.post`。
4. **Data**: 必須使用 `DataTableHelper`。
```

### 資料庫驗證 (DB Check)
```markdown
**DB Validation**:
- **客戶**: [Name]
- **資料表**: [Table Name]
- **預期結果**: 欄位 `[Column]` 應為 `[Value]`

**執行指令**:
使用 `DbHelper` 與 `DatasourceUtil.getCbkConn()` 進行查詢與 Assert。
```


### Option A: 全新功能實作 (New Feature - Standardized)

**New Feature Implementation**:
- **API 代碼**: `[例如: SZCUA01L001]`
- **功能描述**: `[一句話描述]`
- **欄位映射**:
  | Gherkin Field | RequestBO Field | Type   | Note |
  |---------------|-----------------|--------|------|
  | `custNm`      | `customerName`  | String | 必填 |
  | `[欄位2]`     | `[欄位2]`       | `[型別]`| `[備註]`|

**Thinking Process (必須執行)**:
1. 請先搜尋 `com.yhao.alias.CBKServiceCode` 確認代碼是否重複。
2. 規劃 Helper 的方法簽章 (Signature)，確保輸入參數包含 `CIFData`。

**執行指令**:
1. **Enum**: 在 `CBKServiceCode` 新增代碼。
2. **RequestBO**: 建立新物件 (必須使用 `@Builder`)。
3. **Helper**: 建立 `[FeatureName]Helper`，實作靜態方法。
4. **Step**: 建立 `[StepClassName]` (extends `CucumberBase`)。

**✅ Quality Gate (自我檢查)**:
- [ ] 確保沒有使用中文 Gherkin 關鍵字。
- [ ] 確保 Request Body 是透過 Helper 建構，而非在 Step 中組裝。
- [ ] 確保使用了 `context().setResponse()` 儲存結果。

**Create New Feature File**:
- User Story: 需求內容 `
- **關鍵資料欄位 (用於 DataTable)**:
  - `[欄位1: addrId]`
  - `[欄位2: zipCd]`
  - `[欄位3: birthDt]`
- **測試情境矩陣 (Scenarios)**:
  1. `[描述正向流程]`
  2. `[反向流程代碼，例如: 地址格式錯誤回傳 LBNA000002]`
  3. `[描述邊界值，例如: 地址長度超過限制]`

**Constraints**:
1. **Reference**: 嚴格參照 `copilot-instructions.md` 中的 "Standard Feature File Example"。
2. **No UI Steps**: 絕對禁止使用 "Click button", "Enter text" 等 UI 描述。必須使用 使用者層級描述 (e.g., "Customer requests...").
3. **Keywords**: Gherkin 關鍵字 (`Given`, `When`, `Then`) 必須為 **英文**。
4. **Data**: DataTable 內的測試數據使用 **繁體中文**。