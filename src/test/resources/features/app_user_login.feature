Feature: APP user login
  As an APP Product Manager
  I want users to be able to login to the APP
  So that legitimate users can access their accounts and malicious or invalid attempts are rejected

  Background: Registered user setup
    Given A registered APP user "Tester" with following fields
      | username | password     |
      | Tester   | correctPwd7  |

  # Business rules:
  # - Rule 1: password must be longer than 6 characters
  # - Rule 2: lock account after 3 consecutive failed attempts

  Scenario: Successful login when password length is greater than 6
    When The user "Tester" attempts to login with following credentials
      | username | password     |
      | Tester   | correctPwd7  |
    Then The response message code should be "AUTH0000"
    And the response should be contain following fields
      | messageId  |
      | AUTH0000   |

  Scenario: Failed login when password length is less than or equal to 6
    When The user "Tester" attempts to login with following credentials
      | username | password |
      | Tester   | abc12    |
    Then The response message code should be "AUTH1001"
    And the response should be contain following fields
      | messageId  |
      | AUTH1001   |

  # Suggested Edge Case 1: Boundary condition where password length equals 6 (should be rejected because rule requires > 6)
  Scenario: Boundary - password length equals 6
    When The user "Tester" attempts to login with following credentials
      | username | password |
      | Tester   | abcdef   |
    Then The response message code should be "AUTH1001"
    And the response should be contain following fields
      | messageId  |
      | AUTH1001   |

  # Suggested Edge Case 2: Account locks after exactly 3 consecutive failed attempts
  Scenario: Account locked after 3 consecutive failed attempts
    Given A registered APP user "LockUser" with following fields
      | username | password   |
      | LockUser | SecretPwd8 |
    When The user "LockUser" attempts to login with following wrong passwords
      | attemptNo | username | password |
      | 1         | LockUser | wrong1   |
      | 2         | LockUser | wrong2   |
      | 3         | LockUser | wrong3   |
    Then The response message code should be "AUTH2001"
    And the response should be contain following fields
      | messageId  |
      | AUTH2001   |

