# Communication Guidelines (溝通規範)
- **Response Language**: 所有的對話回應、程式碼解釋、步驟說明，**必須**使用 **繁體中文 (Traditional Chinese)**。
- **Code Comments**: 程式碼內的註解 (Comments) 若涉及複雜邏輯，請使用 **繁體中文**。
- **Code Content**: 變數名稱、類別名稱、Gherkin 關鍵字仍維持 **英文**。

# Project Overview
本專案為 Java Spring Boot 應用，專注於自動化測試（Cucumber），使用 Maven 管理。
核心測試架構位於 `src/test/java`，包含 Step Definitions, Request/Response Objects, Utilities 與 Configuration。

# Code Style
- **Java Style**: 遵循 Google Java Style。
- **Indentation**: 4 個空白。
- **Lombok**: 廣泛使用 `@Data`, `@Builder`, `@Getter`, `@Setter`, `@Slf4j`。
- **Assertions**: 使用 `org.junit.Assert`。

# Naming Conventions
- **Class**: PascalCase (e.g., `CustomerStep`, `TransferFundsRequest`).
- **Method/Variable**: camelCase (e.g., `doNIDOCR`, `cifData`).
- **Constant**: UPPER_SNAKE_CASE (e.g., `CBK_CONFIG`).
- **Test Files**: 結尾需為 `*Step.java` 或 `*Test.java`。

# Project Structure & Key Classes
Copilot 應優先參考以下結構與類別：

```text
src/test/java/com/yhao/
├── step/                  # Step Definitions (繼承 CucumberBase)
│   └── CucumberBase.java  # 所有 Step 的父類別，提供 context(), clientHelper 等核心方法
├── requestBO/             # Request Body Objects (Lombok Builder)
├── responseBO/            # Response Body Objects
├── alias/                 # Enums (CBKServiceCode, ReviewCode, etc.)
├── client/                # API Client 封裝 (ClientHelper)
├── service/               # 業務邏輯 Helper (TwAccountHelper, DbHelper, DataTableHelper)
├── util/                  # 工具類 (DateUtil, JsonUtil)
├── CIFData.java           # 核心資料物件，用於在 Step 間傳遞客戶資訊
├── Context.java           # 測試 Context，用於儲存 CIFData 與 Response
└── CBKConfig.java         # 專案設定檔
```

# Core Development Guidelines (重要)

## 1. Step Definition 撰寫規範
- **繼承**: 所有 Step Class 必須繼承 `CucumberBase`。
- **Context 使用**: 使用 `context()` 存取 `Context.CONTEXT`。
  - 取得客戶資料: `CIFData cifData = context().get(name);`
  - 儲存 Response: `context().setResponse(cbkResponse);`
- **API 呼叫**: 使用 `clientHelper` (來自 `CucumberBase`) 發送請求。
  - 範例: `clientHelper.post(endpoint, header, body);`
- **資料處理**: 使用 `DataTableHelper.replaceParameter(dataTable, context())` 處理 Cucumber DataTable。

## 2. Request Body 建構模式
- **Helper Pattern**: 複雜的 Request Body 建構邏輯應抽取至 `service` package 下的 Helper 類別 (如 `TwAccountHelper`)。
- **Builder**: 使用 Lombok `@Builder` 建構物件。
- **範例**:
  ```java
  // 在 Step 中
  TwNidOcr body = TwAccountHelper.getNidOcrBody(cifData);
  ```

## 3. 客戶資料管理 (CIFData)
- `CIFData` 是測試流程中的核心物件，用於儲存客戶的 PII、帳號、狀態等。
- 在 Step 中若需修改客戶屬性，應更新 `CIFData` 物件，以便後續 Step 使用。
- 使用 `combineToCifData(name, map)` (來自 `CucumberBase`) 將 DataTable 資料合併入 `CIFData`。

## 4. Enum 使用
- 服務代碼: `com.yhao.alias.CBKServiceCode`
- 系統代碼: `com.yhao.alias.LBSystem` (e.g., `LBSystem.MBK`)
- 審核代碼: `com.yhao.alias.ReviewCode`

## 5. 資料庫驗證
- 使用 `DbHelper` 進行資料庫查詢與驗證。
- 範例: `new DbHelper(DatasourceUtil.getCbkConn()).query(sql, params);`

## 6. Response Validation (驗證模式)
- **優先重用**: 優先使用 `CustomerStep` 中已定義的通用驗證 Step，避免重複撰寫。
  - 驗證訊息代碼: `Then The response message code should be "{string}"`
  - 驗證欄位內容: `And the response should be contain following fields`
- 只有在需要特殊邏輯驗證時，才撰寫新的 `@Then` Step。

