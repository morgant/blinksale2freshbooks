require "net/http"
require "blinksale2freshbooks/version"
require "blinksale2freshbooks/config"
require "blinksale2freshbooks/person_migration"
require "blinksale2freshbooks/invoice_migration"
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
      migrate_blinksale_invoice(invoice, dry_run)
    end
  end

  private

  def self.migrate_blinksale_client(client, dry_run = true)
    raise ArgumentError if client.nil?
    puts "\t#{client.name}..."
    if client.people.length > 0
      puts "\t\tPeople:"
      client.people.each do |person|
        migration = Blinksale2FreshBooks::PersonMigration.new(@blinksale, @freshbooks, person)
        puts "\t\t#{migration.name}..."
        if !migration.needs_creation?
          puts "\t\t\tAlready exists."
          if !migration.needs_update?
            puts "\t\t\tMatches."
          else
            puts "\t\t\tDiffers. Updating..."
            migration.update
            migration.save unless dry_run
          end
        else
          puts "\t\t\tCreating #{dry_run ? "(not really)" : ""}..."
          migration.create
          migration.save unless dry_run
        end
      end
    end
  end

  def self.migrate_blinksale_invoice(invoice, dry_run = true)
    raise ArgumentError if invoice.nil?
    migration = Blinksale2FreshBooks::InvoiceMigration.new(@blinksale, @freshbooks, invoice)
    puts "\t#{migration.invoice_number}..."
    if !migration.needs_creation?
      puts "\t\tAlready exists."
      if !migration.needs_update?
        puts "\t\tMatches."
      else
        puts "\t\tDiffers. Updating..."
        migration.update
        unless dry_run
          migration.save
        end
      end
    else
      puts "\t\tCreating #{dry_run ? "(not really)" : ""}..."
      migration.create
      unless dry_run
        migration.save
      end
    end
  end

end
