Feature: Modify shipping address for card reissue
  As a Retail Banking Product Manager
  I want customers to be able to update their card shipping address when requesting a card reissue

  # Background 必須包含建立 Active TW account 的步驟
  Background: Open Account
    Given A Active TW account person call "Tester" with following fields
      | custNm   | birthDay | gender |
      | Cucumber | 19990101 | 1      |

  # Scenario: 成功補發卡片並修改寄送地址
  Scenario: Customer requests card replacement and updates shipping address
    When The customer "Tester" requests card replacement and provides new shipping address with following fields
      | addrHrcyCd | addrId          | zipCd | bsicAddrCont  | dtlAddrCont   | shpgAddrTpCd | ipAddr    |
      | 07         | 000000000000063 | 302   | 新竹縣 竹北市   | 成功路 0 號    | 01           | 10.0.0.1  |
    Then The response message code should be "LBNA000001"
    And the response should be contain following fields
      | messageId  |
      | LBNA000001 |

  # Scenario: 地址格式驗證失敗
  Scenario: Customer provides invalid address format for card reissue
    When The customer "Tester" requests card replacement and provides new shipping address with following fields
      | addrHrcyCd | addrId          | zipCd | bsicAddrCont | dtlAddrCont | shpgAddrTpCd | ipAddr    |
      | 07         | 000000000000063 | 302   | 123          | 456         | 01           | 10.0.0.1  |
    Then The response message code should be "LBNA000002"
    And the response should be contain following fields
      | messageId  |
      | LBNA000002 |

  # Scenario: 地址含特殊字元驗證失敗
  Scenario: Customer provides address with special characters for card reissue
    When The customer "Tester" requests card replacement and provides new shipping address with following fields
      | addrHrcyCd | addrId          | zipCd | bsicAddrCont  | dtlAddrCont   | shpgAddrTpCd | ipAddr    |
      | 07         | 000000000000063 | 302   | 新竹@竹北市     | 成功#路 0 號    | 01           | 10.0.0.1  |
    Then The response message code should be "LBNA000003"
    And the response should be contain following fields
      | messageId  |
      | LBNA000003 |
