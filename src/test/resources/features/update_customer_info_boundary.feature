Feature: Update customer personal information
  As a Retail Banking Product Manager
  I want customers to be able to update their personal information via the APP

  Background: Open Account
    Given A Active TW account person call "Tester" with following fields
      | custNm   | birthDay | gender |
      | Cucumber | 19990101 | 1      |

  # 正向測試
  Scenario: Customer updates home address (valid)
    When The customer "Tester" updates home address with following fields
      | addrHrcyCd | addrId          | zipCd | bsicAddrCont  | dtlAddrCont   | shpgAddrTpCd | ipAddr    |
      | 07         | 000000000000063 | 302   | 新竹縣 竹北市   | 成功路 0 號    | 01           | 10.0.0.1  |
    Then The response message code should be "LBNA000001"
    And the response should be contain following fields
      | messageId  |
      | LBNA000001 |

  Scenario: Customer updates occupation and phone (valid)
    When The customer "Tester" updates occupation and phone with following fields
      | occupation | phone     |
      | 工程師      | 0912345678 |
    Then The response message code should be "LBNA000002"
    And the response should be contain following fields
      | messageId  |
      | LBNA000002 |

  Scenario: Customer updates birthday (valid Gregorian)
    When The customer "Tester" updates birthday with following fields
      | birthDay   |
      | 19900101   |
    Then The response message code should be "LBNA000003"
    And the response should be contain following fields
      | messageId  |
      | LBNA000003 |

  # 邊界測試
  Scenario: Customer updates address with exactly 200 characters
    When The customer "Tester" updates home address with following fields
      | addrHrcyCd | addrId          | zipCd | bsicAddrCont  | dtlAddrCont                                                                                                                                                                                                                                    | shpgAddrTpCd | ipAddr    |
      | 07         | 000000000000063 | 302   | 新竹縣 竹北市   | 這是一個剛好200字的地址............................................................................................................................................................................................... | 01           | 10.0.0.1  |
    Then The response message code should be "LBNA000005"
    And the response should be contain following fields
      | messageId  |
      | LBNA000005 |

  # 反向測試
  Scenario: Customer updates address with over 200 characters
    When The customer "Tester" updates home address with following fields
      | addrHrcyCd | addrId          | zipCd | bsicAddrCont  | dtlAddrCont                                                                                                                                                                                                                                    | shpgAddrTpCd | ipAddr    |
      | 07         | 000000000000063 | 302   | 新竹縣 竹北市   | 這是一個超過200字的地址測試................................................................................................................................................................................................. | 01           | 10.0.0.1  |
    Then The response message code should be "LBNA999001"
    And the response should be contain following fields
      | messageId  |
      | LBNA999001 |

  Scenario: Customer updates birthday with ROC year format
    When The customer "Tester" updates birthday with following fields
      | birthDay   |
      | 850101     |
    Then The response message code should be "LBNA999002"
    And the response should be contain following fields
      | messageId  |
      | LBNA999002 |

  Scenario: Customer updates phone with invalid format
    When The customer "Tester" updates occupation and phone with following fields
      | occupation | phone     |
      | 工程師      | 12345      |
    Then The response message code should be "LBNA999003"
    And the response should be contain following fields
      | messageId  |
      | LBNA999003 |
