Feature: 購物車系統
  目標: 測試購物車的新增與數量限制

  Background: Open Account
    Given A Active TW account person call "Tester" with following fields
      | custNm   | birthDay | gender |
      | Cucumber | 19990101 | 1      |

  # 規則說明（來源）
  # - 規則 1: 可加入購物車
  # - 規則 2: 購物車一項物品最多 2 筆
  # 注意: 使用者原始指示提到「超過三筆加入購物車失敗」，以下已做合理假設，見檔案底部說明。

  Scenario: 正向 - 可以成功加入購物車
    When The customer "Tester" adds product "SKU123" with quantity 1 to the shopping cart
    Then The response message code should be "CART000001"
    And the response should be contain following fields
      | messageId  |
      | CART000001 |

  Scenario: 負向 - 嘗試加入第三筆相同商品時失敗
    Given The customer "Tester" already has product "SKU123" with quantity 2 in the shopping cart
    When The customer "Tester" adds product "SKU123" with quantity 1 to the shopping cart
    Then The response message code should be "CART000002"
    And the response should be contain following fields
      | error               |
      | exceed_max_quantity |

  # 自動補充的邊界測試（Edge Cases）
  Scenario: Edge - 邊界成功：剛好加入第二筆（最大允許）
    When The customer "Tester" adds product "SKU_EDGE" with quantity 2 to the shopping cart
    Then The response message code should be "CART000001"
    And the response should be contain following fields
      | messageId  |
      | CART000001 |

  Scenario: Edge - 多種商品，各別達到最大量仍成功
    When The customer "Tester" adds the following items to the shopping cart
      | sku       | quantity |
      | SKU_A     | 2        |
      | SKU_B     | 2        |
    Then The response message code should be "CART000001"
    And the response should be contain following fields
      | messageId  |
      | CART000001 |

  # Assumptions / 說明（中文）:
  # - 根據專案給定的業務規則：每項物品最多 2 筆 (規則 2)。
  # - 使用者在要求中寫到「超過三筆加入購物車失敗」，此處我做如下合理化處理：
  #   將負向場景實作為「嘗試在已存在 2 筆的情況下，再加入 1 筆（即第三筆）應失敗」，
  #   因為這能同時覆蓋使用者想測試的「超出允許數量」的意圖，且與規則 2（每項最多 2 筆）一致。
  # - 若使用者原意為「整體購物車內商品筆數超過 3 筆即失敗」，請回覆指示，我將更新 feature 與 Scenario。

