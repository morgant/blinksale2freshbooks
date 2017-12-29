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
    raise ArgumentError if @freshbooks.using_business.nil?
    
    puts "Migrating from Blinksale (#{@blinksale.host}) to FreshBooks (#{@freshbooks.using_business['name']})..."
    
    clients = all_blinksale_clients
    puts "#{clients.count} clients..."
    clients.each do |client|
      migrate_blinksale_client(client, dry_run)
    end
    
    invoices = all_blinksale_invoices
    puts "#{invoices.count} invoices..."
    invoices.each do |invoice|
      puts "\t#{invoice.number} (#{invoice.date}; #{invoice.status})..."
    end
  end
  
  private
  
  def self.migrate_blinksale_client(client, dry_run = true)
    raise ArgumentError if client.nil?
    
    puts "\t#{client.name}..."
    if client.people.length > 0
      puts "\t\tPeople:"
      client.people.each do |person|
        puts "\t\t#{person.first_name} #{person.last_name}..."
        fb_clients = @freshbooks.clients(email: person.email)
        if !fb_clients.nil? && fb_clients.length > 0
          puts "\t\t\tAlready exists."
        else
          puts "\t\t\tCreating #{dry_run ? "(not really)" : ""}..."
          new_client = @freshbooks.clients.new({
            client: {
              # equivalent to BlinkSale "person" data:
              fname: person.first_name,
              lname: person.last_name,
              email: person.email,
              bus_phone: person.phone_office,  # note: may need to better handle whether to use person.phone_office or client.phone
              mob_phone: person.phone_mobile,
              # equivalent to BlinkSale "client" data:
              organization: client.name,
              p_street: client.address1,
              p_street2: client.address2,
              p_city: client.city,
              p_province: client.state,
              p_code: client.zip,
              p_country: client.country,
              fax: client.fax
            }
          }.to_json)
          unless dry_run || new_client.nil?
            new_client.save
          end
        end
      end
    end
  end
end
