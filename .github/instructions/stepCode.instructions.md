---
applyTo: "src/test/java/com/yhao/**/*.java"
---

# Java 代碼風格 (Java Code Style)

Cerberus 專案的 Java 程式碼規範與最佳實踐。

## 📝 基本風格規範

### 遵循標準
- **Google Java Style Guide**
- **縮排**: 4 個空白（不使用 Tab）
- **編碼**: UTF-8
- **行寬**: 建議 ≤ 120 字元

### 命名規範

#### 類別 (Classes) - PascalCase
```java
✓ CustomerStep
✓ CardReissueHelper
✓ TransferFundsRequest
✓ AccountResponse

✗ customerStep
✗ Card_Reissue_Helper
```

#### 方法與變數 (Methods & Variables) - camelCase
```java
✓ processCardReissue()
✓ custNm
✓ birthDay
✓ addressHierarchyCode

✗ ProcessCardReissue()
✗ CustNm
✗ address_hierarchy_code
```

#### 常數 (Constants) - UPPER_SNAKE_CASE
```java
✓ MAX_RETRIES = 3
✓ DEFAULT_TIMEOUT = 5000
✓ SERVICE_CODE_CARD_ISSUE = "SZCUA010001"

✗ maxRetries
✗ Max_Retries
```

#### 檔案名稱
```
✓ CustomerStep.java
✓ CardReissueHelper.java
✓ CardReissueRequest.java
✓ CardReissueResponse.java

✗ customer_step.java
✗ Card-Reissue-Helper.java
```

---

## 🔑 測試資料鏈：custClient → CIFData → context()

這是 Cerberus 測試框架的**核心資料流**，所有 Step 開發者必須理解。

### 資料建立流程（Background 自動完成）

```
CommonStep.aActiveTWAccountPerson()
  └── clientHelper.createCustomer(CustomerRequest)
        └── custClient.createCustomer()          ← CustClient (com.linebank.cust.client)
              └── CustomerResponse
                    ├── custId          → CIFData.custId
                    ├── nid             → CIFData.nid
                    ├── lineUid         → CIFData.lineUid
                    ├── mainAccountNumber → CIFData.mainAcctNbr
                    └── arrId           → CIFData.arrId
  └── context().set("Tester", cifData)   ← 以 Scenario 中的名稱為 key 存入 context
```

### CIFData 完整欄位清單

| 欄位 | 說明 | 來源 |
|------|------|------|
| `custId` | 客戶 ID | CustomerResponse |
| `nid` | 身分證號 | CustomerResponse |
| `lineUid` | LINE UID | CustomerResponse |
| `mainAcctNbr` | 主帳號 | CustomerResponse |
| `arrId` | 安排 ID | CustomerResponse |
| `custNm` | 客戶姓名 | CIFData（可從 DataTable 補充） |
| `birthDay` | 出生日期 | CIFData（可從 DataTable 補充） |
| `phoneNumber` | 手機號碼 | CIFData（可從 DataTable 補充） |
| `addrId` | 地址 ID | CIFData（可從 DataTable 補充） |

### Step 中取用 CIFData 的標準寫法

```java
// ✅ 正確 — 從 context 取得 CIFData，再取所需欄位
CIFData cifData = context().get("Tester");
String lineUid   = cifData.getLineUid();
String nid       = cifData.getNid();
String custId    = cifData.getCustId();
String mainAcctNbr = cifData.getMainAcctNbr();

// ❌ 錯誤 — 不要讓 Feature DataTable 傳入 lineUid / nid / custId
// 這些欄位由 Background CommonStep 自動建立，不應由測試者手動填寫
```

### custClient 使用規範

`custClient` 封裝於 `ClientHelper.createCustomer()`，**只在 CommonStep（Background）使用**。  
業務 Step 不直接呼叫 `custClient`，而是透過 `context().get(name)` 取得已建立的 CIFData。

