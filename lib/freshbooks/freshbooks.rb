# = FreshBooks.rb
#
require 'freshbooks/oauth2_rest_client'

class FreshBooks < REST::OAuth2Client

  attr_accessor :account_id, :business_id

  def initialize(client_id, client_secret, redirect_uri, auth_code, token = nil)
    @host             = "api.freshbooks.com"
    @oauth2_client_id = client_id
    @oauth2_secret    = client_secret
    @oauth2_redirect_uri = redirect_uri
    @oauth2_auth_uri  = "https://my.freshbooks.com/service/auth/oauth/authorize?client_id=#{@oauth2_client}&response_type=code&redirect_uri=#{@oauth2_redirect_uri}"
    @oauth2_auth_code = auth_code
    @user_agent       = "FreshBooks.rb/1.0 RestClient.rb/1.0"
    @media_type       = "application/json"
    @headers          = { 'Api-Version' => 'alpha' }
    
    if token.nil? && !auth_code.nil?
      get_token("/auth/oauth/token")
    elsif !token.nil?
      @oauth2_token = token
      if token.expired?
        refresh_token("/auth/oauth/token")
      end
    end
  end
  
  # The new FreshBooks API wants all search/filter query string parameters as "search[key]=value" instead of "key=value",
  # so we rewrite those here before letting REST::Client take care of the rest
  def resource(options = {})
    if options.is_a?(Hash) && options.key?(:filter) && !options[:filter].empty?
      options[:filter] = Hash[options[:filter].map {|k, v| [CGI::escape("search[#{k}]"), v] }]
    end
    super options
  end
  
  def businesses
    businesses = []
    unless identity.business_memberships.nil?
      identity.business_memberships.each do |membership|
        businesses << membership["business"]
      end
    end
    businesses
  end
  
  def using_business
    (@business_id.nil? || @account_id.nil?) ? nil : businesses.find {|business| business["id"] == @business_id && business["account_id"] == @account_id}
  end
  
  def use_business(business_id, account_id)
    raise ArgumentError unless businesses.any? {|business| business["id"] == business_id && business["account_id"] == account_id}
    
    @business_id = business_id
    @account_id = account_id
    
    # clear the resource cache (we don't want to accidentally return/modify data for the wrong account!)
    @resources = nil
    
    has_many :clients, path: "accounting/account/#{@account_id}/users/clients"
    has_many :invoices, path: "accounting/account/#{@account_id}/invoices/invoices",:extend => Invoice do |invoice|
      invoice.has_many :lines
      #invoice.has_many :comments
    end
    has_many :payments
  end

  def identity; resource :path => "/auth/api/v1/users/me"; end

  module Invoice
    module ResourceMethods

    end
    module CollectionMethods
      def total; self.inject(0){ |sum, i| sum + i.total.to_f }; end
      def max_number; self.collect{ |i| i.number }.max; end
    end
  end

end
