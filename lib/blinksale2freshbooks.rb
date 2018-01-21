require "net/http"
require "json"
require "active_support/core_ext/object/blank"
require "blinksale2freshbooks/version"
require "blinksale2freshbooks/config"
require "blinksale2freshbooks/migration"
require "blinksale2freshbooks/person_migration"
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
  
  def self.values_match?(val1, val2)
    if !(val1.blank? && val2.blank?) && (val1 != val2)
      false
    else
      true
    end
  end

  def self.blinksale_invoice_status_to_freshbooks(bs_invoice, v3 = true)
    case bs_invoice.status.downcase
    when "draft"
      (v3) ? "draft" : 1
    #when "open"
    else
      (v3) ? "sent" : 2
    #when "pastdue"
    #  (v3) ? "overdue" : 2
    #when "closed"
    #  if bs_invoice.total.to_i > 0 && bs_invoice.total_due.to_i > 0 && bs_invoice.paid.to_i > 0
    #    (v3) ? "partial" : 8
    #  else
    #    (v3) ? "paid" : 4
    #  end
    #else
    #  raise ArgumentError
    end
  end

  def self.compare_blinksale_invoice_to_freshbooks_invoice(bs_invoice, fb_invoice)
    match = true

    # compare invoice attrs between Blinksale & FreshBooks invoice objects
    invoice = Blinksale2FreshBooks::Migration.new(bs_invoice, fb_invoice)
    invoice.add_attr_association("Creation Date", "date", "create_date")
    invoice.add_attr_association("Invoice Number", "number", "invoice_number")
    #invoice.add_attr_association("PO Number", "po_number") # getting method_missing failures for this even though it should work
    invoice.add_attr_association("Terms", "terms")
    invoice.add_attr_association("Days Due", "terms", "due_offset_days")
    invoice.add_attr_association("Currency Code", "currency", "currency_code")
    invoice.add_attr_association("Notes", "notes")
    if !invoice.same?
      puts "\t\t\t\tInvoice attributes differ!"
      match = false
    end

    # compare the invoice statuses
    bs_invoice_status = blinksale_invoice_status_to_freshbooks(bs_invoice, false)
    if (fb_invoice.status != bs_invoice_status)
      puts "\t\t\t\tStatus differs ('#{fb_invoice.status}' vs '#{bs_invoice_status}')"
      match = false
    end

    # confirm the billing client is the same
    bs_client = @blinksale.clients.detect {|client| client.url == bs_invoice.client}
    fb_client = @freshbooks.clients(userid: fb_invoice.customerid)
    if (fb_client.first.userid != find_freshbooks_clients_by_blinksale_client(bs_client).first.userid)
      puts "\t\t\t\tClient differs ('#{fb_client.first.organization}' vs '#{bs_client.name}')"
      match = false
    end

    match
  end

  def self.create_freshbooks_invoice_from_blinksale_invoice(bs_invoice)
    bs_client = @blinksale.clients.detect {|client| client.url == bs_invoice.client}
    fb_client = find_freshbooks_clients_by_blinksale_client(bs_client).first

    @freshbooks.invoices.new({
      invoice: {
        # FreshBooks specific:
        ownerid: 1, # invoice creator (1: business admin)
        #estimateid: 0, # associated estimate
        #basecampid: 0, # connected BaseCamp account
        #sentid: 1, # user who sent invoice (1: business admin)
        # equivalent to Blinksale "invoice" data
        #created_at: bs_invoice.created_at, # read-only field in FreshBooks
        #updated: bs_invoice.updated_at,    # read-only field in FreshBooks
        create_date: bs_invoice.date,
        invoice_number: bs_invoice.number,
        customerid: fb_client.id,
        po_number: bs_invoice.po_number,
        status: blinksale_invoice_status_to_freshbooks(bs_invoice, false),
        terms: bs_invoice.terms,
        due_offset_days: bs_invoice.terms,
        currency_code: bs_invoice.currency,
        notes: bs_invoice.notes
      }
    }.to_json)
  end

  def self.update_freshbooks_invoice_with_blinksale_invoice(fb_invoice, bs_invoice)
    bs_client = @blinksale.clients.detect {|client| client.url == bs_invoice.client}
    fb_client = find_freshbooks_clients_by_blinksale_client(bs_client).first

    # FreshBooks specific:
    #estimateid: 0, # associated estimate
    #basecampid: 0, # connected BaseCamp account
    #sentid: 1, # user who sent invoice (1: business admin)
    # equivalent to Blinksale "invoice" data
    #created_at: bs_invoice.created_at, # read-only field in FreshBooks
    #updated: bs_invoice.updated_at,    # read-only field in FreshBooks
    fb_invoice.create_date = bs_invoice.date
    fb_invoice.invoice_number = bs_invoice.number
    fb_invoice.customerid = fb_client.id
    #fb_invoice.po_number = bs_invoice.po_number # getting method_missing failures for this even though it should work
    fb_invoice.status = blinksale_invoice_status_to_freshbooks(bs_invoice, false)
    fb_invoice.terms = bs_invoice.terms
    fb_invoice.due_offset_days = bs_invoice.terms
    fb_invoice.currency_code = bs_invoice.currency
    fb_invoice.notes = bs_invoice.notes
    fb_invoice
  end

  def self.find_freshbooks_clients_by_blinksale_client(bs_client)
    raise ArgumentError if bs_client.nil?

    fb_clients = []
    bs_client.people.each do |person|
      @freshbooks.clients(email: person.email).each do |fb_client|
        fb_clients << fb_client
      end
    end
    fb_clients
  end

  def self.migrate_blinksale_client(client, dry_run = true)
    raise ArgumentError if client.nil?

    puts "\t#{client.name}..."
    if client.people.length > 0
      puts "\t\tPeople:"
      client.people.each do |person|
        migration = Blinksale2FreshBooks::PersonMigration.new(@blinksale, @freshbooks, person)
        puts "\t\t#{migration.name}..."
        fb_clients = @freshbooks.clients(email: person.email)
        if !migration.needs_creation?
          puts "\t\t\tAlready exists."
          if !migration.needs_update?
            puts "\t\t\tMatches."
          else
            puts "\t\t\tDiffers. Updating..."
            migration.update
            unless dry_run
              migration.freshbooks_client.save
            end
          end
        else
          puts "\t\t\tCreating #{dry_run ? "(not really)" : ""}..."
          migration.create
          unless dry_run || new_client.nil?
            migration.freshbooks_client.save
          end
        end
      end
    end
  end

  def self.migrate_blinksale_invoice(invoice, dry_run = true)
    raise ArgumentError if invoice.nil?

    puts "\t#{invoice.number} (#{invoice.date}; #{invoice.status})..."
    fb_invoices = @freshbooks.invoices(invoice_number: invoice.number)
    if !fb_invoices.nil? && fb_invoices.length > 0
      puts "\t\tAlready exists."
      fb_invoices.each do |fb_invoice|
        if compare_blinksale_invoice_to_freshbooks_invoice(invoice, fb_invoice)
          puts "\t\t\tMatches."
        else
          puts "\t\t\tDiffers. Updating..."
          fb_invoice = update_freshbooks_invoice_with_blinksale_invoice(fb_invoice, invoice)
          unless dry_run
            fb_invoice.save
          end
        end
      end
    else
      puts "\t\tCreating #{dry_run ? "(not really)" : ""}..."
      new_invoice = create_freshbooks_invoice_from_blinksale_invoice(invoice)
      unless dry_run || new_invoice.nil?
        new_invoice.save
      end
    end
  end

end