```java
// ✅ 業務 Step 的標準做法
@When("the customer {string} requests card replacement with the following details")
public void requestCardReplacement(String custName, DataTable dataTable) {
    CIFData cifData = context().get(custName);        // 從 context 取得 CIFData
    Map<String, String> fields = DataTableHelper.toMap(dataTable);
    
    CardReissueRequest request = CardReissueRequest.builder()
        .custId(cifData.getCustId())                  // 來自 CIFData
        .lineUid(cifData.getLineUid())                // 來自 CIFData
        .zipCd(fields.get("zipCd"))                   // 來自 Feature DataTable
        .build();
    // ...
}
```

---

## 🏗️ Step Definition 規範

### 類別結構
```java
// Step 必須繼承 CucumberBase
@Slf4j
public class CardReissueStep extends CucumberBase {
    
    // 使用 @Given, @When, @Then 註解標記 Step
    @When("The customer {string} requests card replacement with the following details")
    public void requestCardReplacement(String custName, DataTable dataTable) {
        // 業務邏輯實作
    }
}
```

### 重要規則
1. **必須繼承 `CucumberBase`**
   ```java
   public class MyStep extends CucumberBase {
       // 可直接使用 context(), clientHelper 等方法
   }
   ```

2. **使用 `@Slf4j` 註解進行日誌**
   ```java
   @Slf4j
   public class CardReissueStep extends CucumberBase {
       public void someMethod() {
           log.info("執行卡片重新發行邏輯");
       }
   }
   ```

3. **不要在 Step 中直接 `new` 物件**
   ```java
// ✗ 不推薦
public void myStep() {
    HttpClient client = new HttpClient();  // 錯誤！
    client.post(...);
}

// ✓ 推薦
public void myStep() {
    clientHelper.post(...)// 使用繼承自 CucumberBase 的 clientHelper
}
```

4. **使用 `DataTableHelper` 處理輸入**
   ```java
   @When("The customer {string} requests card replacement with the following details")
   public void requestCardReplacement(String custName, DataTable dataTable) {
       // DataTableHelper 會自動轉換為 Map<String, String>
       Map<String, String> fields = DataTableHelper.toMap(dataTable);
       String zipCode = fields.get("zipCd");
   }
   ```

5. **使用 `context()` 傳遞資料**
   ```java
   // 存儲資料
   CIFData cifData = context().get("customerName");
   
   // 取出資料
   Response response = context().get("response");
   ```

### Step 命名規範
```java
// ✓ 清晰的 Step 名稱
@When("The customer {string} requests card replacement and provides new shipping address with following fields")
public void requestCardReplacement(String custName, DataTable dataTable) {
    // 實作
}

// ✗ 不清晰的 Step 名稱
@When("The user does something with the following data")
public void doSomething(String user, DataTable dataTable) {
    // 實作
}
```

---

## 📦 RequestBO / ResponseBO 規範

### 使用 Lombok 簡化程式碼
```java
// ✓ 使用 Lombok
@Data
@Builder
public class CardReissueRequest extends CBKRequestBody {
    private String custNm;              // 客戶名稱
    private String birthDay;            // 出生日期 (YYYYMMDD)
    private String addrHrcyCd;          // 地址階層代碼
    private String addrId;              // 地址 ID
    private String zipCd;               // 郵遞區號
    private String bsicAddrCont;        // 基本地址內容
    private String dtlAddrCont;         // 詳細地址內容
    private String shpgAddrTpCd;        // 配送地址類型代碼
    private String ipAddr;              // IP 位址
}
```

### 常見 Lombok 註解

| 註解 | 用途 | 範例 |
|-----|------|------|
| `@Data` | 自動生成 Getter/Setter/equals/hashCode/toString | 大部分 BO 類別 |
| `@Builder` | 提供 Builder 模式 | RequestBO 建構 |
| `@Getter` | 僅生成 Getter | 唯讀欄位 |
| `@Setter` | 僅生成 Setter | 特定欄位 |
| `@Slf4j` | 自動注入 `log` 變數 | 有日誌需求的類別 |
| `@NoArgsConstructor` | 無參建構子 | 框架需要 |
| `@AllArgsConstructor` | 全參建構子 | 手動建構物件 |

