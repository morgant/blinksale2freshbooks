# = Blinksale.rb
#
# Insanely easy access to your Blinksale.com account data. Usage:
#
#   # Instantiate an object with your Blinksale subdomain, userid, and password:
#   mycompany = Blinksale.new 'mycompany', 'username', 'password'
#
#   mycompany.clients.keys            #=> [123, 456, 789]
#   client = mycompany.clients[123]   #=> < ... https://mycompany.blinksale.com/clients/123>
#   client.name                       #=> "Acme Inc."
#   bob = client.people[456]          #=> < ... https://mycompany.blinksale.com/clients/123/people/456>
#   bob.email                         #=> "bob@example.com"
#   bob.email = 'bob@acme.com'
#   bob.save
#   invoice = mycompany.invoices[789] #=> < ... https://mycompany.blinksale.com/invoices/789>
#   invoice.date = '2006-10-01'
#   invoice.save
#   invoices[987].delete
#   closed_invoices = mycompany.invoices :status => 'closed'
#   closed_invoices.total             # => 45000.00
#
# To use within Rails, just add blinksale.rb (and its prerequesites,
# rest_client.rb and xml_node.rb) into the lib directory.
#
# API documentation:     https://www.blinksale.com/api/
# Terms of Service:      https://www.blinksale.com/help/tos
# Unit tests:            https://www.blinksale.com/api/blinksale_test.rb
# Questions/patches:     Scott Raymond <sco@scottraymond.net>
# Licensed under MIT:    https://www.blinksale.com/api/MIT-LICENSE
# Requires Ruby >= 1.8.4
# Requires REST::Client: https://www.blinksale.com/api/rest_client.rb
#
require 'blinksale/rest_client'

class Blinksale < REST::Client

  def initialize(blinksale_id, userid, password)
    @host       = blinksale_id + ".blinksale.com"
    @userid     = userid
    @password   = password
    @user_agent = "Blinksale.rb/1.0 RestClient.rb/1.0"
    @media_type = "application/vnd.blinksale+xml"

    has_many :clients do |client|
      client.has_many :people
    end

    has_many :invoices, :extend => Invoice do |invoice|
      invoice.has_many :deliveries
      invoice.has_many :payments
    end

  end

  module Invoice
    module ResourceMethods
      def html; get_type "text/html"; end
    end
    module CollectionMethods
      def total; self.inject(0){ |sum, i| sum + i.total.to_f }; end
      def max_number; self.collect{ |i| i.number }.max; end
      def atom; get_type "application/atom+xml"; end
      def rss; get_type "application/rss+xml"; end
    end
  end

end
