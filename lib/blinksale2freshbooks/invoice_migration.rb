require "blinksale2freshbooks/migration"
require "blinksale/blinksale"
require "freshbooks/freshbooks"

module Blinksale2FreshBooks

  class InvoiceMigration

    attr_accessor :blinksale, :freshbooks, :blinksale_invoice, :invoice_migration

    def initialize(blinksale, freshbooks, blinksale_invoice)
      raise ArgumentError if blinksale.nil? || freshbooks.nil? || blinksale_invoice.nil?
      @blinksale = blinksale
      @freshbooks = freshbooks
      @blinksale_invoice = blinksale_invoice

      # init invoice migration
      fb_invoice = find_freshbooks_invoice_by_number
      @invoice_migration = Blinksale2FreshBooks::Migration.new(blinksale_invoice, fb_invoice)
      @invoice_migration.add_attr_association("Creation Date", "date", "create_date")
      @invoice_migration.add_attr_association("Invoice Number", "number", "invoice_number")
      #@invoice_migration.add_attr_association("PO Number", "po_number") # getting method_missing failures for this even though it should work
      @invoice_migration.add_attr_association("Terms", "terms")
      @invoice_migration.add_attr_association("Days Due", "terms", "due_offset_days")
      @invoice_migration.add_attr_association("Currency Code", "currency", "currency_code")
      @invoice_migration.add_attr_association("Notes", "notes")
    end

    def freshbooks_invoice
      if (needs_creation?)
        nil
      else
        @invoice_migration.dst
      end
    end

    def freshbooks_invoice=(freshbooks_client)
      raise ArgumentError if !needs_creation? || !freshbooks_invoice.nil?
      @invoice_migration.dst = freshbooks_invoice
    end

    def create
      raise ArgumentError if !needs_creation?

      # build a hash of data to initialize a new FreshBooks Invoice with
      invoice_data = {
        # FreshBooks specific:
        ownerid: 1, # invoice creator (1: business admin)
        #estimateid: 0, # associated estimate
        #basecampid: 0, # connected BaseCamp account
        #sentid: 1, # user who sent invoice (1: business admin)
      }
      invoice_data.merge!(@invoice_migration.migration_hash)

      # create the new FreshBooks Invoice
      new_invoice = @freshbooks.invoices.new({invoice: invoice_data}.to_json)
      freshbooks_invoice = new_invoice
    end

    def invoice_number
      raise ArgumentError if @blinksale_invoice.nil?
      @blinksale_invoice.number
    end

    def needs_creation?
      raise ArgumentError if @invoice_migration.nil?
      @invoice_migration.dst.nil?
    end

    def needs_update?
      differ = false
      if needs_creation? || !@invoice_migration.same?
        differ = true
      end

      status = convert_blinksale_status_to_freshbooks(false)
      if (freshbooks_invoice.status != status)
        puts "Status differs ('#{freshbooks_invoice.status}' vs '#{status}')"
        differ = true
      end

      # confirm the billing client is the same
      freshbooks_client = @freshbooks.clients(userid: freshbooks_invoice.customerid).first
      if (freshbooks_client.userid != find_freshbooks_client.userid)
        puts "Client differs ('#{fb_client.first.organization}' vs '#{bs_client.name}')"
        differ = true
      end

      differ
    end

    def update
      raise ArgumentError if needs_creation?
      @invoice_migration.update
      
      # update the status & billing client, if necessary
      invoice = freshbooks_invoice
      invoice.status = convert_blinksale_status_to_freshbooks
      invoice.customerid = find_freshbooks_client.userid
    end

    def save
      raise ArgumentError if needs_creation?
      freshbooks_invoice.save
    end

    private

    def find_freshbooks_invoice_by_number
      raise ArgumentError if @blinksale_invoice.number.blank?
        invoices = @freshbooks.invoices(invoice_number: @blinksale_invoice.number)
        if !invoices.nil? && invoices.length > 0
          invoices.first
        else
          nil
        end
    end

    def find_freshbooks_client
      raise ArgumentError if @blinksale_invoice.nil? || @blinksale_invoice.client.nil?
      blinksale_client = @blinksale.clients.detect {|client| client.url == @blinksale_invoice.client}
      freshbooks_clients = []
      blinksale_client.people.each do |person|
        @freshbooks.clients(email: person.email).each do |client|
          freshbooks_clients << client
        end
      end
      freshbooks_clients.first
    end

    def convert_blinksale_status_to_freshbooks(v3 = true)
      case @blinksale_invoice.status.downcase
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

  end

end