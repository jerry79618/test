package stepDefinitions;

import io.cucumber.java.en.Given;
import io.cucumber.java.en.When;
import io.cucumber.java.en.Then;

public class Steps {

    @Given("a precondition")
    public void a_precondition() {
        System.out.println("Given step executed");
    }

    @When("an action occurs")
    public void an_action_occurs() {
        System.out.println("When step executed");
    }

    @Then("outcome is observed")
    public void outcome_is_observed() {
        System.out.println("Then step executed");
    }
}

