require "net/http"
require "json"
require "blinksale2freshbooks/version"
require "blinksale2freshbooks/config"
require "blinksale/blinksale"
require "freshbooks/freshbooks"

module Blinksale2FreshBooks
  class << self
    attr_accessor :blinksale, :freshbooks
  end

  def self.connect
    puts "Connecting to Blinksale..."
    @blinksale = Blinksale.new(@configuration.blinksale_id, @configuration.blinksale_username, @configuration.blinksale_password)
    puts "Connected to Blinksale with #{@configuration.blinksale_username} account"
    
    puts "Connecting to FreshBooks..."
    @freshbooks = FreshBooks.new(@configuration.freshbooks_api_client_id, @configuration.freshbooks_api_secret, @configuration.freshbooks_api_redirect_uri, @configuration.freshbooks_api_auth_code, @configuration.freshbooks_api_token)
    puts "Connected to FreshBooks with #{@freshbooks.identity.first_name} #{@freshbooks.identity.last_name} (#{@freshbooks.identity.email}) account"
  end
  
  def self.all_blinksale_clients
    @blinksale.clients
  end
  
  def self.all_blinksale_invoices
    @blinksale.invoices(status: :all, start: "2006-01-01")  # the Blinksale API was first released in 2006, so presumably that should cover all invoices, but could make it a config option if necessary
  end
  
  def self.migrate(dry_run = true)
    puts "Migrating from #{@blinksale.host}..."
    
    clients = all_blinksale_clients
    puts "#{clients.count} clients..."
    clients.each do |client|
      puts "\t'#{client.name}'..."
      if client.people.length > 0
        client.people.each do |person|
          puts "\t\t'#{person.first_name} #{person.last_name}'..."
        end
      end
    end
    
    invoices = all_blinksale_invoices
    puts "#{invoices.count} invoices..."
    invoices.each do |invoice|
      puts "\t#{invoice.number} (#{invoice.date}; #{invoice.status})..."
    end
    
    
  end
end
