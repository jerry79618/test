# Cerberus Copilot Instructions

> 本檔為 Cerberus 專案的全域 Copilot 規範。
> Feature 細節規範請見 `.github/instructions/feature.instructions.md`，Java/Step 細節規範請見 `.github/instructions/stepCode.instructions.md`。

## 溝通規範
- 回應使用 **繁體中文**
- 複雜邏輯註解使用 **繁體中文**
- 代碼內容保持 **英文** (變數名、類別名、Gherkin 關鍵字)
- Feature/Scenario 描述與步驟文字需使用**銀行業務可理解用詞**，避免技術術語

---

## 專案結構
```text
src/test/java/com/
├── step/          # Step Definitions (繼承 CucumberBase)
├── requestBO/     # Request Body Objects
├── responseBO/    # Response Body Objects
├── alias/         # Enums
├── client/        # API Client
├── service/       # 業務邏輯 Helper
├── util/          # 工具類
├── CIFData.java   # 核心資料物件
├── Context.java   # 測試 Context
└── CBKConfig.java # 專案設定
```

### 核心 Enum
- `com.yhao.alias.CBKServiceCode` - 服務代碼
- `com.yhao.alias.LBSystem` - 系統代碼
- `com.yhao.alias.ReviewCode` - 審核代碼

---

## Service Code 規範

這是跨 Feature 與 Step 層的核心約束，所有開發活動都必須遵守。

- `Feature` 層以業務流程描述為主，原則上**不在 Scenario 文字中直接呈現** `Service Code`、`LBSystem`
- 測試需求、開發 prompt 與 Step 實作層，應**明確指出並綁定**對應的 `Service Code`
- 若同一業務流程可能對應多個服務，需標明本次驗證的**主要 `Service Code`**
- 若未提供 `Service Code`，需先確認服務範圍，再撰寫 Step 或 Helper，避免案例目標模糊
- 若需跨系統驗證，應於需求/Step 層一併標明對應的 `LBSystem`
- 若為**新增 Step**且同時導入**新的 Service Code**，需求/Prompt 必須提供：
  - **Input 欄位**（必要參數、格式、邊界條件）
  - **預期 Output 欄位**（回應碼、關鍵欄位、狀態/業務結果）
- 若 Step 實作結果與既有 Feature 敘述不一致，需**同步調整 Feature 內容**，確保案例敘述與實作行為一致

### Feature 前置假設與環境要求

**應在 Feature 標題下方的註釋中明確說明**：
- **環境要求**：本地開發環境 / 測試環境 / 預發佈環境
- **帳戶前置**：需要什麼狀態的帳戶（TW account, KYC approved, Active status 等）
- **時間限制**：是否有營業時間限制（如 EOD 流程、日切時間）
- **Service Code**：指定的服務代碼

```gherkin
Feature: Deposit Money into Main Account
  # 環境要求: MBK System only (LBSystem: MBK)
  # 帳戶前置: 已激活的 TW 帳戶，須通過 KYC，帳戶狀態為 ACTIVE
  # 時間限制: 須在營業時間內 (09:00-17:00)
  # Service Code: SZDPF023011
```

---

## 通路範圍限制
- 本專案測試案例僅針對**單一通道**流程
- 撰寫 Feature/Scenario 時，不需額外延伸或推導其他通路情境
- 不納入 ATM、臨櫃存款等非本專案範圍之通路案例

---

## 🔗 跨服務場景處理規範

### 多個 Service Code 在同一 Feature 的協調

**原則**：
- Feature 只表達業務流程，不呈現技術性的服務代碼
- 若涉及多個服務（如開戶 = QRY + CREATE + VERIFY），Feature 層描述業務流程，Step 層綁定每一步的 Service Code
- Background 或 Scenario 註釋中應標明服務執行序列（便於維護者理解）

**✅ 正確範例**：
```gherkin
Feature: Account Opening Complete Flow
  # 服務序列: 
  #   1. QRY_CUST_EXIST (查詢客戶是否存在)
  #   2. CREATE_ACCOUNT (建立賬戶)
  #   3. VERIFY_KYC (驗證 KYC)
  # Service Code Mapping 見 Step 層 AccountOpeningStep.java

  Background: Setup customer data
    Given a new customer "John" with NID "A123456789"
    # 此步驟觸發 QRY_CUST_EXIST

  Scenario: Complete account opening with KYC verification
    When customer "John" submits account opening request with KYC documents
    # Step 內觸發:
    #   - CREATE_ACCOUNT (Service Code: SZDPF001001)
    #   - VERIFY_KYC (Service Code: KYC_VERIFY_001)
    Then account opening request should be successful
    And the account status should be "ACTIVE"
```

