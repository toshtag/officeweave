ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require_relative "test_helpers/session_test_helper"
require_relative "test_helpers/isolated_organization_test_helper"
require_relative "test_helpers/boot_process_test_helper"
require_relative "test_helpers/capability_registry_test_helper"
require_relative "test_helpers/query_count_test_helper"
require_relative "test_helpers/passwordless_provider_test_helper"
require_relative "test_helpers/keyboard_navigation_test_helper"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end
