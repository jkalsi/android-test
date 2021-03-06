Feature: Definitions!
  As a reader, when there is a word I am unfamiliar with I would like to find its meaning

  Background:
    Given the My Library screen is displayed
    When I open the first book on the My Library page
    And I set the book slider position to 50
    And turn 2 pages forward

  @sanity-all
  Scenario: I want to know the definition of a word so I look smart!
    Given I invoke the definition functionality on the reader
    Then I should be shown a definition
    And It should be included in the full definition page