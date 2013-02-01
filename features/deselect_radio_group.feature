Feature: Deselect radio option
  In order to deselect radio option
  As a system owner
  I want to allow radio groups options to be cleared

  Background:
    Given I have the usual roles
    And I have a user "data.provider@intersect.org.au" with role "Data Provider"
    And I have a survey with name "MySurvey" and questions
      | question  | question_type |
      | Choice Q1 | Choice        |
    And question "Choice Q1" has question options
      | option_value | label | hint_text    | option_order |
      | 99           | Dunno |              | 2            |
      | 0            | Yes   | this is true | 0            |
      | 1            | No    | not true     | 1            |

  @javascript
  Scenario: Deselect radio option for new form
    And I am ready to enter responses as data.provider@intersect.org.au
    When I answer as follows
      | question  | answer |
      | Choice Q1 | Dunno  |
    And I deselect "Choice Q1"
    And press "Save page"
    Then I should see choice "Choice Q1" with no options

  @javascript
  Scenario: Deselect radio option for saved form
    And I am ready to enter responses as data.provider@intersect.org.au
    When I answer as follows
      | question  | answer |
      | Choice Q1 | Dunno  |
    And press "Save page"
    Then I should see choice "Choice Q1" with "(99) Dunno"
    And I deselect "Choice Q1"
    And press "Save page"
    Then I should see choice "Choice Q1" with no options
