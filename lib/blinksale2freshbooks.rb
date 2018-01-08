require "net/http"
require "json"
require "active_support/core_ext/object/blank"
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
  
  def self.values_match?(val1, val2)
    if !(val1.blank? && val2.blank?) && (val1 != val2)
      false
    else
      true
    end
  end
  
  def self.compare_blinksale_person_to_freshbooks_client(bs_person, fb_client)
    match = true
    bs_client = bs_person.parent.parent
    if !values_match?(bs_person.first_name, fb_client.fname)
      puts "\t\t\t\tFirst Name differs ('#{bs_person.first_name}' vs '#{fb_client.fname}')"
      match = false
    end
    if !values_match?(bs_person.last_name, fb_client.lname)
      puts "\t\t\t\tLast Name differs ('#{bs_person.last_name}' vs '#{fb_client.lname}')"
      match = false
    end
    if !values_match?(bs_person.email, fb_client.email)
      puts "\t\t\t\tEmail differs ('#{bs_person.email}' vs '#{fb_client.email}')"
      match = false
    end
    if !values_match?(bs_person.phone_office, fb_client.bus_phone)
      puts "\t\t\t\tOffice Phone differs ('#{bs_person.phone_office}' vs '#{fb_client.bus_phone}')"
      match = false
    end
    if !values_match?(bs_person.phone_mobile, fb_client.mob_phone)
      puts "\t\t\t\tMobile Phone differs ('#{bs_person.phone_mobile}' vs '#{fb_client.mob_phone}')"
      match = false
    end
    if !values_match?(bs_client.name, fb_client.organization)
      puts "\t\t\t\tCompany/Organization differs ('#{bs_client.name}' vs '#{fb_client.organization}')"
      match = false
    end
    if !values_match?(bs_client.address1, fb_client.p_street)
      puts "\t\t\t\tAddress (Line 1) differs ('#{bs_client.address1}' vs '#{fb_client.p_street}')"
      match = false
    end
    if !values_match?(bs_client.address2, fb_client.p_street2)
      puts "\t\t\t\tAddress (Line 2) differs ('#{bs_client.address2}' vs '#{fb_client.p_street2}')"
      match = false
    end
    if !values_match?(bs_client.city, fb_client.p_city)
      puts "\t\t\t\tCity differs ('#{bs_client.city}' vs '#{fb_client.p_city}')"
      match = false
    end
    if !values_match?(bs_client.state, fb_client.p_province)
      puts "\t\t\t\tState differs ('#{bs_client.state}' vs '#{fb_client.p_province}')"
      match = false
    end
    if !values_match?(bs_client.zip, fb_client.p_code)
      puts "\t\t\t\tZip differs ('#{bs_client.zip}' vs '#{fb_client.p_code}')"
      match = false
    end
    if !values_match?(bs_client.country, fb_client.p_country)
      puts "\t\t\t\tCountry differs ('#{bs_client.country}' vs '#{fb_client.p_country}')"
      match = false
    end
    if !values_match?(bs_client.fax, fb_client.fax)
      puts "\t\t\t\tFax differs ('#{bs_client.fax}' vs '#{fb_client.fax}')"
      match = false
    end
    match
  end

  def self.create_freshbooks_client_from_blinksale_person(bs_person)
    bs_client = bs_person.parent.parent
    @freshbooks.clients.new({
      client: {
        # equivalent to BlinkSale "person" data:
        fname: bs_person.first_name,
        lname: bs_person.last_name,
        email: bs_person.email,
        bus_phone: bs_person.phone_office,  # note: may need to better handle whether to use person.phone_office or client.phone
        mob_phone: bs_person.phone_mobile,
        # equivalent to BlinkSale "client" data:
        organization: bs_client.name,
        p_street: bs_client.address1,
        p_street2: bs_client.address2,
        p_city: bs_client.city,
        p_province: bs_client.state,
        p_code: bs_client.zip,
        p_country: bs_client.country,
        fax: bs_client.fax
      }
    }.to_json)
  end
  
  def self.update_freshbooks_client_with_blinksale_person(fb_client, bs_person)
    bs_client = bs_person.parent.parent
    # equivalent to BlinkSale "person" data:
    fb_client.fname = bs_person.first_name
    fb_client.lname = bs_person.last_name
    fb_client.email = bs_person.email
    fb_client.bus_phone = bs_person.phone_office  # note: may need to better handle whether to use person.phone_office or client.phone
    fb_client.mob_phone = bs_person.phone_mobile
    # equivalent to BlinkSale "client" data:
    fb_client.organization = bs_client.name
    fb_client.p_street = bs_client.address1
    fb_client.p_street2 = bs_client.address2
    fb_client.p_city = bs_client.city
    fb_client.p_province = bs_client.state
    fb_client.p_code = bs_client.zip
    fb_client.p_country = bs_client.country
    fb_client.fax = bs_client.fax
    fb_client
  end
  
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
          fb_clients.each do |fb_client|
            if compare_blinksale_person_to_freshbooks_client(person, fb_client)
              puts "\t\t\tMatches."
            else
              puts "\t\t\tDiffers. Updating..."
              fb_client = update_freshbooks_client_with_blinksale_person(fb_client, person)
              unless dry_run
                fb_client.save
              end
            end
          end
        else
          puts "\t\t\tCreating #{dry_run ? "(not really)" : ""}..."
          new_client = create_freshbooks_client_from_blinksale_person(person)
          unless dry_run || new_client.nil?
            new_client.save
          end
        end
      end
    end
  end
end
