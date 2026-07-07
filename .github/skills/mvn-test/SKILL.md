---
name: mvn-test
description: >
  Executes Maven tests (mvn test) for a specific tag and environment profile and returns the result.
  Use this skill when you need to run Cucumber tests or verify feature implementations.
allowed-tools: shell
---

# Maven Test Runner Skill

This skill provides a standardized workflow for executing Maven tests. It handles `JAVA_HOME` and Maven path configuration automatically.

## How It Works

When triggered, the skill executes the predefined workflow.

The expected input format is: `<Tag> <EnvProfile>` (separated by a space).
Example: `FATCA_CRS dev`

The process handles:
1.  **Environment Setup**: Automatically detects and sets `JAVA_HOME` and the Maven path if they are not already available in the current terminal session.
2.  **Execution**: Runs `mvn test "-Dcucumber.filter.tags=@<Tag>" -P <EnvProfile>` directly from the project root.

This removes the need for the external `run-mvn-test.ps1` script, keeping the logic centralized in this skill.

## After Execution

The agent should interpret the results by:

1. Checking the exit code: `0` means all tests passed, non-`0` means there are failures.
2. Reading the test report generated at: `target/cucumberReportJsonFiles/cucumber-report.json`.
3. If the JSON report is not found, falling back to reading `target/surefire-reports/*.txt`.
4. Extracting and summarizing from the report:
   - The number of passed / failed / skipped Scenarios.
   - For any failed Scenarios, the specific scenario `name` and the `error_message`.
