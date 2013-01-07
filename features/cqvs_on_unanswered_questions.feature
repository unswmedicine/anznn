Feature: In order to see error messages in the right place
  As a Data Provider or Data Provider Supervisor
  I want to specify CQVs stating a particular question must be answered based on other answers

  Background:
    Given I have the usual roles
    And I have hospitals
      | state | name       | abbrev |
      | NSW   | Left Wing  | Left   |
    And I have users
      | email                         | first_name | last_name  | role                     | hospital  |
      | dataprovider@intersect.org.au | Data       | Provider   | Data Provider            | Left Wing |
    # Setup questionnaire with two questions one must be present if other is something
    And I have a survey with name "MySurvey" and questions
      | question | question_type |
      | QChoice   | Choice        |
      | QText     | Text          |
    And question "QChoice" has question options
      | option_value | label     |
      | 1            | trigger   |
      | 0            | notrigger |
    And I have the following cross question validations
      | question  | related | rule             | conditional_operator | conditional_constant | error_message                               |
      | QText     | QChoice | present_if_const | ==                   | 1                    | QText must be present if QChoice is trigger |

  Scenario: Warning shows up on entry screen
    Given I am ready to enter responses as dataprovider@intersect.org.au
    Then I should not see "QText must be present if QChoice is trigger"

    When I store the following answers skipping assertion
      | question | answer  |
      | QChoice  | trigger |
      | QText    |         |
    Then I should see "QText must be present if QChoice is trigger"

    When I store the following answers skipping assertion
      | question | answer    |
      | QChoice  | notrigger |
      | QText    |           |
    Then I should not see "QText must be present if QChoice is trigger"

    When I store the following answers skipping assertion
      | question | answer    |
      | QChoice  | notrigger |
      | QText    | something |
    Then I should not see "QText must be present if QChoice is trigger"

    When I store the following answers skipping assertion
      | question | answer    |
      | QChoice  | trigger   |
      | QText    | something |
    Then I should not see "QText must be present if QChoice is trigger"

  Scenario: Warning shows up on response submission screen
    Given "dataprovider@intersect.org.au" created a response to the "MySurvey" survey with babycode "abc"
    And I am logged in as "dataprovider@intersect.org.au"
    And I am on the edit first response page
    And I store the following answers skipping assertion
      | question | answer  |
      | QChoice  | trigger |
      | QText    |         |

    When I am on the response summary page for abc
    Then show me the page
    And I press "Submit"

  Scenario: Warning shows up on batch submission