### RequestBO 設計原則

1. **繼承 `CBKRequestBody`**
   ```java
   public class CardReissueRequest extends CBKRequestBody {
       // 所有請求欄位
   }
   ```

2. **欄位映射與 API 文件保持一致**
   ```java
   // 變數名稱應與 JSON 欄位名稱相同
   private String custNm;         // API 文件中: "custNm"
   private String birthDay;       // API 文件中: "birthDay"
   ```

3. **⚠️ RequestBO 必須包含 P3 分析中所有 Input 欄位（必填 + 選填全部）**

   > P6 產生 RequestBO 時，**不得只放 Feature Scenario 用到的欄位**。  
   > 應將 P3 code-analysis 報告中 `Input 欄位` 表格的**所有欄位**（無論必填與否）完整對應。

   ```java
   // ✅ 正確：完整對應 SvcIn 所有欄位（含 FDS 選填欄位）
   @Data
   @Builder
   public class LineFriendsTrnsfrBO extends CBKRequestBody {
       private String custId;               // ✅ 必填
       private String wdrwAcctNbr;          // ✅ 必填
       private BigDecimal txfrAmt;          // ✅ 必填
       private String txfrSndrLineNick;     // ✅ 必填
       private String txfrRcvrLineUid;      // ✅ 必填
       private String txfrRcvrLineNick;     // ✅ 必填
       private String txMemoVal;            // ❌ 選填 → 仍須宣告
       private String umsTknCont;           // ❌ 選填 → 仍須宣告
       private String dvceNm;              // ❌ FDS 選填 → 仍須宣告
       private String loinId;              // ❌ FDS 選填 → 仍須宣告
       // ... 其餘所有 SvcIn 欄位
   }

   // ❌ 錯誤：只放 Scenario 用到的欄位，FDS 欄位全部省略
   @Data
   @Builder
   public class LineFriendsTrnsfrBO extends CBKRequestBody {
       private String custId;
       private String wdrwAcctNbr;
       private BigDecimal txfrAmt;
       // 缺少 dvceNm, loinId, sssnId ... 等 FDS 欄位 ← 不允許
   }
   ```

   **理由**：BO 是 API 契約的完整映射。若未來需要補測 FDS 情境或邊界值，缺欄位會造成 BO 需要手動補充，打斷開發流程。

3. **使用有意義的變數名稱**
   ```java
   // ✓ 清晰
   private String custNm;         // 客戶名稱
   private String addrHrcyCd;     // 地址階層代碼
   
   // ✗ 不清晰
   private String cn;             // 不知道是什麼
   private String ahc;            // 縮寫不清
   ```

4. **無需硬編碼預設值**
   ```java
// ✗ 不推薦在 BO 中硬編碼
@Data
@Builder
public class CardReissueRequest {
    private final String shpgAddrTpCd = "01";  // 硬編碼！
}

// ✓ 在 Helper 中設定預設值
public class CardReissueHelper {
    public static CardReissueRequest create(...) {
        return CardReissueRequest.builder()
            .shpgAddrTpCd("01")  // 預設值在這裡
            .build();
    }
}
```

### ResponseBO 設計原則

```java
@Data
public class CardReissueResponse {
    private String messageId;          // 訊息代碼
    private String messageContent;     // 訊息內容
    private String cardStatus;         // 卡片狀態
    private String orderNumber;        // 訂單編號
}
```

---

## 🔧 Helper 類別規範

### 命名與位置
```
com.yhao.service/
├── CardReissueHelper.java
├── TransferFundsHelper.java
└── AMLHelper.java
```

