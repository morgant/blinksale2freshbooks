require "blinksale2freshbooks/migration"
require "blinksale/blinksale"
require "freshbooks/freshbooks"

module Blinksale2FreshBooks

  class PersonMigration

    attr_accessor :blinksale, :freshbooks, :blinksale_person, :person_migration, :company_migration

    def initialize(blinksale, freshbooks, blinksale_person)
      raise ArgumentError if blinksale.nil? || freshbooks.nil? || blinksale_person.nil?
      @blinksale = blinksale
      @freshbooks = freshbooks
      @blinksale_person = blinksale_person
      
      # init person migration
      fb_client = find_freshbooks_client_by_email
      @person_migration = Blinksale2FreshBooks::Migration.new(@blinksale_person, fb_client)
      @person_migration.add_attr_association("First Name", "first_name", "fname")
      @person_migration.add_attr_association("Last Name", "last_name", "lname")
      @person_migration.add_attr_association("Email", "email")
      @person_migration.add_attr_association("Business Phone", "phone_office", "bus_phone")
      @person_migration.add_attr_association("Mobile Phone", "phone_mobile", "mob_phone")
      
      # init company migration
      blinksale_client = @blinksale_person.parent.parent
      @company_migration = Blinksale2FreshBooks::Migration.new(blinksale_client, fb_client)
      @company_migration.add_attr_association("Organization Name", "name", "organization")
      @company_migration.add_attr_association("Street Address (Line 1)", "address1", "p_street")
      @company_migration.add_attr_association("Street Address (Line 2)", "address2", "p_street2")
      @company_migration.add_attr_association("City", "city", "p_city")
      @company_migration.add_attr_association("State", "state", "p_province")
      @company_migration.add_attr_association("Postal Code", "zip", "p_code")
      @company_migration.add_attr_association("Country", "country", "p_country")
      @company_migration.add_attr_association("Fax", "fax")
    end

    def freshbooks_client
      if (needs_creation?)
        nil
      else
        raise ArgumentError if @person_migration.dst != @company_migration.dst
        @person_migration.dst
      end
    end

    def freshbooks_client=(freshbooks_client)
      raise ArgumentError if !needs_creation? || !freshbooks_client.nil?
      @person_migration.dst = freshbooks_client
      @company_migration.dst = freshbooks_client
    end

    def create
      raise ArgumentError if !needs_creation?

      # build a hash of data to initialize a new FreshBooks Client with
      client_data = @person_migration.migration_hash
      client_data.merge!(@company_migration.migration_hash)

      # create the new FreshBooks Client
      new_client = @freshbooks.clients.new({client: client_data}.to_json)
      freshbooks_client = new_client
    end

    def name
      raise ArgumentError if @blinksale_person.nil?
      "#{@blinksale_person.first_name} #{@blinksale_person.last_name}"
    end

    def needs_creation?
      raise ArgumentError if @person_migration.nil? || @company_migration.nil?
      (@person_migration.dst.nil? || @company_migration.dst.nil?)
    end

    def needs_update?
      needs_creation? || !(@person_migration.same? && @company_migration.same?)
    end

    def update
      raise ArgumentError if needs_creation?
      @person_migration.update
      @company_migration.update
    end

    def save
      raise ArgumentError if needs_creation?
      freshbooks_client.save
    end

    private

    def find_freshbooks_client_by_email
      raise ArgumentError if @blinksale_person.email.blank?
      clients = @freshbooks.clients(email: @blinksale_person.email)
      if !clients.nil? && clients.length > 0
        clients.first
      else
        nil
      end
    end

  end

end