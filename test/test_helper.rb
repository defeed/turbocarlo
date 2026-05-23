ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Load the same domain records as db/seeds.rb (idempotent). Used by
    # DB-backed tests instead of fixtures.
    def seed_decision_lab!
      Rails.application.load_seed
      Scenario.find_by!(slug: "invest-vs-savings")
    end
  end
end