### 設計模式：靜態工廠方法
```java
@Slf4j
public class CardReissueHelper {
    
    // 靜態工廠方法（建議）
    public static CardReissueHelper create(CIFData cifData) {
        return new CardReissueHelper(cifData);
    }
    
    private final CIFData cifData;
    
    private CardReissueHelper(CIFData cifData) {
        this.cifData = cifData;
    }
    
    // 業務邏輯方法
    public CardReissueRequest buildRequest(Map<String, String> fields) {
        return CardReissueRequest.builder()
            .custNm(cifData.getCustNm())
            .birthDay(cifData.getBirthDay())
            .addrHrcyCd(fields.get("addrHrcyCd"))
            .addrId(fields.get("addrId"))
            // ... 其他欄位
            .build();
    }
    
    public void processResponse(CardReissueResponse response) {
        log.info("卡片重新發行結果: {}", response.getMessageId());
        // 業務邏輯
    }
}
```

### 關鍵原則
1. **業務邏輯集中在 Helper**，Step 只負責 Gherkin 與資料流轉
2. **提供靜態工廠方法** 簡化建構
3. **使用 `log` 記錄關鍵步驟**
4. **方法名稱清晰** 反映業務行為

---

## 🔄 批次測試 (BXM Batch) 規範

批次測試與線上 API 測試在客戶端和流程上有本質差異，請務必區分。

### 客戶端選擇

| 測試類型 | 使用客戶端 | 說明 |
|---|---|---|
| 線上 API (CBK/MBK) | `clientHelper.post(endpoint, header, body)` | CBK 標準流程 |
| 批次執行 (BXM) | `BatchStep` 內建 Step（直接在 Feature 使用） | BXM 批次排程系統 |
| 批次檔案上傳 | `SSHUtil.copyFileToBatServer()` | SCP 到批次伺服器 |

### Feature 層：批次步驟寫法

```gherkin
# 觸發批次執行
When Execute batch that jobId is "BZDP0260005" on BXM with following fields
  | key              | value       |
  | baseDt           | {#sysDt}    |
  | inputCenterCutId | CZDP0000001 |

# 驗證批次結果
Then Batch about jobId "BZDP0260005" execute FAILED in 10 sec
Then Batch about jobId "BZDP0260005" execute COMPLETED in 60 sec

# 上傳測試檔案到批次伺服器
When Upload SAM which context name is "testFile" to server by interface id "BZDP0260005"
```

### Step 層：需要客戶資料時的 SAM 檔案建立

若 E2E 批次測試需要 `.SAM` 檔，Step 中使用 `FileUtil.writeCsv2()` 搭配 `SSHUtil` 上傳：

```java
@When("prepare a valid SAM file for customer {string} with arrangement condition")
public void prepareSamFile(String custName) {
    CIFData cifData = context().get(custName);

    // 建立 .SAM 檔內容（格式: UTF-8, |^| 分隔, \r\n 換行）
    List<String[]> rows = new ArrayList<>();
    rows.add(new String[]{
        cifData.getCustId(),   // custId
        cifData.getArrId(),    // arrId
        "TAG001",              // cndCd
        "VALUE001"             // cndCdVal
    });

    File samFile = FileUtil.writeCsv2(rows, "BZDP0260005_test.SAM");
    
    // 上傳到批次伺服器 rcv/ 目錄
    SSHUtil.copyFileToBatServer(samFile, "/shared/bat/ZDP00/BZDP0260005/BZDP0260005_ArrCndMgmt_001/rcv/");
    context().put("samFile", samFile);
}
```

### 批次 Feature 的 Background 判斷規則

| Scenario 類型 | Background 需要？ | 理由 |
|---|---|---|
| 批次參數驗證（啟動即失敗） | ❌ 不需要 | 批次不讀 .SAM，不用 custId |
| 批次 E2E（需操作真實 .SAM） | ✅ 需要 | .SAM 內容需要 custId / arrId |

