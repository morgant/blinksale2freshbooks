module Blinksale2FreshBooks

  class Configuration
    attr_accessor :blinksale_id, :blinksale_username, :blinksale_password

    def initialize
      @blinksale_id = nil
      @blinksale_username = nil
      @blinksale_password = nil
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