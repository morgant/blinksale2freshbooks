require "blinksale2freshbooks/version"
require "blinksale2freshbooks/config"
require "blinksale/blinksale"

module Blinksale2FreshBooks
  attr_accessor :blinksale, :freshbooks

  def self.connect
    puts "Connecting to Blinksale..."
    @blinksale = Blinksale.new(@configuration.blinksale_id, @configuration.blinksale_username, @configuration.blinksale_password)
    
    puts "Clients: #{@blinksale.clients.count}"
    puts "Invoices: #{@blinksale.invoices.count}"
  end
end
