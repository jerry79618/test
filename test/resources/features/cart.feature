# language: zh
Feature: 購物車管理

Background:
  Given 使用者已登入且在商品頁面

Scenario Outline: 新增單一商品到購物車
  When 使用者將 "<商品名稱>" 加入購物車
  Then 購物車應包含 "<商品名稱>" 並且數量為 1

  Examples
    | 商品名稱   |
    | 藍牙滑鼠   |
    | 無印筆記本 |

Scenario Outline: 更新購物車內商品數量
  Given 購物車內已存在 "<商品名稱>"，數量為 <原數量>
  When 使用者將 "<商品名稱>" 的數量更新為 <更新後數量>
  Then 購物車應顯示 "<商品名稱>" 的數量為 <更新後數量>

  Examples:
    | 商品名稱   | 原數量 | 更新後數量 |
    | 藍牙滑鼠   | 1      | 3          |
    | 無印筆記本 | 5      | 2          |

Scenario: 從購物車移除商品
  Given 購物車內已存在 "藍牙滑鼠"，數量為 1
  When 使用者從購物車移除 "藍牙滑鼠"
  Then 購物車不應包含 "藍牙滑鼠"
