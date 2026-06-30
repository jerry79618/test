package com.jerry;

import org.junit.runner.RunWith;
import io.cucumber.junit.Cucumber;
import io.cucumber.junit.CucumberOptions;

@RunWith(Cucumber.class)
@CucumberOptions(
    features = "src/test/resources/features",
    glue = "com.jerry.stepDefinitions",
    plugin = { "pretty", "json:target/cucumber.json" },
    monochrome = true
)
public class TestRunner {
    // 只需要空的 class 與正確的匯入與註解
}