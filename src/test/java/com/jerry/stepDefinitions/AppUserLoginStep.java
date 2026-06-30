package com.jerry.stepDefinitions;

import com.jerry.helper.AppUserLoginHelper;
import com.jerry.requestBO.SzcuLoginRequest;
import com.jerry.support.CBKHeader;
import com.jerry.support.CBKServiceCode;
import com.jerry.support.CBKResponse;
import com.jerry.support.CIFData;
import com.jerry.util.DataTableHelper;

import io.cucumber.datatable.DataTable;
import io.cucumber.java.en.Given;
import io.cucumber.java.en.When;
import io.cucumber.java.en.Then;

import java.util.List;
import java.util.Map;

public class AppUserLoginStep extends CucumberBase {

    @Given("A registered APP user {string} with following fields")
    public void registeredUser(String name, DataTable dataTable) {
        List<Map<String, String>> rows = DataTableHelper.replaceParameter(dataTable, context());
        if (!rows.isEmpty()) {
            combineToCifData(name, rows.get(0));
        }
    }

    @When("The user {string} attempts to login with following credentials")
    public void userAttemptsLogin(String name, DataTable dataTable) {
        List<Map<String, String>> rows = DataTableHelper.replaceParameter(dataTable, context());
        if (rows.isEmpty()) {
            throw new RuntimeException("No credentials provided");
        }
        Map<String, String> creds = rows.get(0);

        CIFData cif = context().get(name);
        if (cif == null) {
            combineToCifData(name, creds);
            cif = context().get(name);
        } else {
            if (creds.containsKey("username")) {
                cif.setUserName(creds.get("username"));
            }
            if (creds.containsKey("password")) {
                cif.setPasswords(creds.get("password"));
            }
        }

        SzcuLoginRequest body = AppUserLoginHelper.buildLoginRequest(cif);
        CBKHeader header = CBKHeader.defaultHeader(CBKServiceCode.SZCUA01L001);
        CBKResponse response = clientHelper.post("/szc/login", header, body);
        context().setResponse(response);
    }

    @Then("The response message code should be {string}")
    public void responseMessageCodeShouldBe(String code) {
        CBKResponse resp = context().getResponse();
        org.junit.Assert.assertNotNull(resp);
        org.junit.Assert.assertEquals(code, resp.getMessageId());
    }
}