# Cucumber Coding Style & Feature Format
- **Feature Files**: `src/test/resources/features/*.feature`。
- **Step Definitions**: `src/test/java/com/yhao/step/*Step.java`。
- **Language Rules (語言規則)**:
  - **Gherkin Keywords**: 必須使用 **英文** (e.g., `Feature`, `Background`, `Scenario`, `Given`, `When`, `Then`, `And`, `But`)。**禁止**使用中文關鍵字 (如 `功能`, `場景`)。
  - **Step Description**: 必須使用 **英文** 描述業務行為 (PM voice)。
  - **Data**: DataTable 內的測試資料 (如姓名、地址) 可以使用 **繁體中文**。
- **Parameter Types**: 善用 `ParameterType` (如 `Approver`, `ReviewCode`) 簡化 Gherkin。

## 🤖 Auto-Generation Triggers (自動生成觸發規則)
當使用者提供以下結構的輸入時，請**自動**執行對應任務，無需額外指令：

**Trigger 1: Create New Feature File**
- **Keyword**: `**Create New Feature File**`
- **Action**: 產生全新的 `.feature` 檔案，包含 Background 與 Scenario。

**Trigger 2: Modify Existing Feature File**
- **Keyword**: `**Modify Existing Feature File**`
- **Action**: 讀取既有 Feature 檔案，保留原有 Scenario，僅**新增**或**修改**指定的 Scenario。

**Trigger 3: New Feature Implementation**
- **Keyword**: `**New Feature Implementation**`
- **Action**: 依照順序實作：
  1. Add Enum (`CBKServiceCode`).
  2. Create RequestBO (Lombok).
  3. Create **NEW Helper Class** (Static Factory Method).
  4. Create Step Definition (Extend `CucumberBase`).

**Trigger 4: Modify Existing Implementation**
- **Keyword**: `**Modify Existing Implementation**`
- **Action**: 更新既有 Java 類別 (RequestBO/Helper/Step)，確保不破壞現有測試 (Backward Compatibility)。

**Trigger 5: Correction Needed**
- **Keyword**: `🛑 **Correction Needed**`
- **Action**: 強制重構程式碼以符合 `CucumberBase` 與 `Helper Pattern` 規範。

## ⭐ Standard Feature File Example (黃金範本)
Copilot 產生 Feature 檔案時，**必須嚴格遵守**以下格式與結構：

```gherkin
Feature: Modify shipping address for card reissue
  As a Retail Banking Product Manager
  I want customers to be able to update their card shipping address when requesting a card reissue

  # Background 必須包含建立 Active TW account 的步驟
  Background: Open Account
    Given A Active TW account person call "Tester" with following fields
      | custNm   | birthDay | gender |
      | Cucumber | 19990101 | 1      |

  # Scenario 必須包含清楚的 When (API 呼叫) 與 Then (結果驗證)
  Scenario: Customer requests card replacement and updates shipping address
    When The customer "Tester" requests card replacement and provides new shipping address with following fields
      | addrHrcyCd | addrId          | zipCd | bsicAddrCont  | dtlAddrCont   | shpgAddrTpCd | ipAddr    |
      | 07         | 000000000000063 | 302   | 新竹縣 竹北市   | 成功路 0 號    | 01           | 10.0.0.1  |
    Then The response message code should be "LBNA000001"
    And the response should be contain following fields
      | messageId  |
      | LBNA000001 |
```

# Java Implementation Examples

## Step Definition Example
```java
@Slf4j
public class IdentityStep extends CucumberBase {

    @When("The people {string} do the NID OCR with following field")
    public void doNidOcr(String name, DataTable dataTable) {
        // 1. 準備資料
        combineToCifData(name, dataTable.asMaps().get(0));
        CIFData cifData = context().get(name);

        // 2. 建構 Request Body (使用 Helper)
        TwNidOcr body = TwAccountHelper.getNidOcrBody(cifData);

        // 3. 準備 Header
        CBKHeader header = CBKHeaderHelper.getDefault(CBKServiceCode.TW_ACCOUNT_OPEN_NID_OCR);

        // 4. 發送請求
        CBKResponse response = clientHelper.post(
            CBK_CONFIG.getCbkEndpoints().get(LBSystem.MBK), 
            header, 
            body
        );

        // 5. 儲存結果
        context().setResponse(response);
    }
}
```

## RequestBO Example
```java
@Builder
@Getter
@Setter
public class TwNidOcr extends CBKRequestBody {
    private String natlId;
    private String custNm;
    private EncPinCd encPinCd; // 巢狀物件
}
```
# Data Specifications & Testing Standards (資料與測試規範)
- **Date Format (日期格式)**:
  - 所有日期欄位**必須**使用 `yyyymmdd` 格式 (String type)。
  - ❌ Invalid: `2023-12-31`, `2023/12/31`, `Dec 31 2023`
  - ✅ Valid: `20231231`