⚠️ **禁止為批次參數驗證 Scenario 加入 Background 開帳步驟** — 會造成不必要的 API 呼叫與執行時間浪費。

### 檔案格式規範（SAM 檔）

```
編碼: UTF-8
分隔符: |^|
換行: \r\n (CRLF)
副檔名: .SAM（處理中）/ .RCV（已讀取）/ .ERR（錯誤）
```

---

## 📊 Enum 規範

### 位置與組織
```
com.yhao.alias/
├── CBKServiceCode.java      # 服務代碼
├── ReviewCode.java          # 審核代碼
├── LBSystem.java            # 系統代碼
└── CardStatus.java          # 卡片狀態
```

### 定義方式
```java
// ✓ 推薦
public enum CBKServiceCode {
    CARD_REISSUE("SZCUA010001", "卡片重新發行"),
    TRANSFER_DOMESTIC("SZCUA010002", "國內轉帳"),
    QUERY_BALANCE("SZCUA010003", "查詢餘額");
    
    private final String code;
    private final String description;
    
    CBKServiceCode(String code, String description) {
        this.code = code;
        this.description = description;
    }
    
    public String getCode() {
        return code;
    }
    
    public String getDescription() {
        return description;
    }
}
```

### 使用方式
```java
// 使用 Enum 而非硬編碼字串
CardReissueRequest request = CardReissueRequest.builder()
    .serviceCode(CBKServiceCode.CARD_REISSUE.getCode())
    .build();

// 搜索對應 Enum
CBKServiceCode code = CBKServiceCode.CARD_REISSUE;
```

---

## ✅ 最佳實踐 (Best Practices)

### Do's
- ✓ 使用 Lombok 減少樣板程式碼
- ✓ Step 繼承 `CucumberBase`
- ✓ 業務邏輯在 Helper 中實現
- ✓ 使用 `clientHelper` 發送 API 請求
- ✓ 使用 `context()` 在 Step 間傳遞資料
- ✓ **非直觀的業務邏輯**才加上繁體中文註釋（例如：冪等設計、特殊錯誤碼處理）
- ✓ 使用 `ReportUtil.addText()` 記錄測試資訊

### Don'ts
- ✗ 直接 `new HttpClient` 在 Step 中
- ✗ 複雜業務邏輯在 Step 中實現
- ✗ 硬編碼環境設定（應用 `CBK_CONFIG`）
- ✗ 硬編碼測試資料在程式碼中（應用 DataTable）
- ✗ 分散的 Enum 定義（集中在 `com.yhao.alias`）
- ✗ 重複程式碼（應抽象為方法）

---

## 💬 程式碼註釋原則

### 只在「非直覺」時才加註釋

**判斷標準**：讀程式碼的人，光看方法名稱與參數就能理解的，**不需要**註釋。

```java
// ❌ 冗餘 — 方法名稱已經說明一切
// 取得 CIFData
CIFData cifData = context().get(custName);

// ❌ 冗餘 — 每一行都是自說明的
// 建立 Header
CBKHeader header = CBKHeaderHelper.getDefault(CBKServiceCode.FATCA_MAINTENANCE);
// 呼叫 API
CBKResponse response = clientHelper.post(endpoint, header, body);
// 存入 context
context().setResponse(response);

// ✅ 有意義 — 解釋為何這樣做（規格設計決策）
// AAPARE0231 代表資料已存在（冪等情境），依規格視為成功，不拋錯
if ("AAPARE0231".equals(response.getMessageId())) {
    return;
}

// ✅ 有意義 — 非直覺的業務約束
// SSA 帳戶只允許更新 L1081（跨提限制碼），其餘條件碼會被系統拒絕
```

### 方法層級的 Javadoc — 不需要

Step 方法的行為由 Gherkin Step 文字描述，不需要加 Javadoc：

