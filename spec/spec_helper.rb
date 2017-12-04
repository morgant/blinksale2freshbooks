require "bundler/setup"
require "blinksale2freshbooks"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
  
  config.before(:all) do
    Blinksale2FreshBooks.configure do |config|
      config.blinksale_id = ENV['BS2FB_BLINKSALE_ID']
      config.blinksale_username = ENV['BS2FB_BLINKSALE_USER']
      config.blinksale_password = ENV['BS2FB_BLINKSALE_PASS']
    end
  end
end