- **Date Boundary Testing (日期邊界測試)**:
  - 凡涉及日期運算或檢核的 Feature，**必須**包含邊界值 Scenario。
  - **Mandatory Cases**:
    1. **Year End/Start**: 驗證跨年邏輯 (e.g., `20231231` to `20240101`)。
    2. **Month End/Start**: 驗證跨月邏輯。
    3. **Leap Year**: 若涉及二月，需驗證閏年 (e.g., `20240229`)。
    
# Do's
- 優先使用 `CucumberBase` 提供的 protected 方法 (e.g., `doNIDOCR`, `doReview`) 如果邏輯已存在。
- 使用 `ReportUtil.addText()` 記錄關鍵測試資訊。
- 使用 `JsonUtil` 處理 JSON 轉換。

# Don'ts
- 不要直接在 Step 中 `new` HttpClient，請使用 `clientHelper`。
- 不要硬編碼環境設定，請使用 `CBK_CONFIG`。

# Build / Test / Lint commands
- Build (compile + package): mvn clean package
- Run all tests: mvn test
- Run a single test class: mvn -Dtest=ClassName test
  - Example (run TestRunner): mvn -Dtest=TestRunner test
- Run a single test method: mvn -Dtest=ClassName#methodName test
- Run TestRunner with Cucumber tags: mvn -Dtest=TestRunner test -Dcucumber.filter.tags="@smoke"
- Run a specific scenario by name: mvn -Dtest=TestRunner test -Dcucumber.options="--name \"Exact Scenario Name\""
- Lint: 本專案未配置自動化 linter。建議使用 IDE 的 Checkstyle / SpotBugs 或在 CI 中新增相關插件。

# High-level architecture (摘要)
- Maven Java 專案，主體為 Cucumber BDD 測試套件。
- 測試資源：src/test/resources/features/*.feature
- 測試程式碼：src/test/java/com/yhao/**
  - Step Definitions (通常位於 step/ 下)，皆繼承 CucumberBase，透過 context() 共享 CIFData 與回應。
  - Request/Response BO 放在 requestBO/ / responseBO/，使用 Lombok (@Builder) 建構。
  - client/ 包含 clientHelper，負責所有 HTTP 呼叫。
  - service/ 放 Helper 類別（如 TwAccountHelper、DbHelper、DataTableHelper）以封裝建構 Request 與 DB 驗證邏輯。
  - util/ 放 JsonUtil、DateUtil 等工具。
- Test runner: surefire 配置只包含 **/TestRunner.java，故 TestRunner 為執行入口（請確保存在一個 TestRunner 類）。

# Key repository conventions (重點慣例)
- Step 類別必須繼承 CucumberBase 並使用 context() 取得/儲存 CIFData 與回應。
- 複雜 Request 建構應放在 service helper；Step 只負責呼叫 helper 與 clientHelper。
- RequestBO 使用 Lombok @Builder；所有日期欄位皆為 "yyyymmdd" 字串。
- Test class 命名需以 *Step.java 或 *Test.java 結尾；Cucumber feature 與 Gherkin 關鍵字必須為英文。
- 使用 DataTableHelper.replaceParameter 處理 DataTable 參數化。
- 使用 DbHelper + DatasourceUtil.getCbkConn() 進行資料庫驗證。

# Notes about existing AI-agent configs
- 本專案包含 .github/agents/*.agent.md 與 prompt.md，已定義 tester/reviewer 行為與回應語言（繁體中文）。Copilot 應遵循這些規範。

---

若要我直接將上述變更寫入檔案（已完成）或進一步把執行範例補入 CI workflow，請告知是否要新增 MCP server（例如為 Playwright/瀏覽器測試設定）。

# Suggested improvements applied
- 明確列出 Maven 與 Java 版本：Java 11 (maven.compiler.source/target), cucumber 7.14.0, junit 4.13.2（見 pom.xml）。
- 提醒 surefire 目前只包含 **/TestRunner.java**（若要執行其他測試，請用 -Dtest 或調整 surefire includes）。
- 加入常用命令範例：
  - Build: mvn clean package
  - Run all tests: mvn test
  - Run TestRunner: mvn -Dtest=TestRunner test
  - Run single test method: mvn -Dtest=TestRunner#methodName test
  - Run scenario by name: mvn -Dtest=TestRunner test -Dcucumber.options="--name \"Exact Scenario Name\""
- 明確指出 feature 檔位置：src/test/resources/features/
- 保留並遵循 .github/agents/*.agent.md 與 prompt.md 中的規範（回應使用繁體中文）。

若需把這些建議再調整進更詳細的段落或加入 CI 範例，請告知要怎麼調整。