```java
// ❌ 不需要
/**
 * 執行 FATCA 資訊維護
 * @param custName 客戶名稱
 * @param dataTable 輸入資料
 */
@When("the representative {action} FATCA information for {string} with following fields")
public void fatcaMaintenance(Action action, String custName, DataTable dataTable) { ... }

// ✅ 直接寫即可
@When("the representative {action} FATCA information for {string} with following fields")
public void fatcaMaintenance(Action action, String custName, DataTable dataTable) { ... }
```

### TODO 註釋 — 僅限骨架 Step

只有 `@Pending` Skeleton Step 需要 `// TODO:` 說明原因：

```java
// TODO: @Pending — 需要 WireMock 模擬 EAI 失敗，環境就緒後移除 @Pending 並實作
@When("the EAI endpoint EBATETLF026005 is unavailable")
public void pendingEaiUnavailable() {
    throw new io.cucumber.java.PendingException("Pending: requires WireMock for EAI simulation");
}
```

---

## 🔌 連線補齊規範

### Step 結構（標準寫法）

```java
// @When / @Then — 只做三件事：解析參數、呼叫 private method、設定 context
@When("the representative {action} FATCA information for {string} with following fields")
public void fatcaMaintenance(Action action, String name, DataTable dataTable) {
    Map<String, String> data = DataTableHelper.toMap(dataTable);
    data.put("custId", context().get(name).getCustId());
    callFatcaMaintenanceApi(data);
}

private void callFatcaMaintenanceApi(Map<String, String> data) {
    CBKHeader header = CBKHeaderHelper.getDefault(CBKServiceCode.FATCA_MAINTENANCE);
    CBKResponse response = clientHelper.post(
        CBK_CONFIG.getCbkEndpoins().get(LBSystem.CBK), header, data);
    context().setResponse(response);
}
```

### @Pending Skeleton Step 寫法

```java
// TODO: @Pending — 此 Step 需要 [說明缺少什麼]，環境就緒後移除 @Pending 並補充實作
@Given("the EDW has the following VASP broadcast records for customer {string}")
public void pendingEdwHasBroadcastRecords(String custName, DataTable dataTable) {
    throw new io.cucumber.java.PendingException(
        "Pending: requires pre-existing EDW test data for " + custName);
}
```

骨架規則：
- 方法名稱加 `pending` 前綴
- 方法體只有 `throw new PendingException(...)`
- 加上 `// TODO:` 說明缺少什麼

### Header / 信封選擇（依系統協定表）

請求信封**不可一律假設為原生 CBK**。組請求前先查 `.cucb/config.md`「系統協定設定」表，依該 LBSystem 列的 `Header Helper` 與 `Response 類型` 選擇實作類別（範例存放於 `.cucb/protocol-samples/<LBSystem>.md`）。表不存在時視為原生 CBK；表存在但該系統標 `⚠️ 待補` 或框架無對應 Helper 時，走下方「協定不相容時的骨架 Helper」，禁止硬套 CBK 信封。

### ClientProvider 新增 client（相容協定）

當 `dev.conf` 有新 endpoint group 但 `ClientProvider` 無對應 client 時，參考此 pattern 補齊：

```java
// 在 ClientProvider.java 新增（參考 cbkClient 的 pattern）
private static CBKClient eaiClient;

public static synchronized CBKClient getEaiClient() {
    if (eaiClient == null) {
        CBKClientConfig config = CBKClientConfig.builder()
            .connectionTimeout(5 * 1000)
            .retryTimes(3)
            .readTimeout(5 * 1000)
            .build();
        eaiClient = CBKClientImpl.builder().cbkClientConfig(config).build();
    }
    return eaiClient;
}

// 在 ClientHelper.java 新增對應欄位與方法
protected static CBKClient eaiClient = ClientProvider.getEaiClient();

public CBKResponse postToEai(LBSystem system, CBKHeader header, CBKRequestBody body) {
    String endpoint = CBK_CONFIG.getEaiEndpoins().get(system);
    CBKPayload payload = CBKPayload.builder()
        .body(toMap(body)).cbkHeader(header).endpoint(endpoint).build();
    CBKResponse response = eaiClient.post(payload);
    ReportUtil.addRespToReport(response);
    return response;
}
```

