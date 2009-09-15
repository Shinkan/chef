@provider @git @deploy

Feature: Deploy
  In order to repeatably and reliably deploy web apps from a source repository from the comfort of chef
  As an OpsDev
  I want to have automated deployments

  Scenario: Deploy an app for the first time
    Given a validated node
	And it includes the recipe 'deploy'
	And I have a clone of typo in the data/tmp dir
    When I run the chef-client
    Then the run should exit '0'
	And a file named 'deploy/shared' should exist
	And a file named 'deploy/shared/cached-copy/.git' should exist
	And a file named 'deploy/current/app' should exist
	And a file named 'deploy/current/config/database.yml' should exist
	And a file named 'deploy/current/db/production.sqlite3' should exist
	And a file named 'deploy/current/tmp/restart.txt' should exist
  
  Scenario: Deploy an app again
    Given a validated node
	And it includes the recipe 'deploy'
	And I have a clone of typo in the data/tmp dir
    When I run the chef-client
	And I run the chef-client again
	And there should be 'two' releases
  
  Scenario: Rollback an app
    Given a validated node
	And it includes the recipe 'deploy::rollback'
    When I run the chef-client
    Then there should be 'one' release
  
  
