# frozen_string_literal: true

require "polymux"
require "webmock/rspec"
require "timecop"

# Configure WebMock to allow no external connections during tests
WebMock.disable_net_connect!(allow_localhost: true)

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Clean up WebMock stubs after each test
  config.after(:each) do
    WebMock.reset!
  end

  # Reset Timecop after each test
  config.after(:each) do
    Timecop.return
  end

  # Configure test environment variables
  config.before(:each) do |example|
    # Set default test API key unless the test is specifically testing config
    unless example.metadata[:skip_config_setup]
      ENV["POLYMUX_API_KEY"] = "test_api_key_12345"
      ENV["POLYMUX_BASE_URL"] = "https://api.polygon.io"
    end
  end

  config.after(:each) do |example|
    # Clean up environment variables after each test
    unless example.metadata[:skip_config_setup]
      ENV.delete("POLYMUX_API_KEY")
      ENV.delete("POLYMUX_BASE_URL")
    end
  end
end

# Helper method to load JSON fixtures
def load_fixture(filename)
  File.read(File.join(__dir__, "fixtures", "#{filename}.json"))
end

# Helper method to parse JSON fixtures
def json_fixture(filename)
  JSON.parse(load_fixture(filename))
end