### 協定不相容時的骨架 Helper

若新系統協定與 CBKClient 不相容（SOAP / MQ / 私有協定）：

```java
@Slf4j
public class SoapConnectionHelper {
    // TODO: [CONNECTION GAP] SOAP 協定不相容，CBKClient 無法使用
    // 需引入獨立 SOAP client 後補充實作，對應 Scenario 須標 @Pending
    public static Object call(String operation, Object requestBody) {
        throw new UnsupportedOperationException(
            "[CONNECTION GAP] SOAP 協定不相容。需引入獨立 SOAP client 或包裝層後補充實作。"
        );
    }
}
```

### DB 驗證 Step 寫法

對應 `.cucb/db-usage-scenarios.md` 的情境（清單 D），每個 DB 驗證 `Then` 步驟按以下模式實作：

```java
/**
 * DB 驗證步驟：<purpose>
 * 對應 DB 情境 ID：<scenario_id>
 * 查詢檔案：.cucb/db-queries/<query_file>
 */
@Then("<then_step_template>")
public void verifyDatabaseXxx() {
    // 從 context 取得查詢所需參數
    String acctNbr = context().get("senderName", CIFData.class).getMainAcctNbr();
    // 若需要 response 欄位，從 context().getResponse() 取得

    // 呼叫 DB Agent 執行驗證查詢
    Map<String, Object> dbResult = dbQueryHelper.query(
        "<query_file>",                    // .cucb/db-queries/ 下的 SQL 檔名
        Map.of("acctNbr", acctNbr)         // 查詢參數（對應 SQL 中的 {{acctNbr}}）
    );

    // 驗證查詢結果
    assertThat(dbResult).isNotNull();
    assertThat(dbResult.get("ACCT_BAL")).isNotNull();
}
```

**key_params 對應規則**：

| `key_params` 值 | Java 取值方式 |
|----------------|-------------|
| `context.<custName>` | `context().get("<custName>", CIFData.class).getCustId()` |
| `context.acctNbr` | `context().get(name, CIFData.class).getMainAcctNbr()` |
| `response.txSeqNbr` | `context().getResponse().getBody().get("txSeqNbr")` |
| `response.<fieldName>` | `context().getResponse().getBody().get("<fieldName>")` |

> ⚠️ 若 `dbQueryHelper` 尚未在 `CucumberBase` 或 `ClientHelper` 中定義，需先在 `ClientHelper` 新增 `query(String queryFile, Map<String, Object> params)` 方法，呼叫 `core.db-query` Agent 並回傳結果 Map。

### step-business-map.md 格式

完成後回寫至 `step_business_map_path`（New / Modify 項目才寫，Reuse 不寫）：

```markdown
### FatcaCrsStep.java
| Step Method     | Service Code | Request BO | Gherkin Step                        | Feature File      | 狀態      |
|-----------------|--------------|------------|-------------------------------------|-------------------|-----------|
| queryFatcaInfo  | SZCUA01G001  | FatcaQry   | Query FATCA information for {string}| fatca_crs.feature | ⏳ 待驗證 |
```


### step-capabilities.md 區塊格式

New / Modify 的 Step 檔需同步更新 `.cucb/step-capabilities.md`（已有區塊則更新、無則於檔尾新增，並更新 `Last updated`）：

```markdown
## <FileName>.java

| Given / Setup 能力 | 說明 | 支援 txCd |
|--------------------|------|-----------|
| `<@Given pattern>` | <業務語意一句話> | <txCd or 通用> |

**can_setup**：<一句話描述能建立什麼業務前置狀態>
```

> 若該 Step 檔沒有任何 `@Given`（只有 `@When` / `@Then`），仍建立區塊，`can_setup` 標記為「無前置建立能力」。