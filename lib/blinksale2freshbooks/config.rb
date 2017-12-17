module Blinksale2FreshBooks

  class Configuration
    attr_accessor :blinksale_id, :blinksale_username, :blinksale_password, :freshbooks_api_client_id, :freshbooks_api_secret, :freshbooks_api_redirect_uri, :freshbooks_api_auth_code

    def initialize
      @blinksale_id = nil
      @blinksale_username = nil
      @blinksale_password = nil
      @freshbooks_api_client_id = nil
      @freshbooks_api_secret = nil
      @freshbooks_api_redirect_uri = nil
      @freshbooks_api_auth_code = nil
    end
  end
  
  class << self
    attr_accessor :configuration
  end

  def self.configuration
    @configuration ||= Configuration.new
  end

  def self.reset
    @configuration = Configuration.new
  end

  def self.configure
    yield(configuration)
  end

end