**Step 層必須明確綁定 Service Code**：
```java
@When("customer {string} submits account opening request with KYC documents")
public void submitAccountOpening(String custName) {
    // 第一步：CREATE_ACCOUNT (Service Code: SZDPF001001)
    CBKHeader header1 = CBKHeaderHelper.getDefault(CBKServiceCode.CREATE_ACCOUNT);
    CBKResponse resp1 = clientHelper.post(endpoint, header1, createAccountBody);
    
    // 第二步：VERIFY_KYC (Service Code: KYC_VERIFY_001)
    CBKHeader header2 = CBKHeaderHelper.getDefault(CBKServiceCode.KYC_VERIFY);
    CBKResponse resp2 = clientHelper.post(endpoint, header2, verifyKYCBody);
    
    context().put("accountOpeningResponse", resp1);
    context().put("kycVerifyResponse", resp2);
}
```

### 跨服務場景驗證要點

1. **服務執行順序驗證**：確認服務必須按正確順序執行（例如，不能先 VERIFY_KYC 再 CREATE_ACCOUNT）
2. **服務間資料流驗證**：第一個服務的輸出是否正確傳遞給第二個服務
3. **部分失敗處理**：如果第一個服務成功、第二個失敗，系統是否有正確的回滾邏輯
4. **跨服務 message code**：驗證最終回應的 message code 是否反映整個流程的結果
5. **Service Code 綁定正確性**：確認每一步的 Service Code 是否與業務需求一致

**跨服務場景避免混亂的檢查清單**：
- [ ] Feature 描述是否清晰（不含技術服務代碼）
- [ ] Background / Scenario 註釋中是否標明服務序列
- [ ] 每個 Service Code 是否在 Step 層明確綁定
- [ ] 是否驗證了服務間的資料傳遞正確性
- [ ] 是否驗證了失敗情況下的系統行為
- [ ] 所有涉及的 Service Code 是否都有對應的 Step 實作

---

## 驗證重點

### 通用驗證準則
- **服務識別驗證**:
  - 確認需求或 Step 對應的 `Service Code` 是否明確
  - 確認案例是否驗證到正確的服務流程，而非相似功能
  - `Feature` 文字以業務語意呈現，服務代碼驗證放在 Step/執行流程層

- **Input 驗證**:
  - Null 值測試
  - 空值測試
  - 特殊字符/編碼測試
  - 類型轉換驗證
  
- **Output 驗證**:
  - 返回值正確性
  - 返回值類型匹配
  - 返回值格式規範 (日期格式、金額小數位等)
  - 返回值是否為 null/empty
  
- **業務邏輯驗證**:
  - 前置條件檢查
  - 後置條件驗證
  - 狀態轉換合法性
  - 金額計算精度 (6位小數位等)

### 日期與年份驗證
- 驗證年份格式: 確保 YYYY/yyyy 一致性，特別是跨年份邊界情況
- 跨年份邊界: 須驗證12月31日 → 1月1日的轉換邏輯
- 跨月邊界: 驗證各月最後一日的邊界情況 (如28/29/30/31)
- 時間邊界: 測試 23:59:59 → 00:00:00 的轉換

### 跨年度常見案例 
- **交易日切換**: 驗證 12/31 → 1/1 的 Business Date 與營業日順延
- **利息與費用**: 驗證跨年計息、結息、年費/管理費扣收正確性
- **額度重置**: 驗證日/月/年限額在新年度是否正確重置
- **參數生效**: 驗證新年度費率、限額、規則於生效日正確套用

### 數據邊界驗證
- **最小值測試**: 邊界下限 (如 0, null, 空字符串)
- **最大值測試**: 邊界上限 (如整數最大值、字符串長度上限)
- **數值範圍**: 確認有效範圍內外的行為 (如金額 0.00 vs 999999.99)
- **字符串邊界**: 
  - 空字符串 `""`
  - 單個字符 `"a"`
  - 特殊字符 (空格、特殊符號、Unicode)
  - 長度邊界值 (如恰好達到上限)
- **集合邊界**:
  - 空列表 (size = 0)
  - 單元素列表 (size = 1)
  - 最大容量邊界




## 重要注意事項


### 時間相關
- ⚠️ 測試涉及當前時間時，必須使用 `System.currentTimeMillis()` 或系統時鐘，勿使用硬編碼日期
- ⚠️ 跨時區測試須確認時區處理邏輯正確


### 資料完整性
- ⚠️ 驗證所有必填欄位實際被填充
- ⚠️ 檢查資料庫中資料完整性，不依賴前端驗證
- ⚠️ 測試資料刪除和軟刪除邏輯

### 狀態管理
- ⚠️ 驗證不合法的狀態轉換被拒絕
- ⚠️ 測試並發修改同一資源的行為
- ⚠️ 驗證幂等性，同一請求多次執行結果一致


### 測試維護
- ⚠️ 定期檢查測試資料的有效性
- ⚠️ 避免測試間的隱性依賴 (確保測試獨立)
- ⚠️ 清理測試環境 (teardown 務必執行)
- ⚠️ 記錄易失敗的場景與原因，建立 FAQ

