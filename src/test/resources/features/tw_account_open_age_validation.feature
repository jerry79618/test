Feature: TW account opening age validation
  As a Retail Banking Product Manager
  I want to ensure only customers aged 18 to 65 can open a TWD account, and invalid birth date formats are rejected

  Background: Open Account
    Given A Active TW account person call "Tester" with following fields
      | custNm   | birthDay | gender |
      | Cucumber | 19990101 | 1      |

  # 年齡小於18歲
  Scenario: Customer under 18 attempts to open account
    When The customer "Tester" opens a TW account with following fields
      | birthDt   |
      | 20100101  |
    Then The response message code should be "LEBA00009"
    And the response should be contain following fields
      | messageId  |
      | LEBA00009  |

  # 年齡大於65歲
  Scenario: Customer over 65 attempts to open account
    When The customer "Tester" opens a TW account with following fields
      | birthDt   |
      | 19400101  |
    Then The response message code should be "LEBA00008"
    And the response should be contain following fields
      | messageId  |
      | LEBA00008  |

  # 日期格式錯誤
  Scenario: Customer provides invalid birth date format
    When The customer "Tester" opens a TW account with following fields
      | birthDt   |
      | 1999-01-01|
    Then The response message code should be "LEBA00007"
    And the response should be contain following fields
      | messageId  |
      | LEBA00007  |
