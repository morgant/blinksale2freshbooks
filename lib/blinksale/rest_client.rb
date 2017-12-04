# = RestClient.rb
#
# Implements a client for an HTTP service with a RESTian interface. For example:
#
#   myapp = REST::Client.new
#   myapp.host = 'www.myapp.com'
#   myapp.media_type = 'text/html'
#   puts myapp.get('/').body
#
# In addition to the +get(path)+ method seen above, you have +delete(path)+, +post(path, body)+,
# and +put(path, body)+. Exceptions will be raised for response codes outside of the 200
# and 300 range. To enable HTTP Basic Authentication, set the +userid+ and +password+ setters.
# To set a port other than 80, use the +port+ setter. To set the default Content-type and Accept
# headers, use the +media_type+ setter (defaults to application/xml). For example:
#
#   myapp = REST::Client.new
#   myapp.host       = 'www.myapp.com'
#   myapp.port       = 3000
#   myapp.userid     = 'me'
#   myapp.password   = 'secret'
#   myapp.media_type = 'text/json'
#
#   myapp.get    '/widgets'
#   myapp.post   '/widgets', 'new widget data'
#   myapp.put    '/widgets/1', 'updated widget data'
#   myapp.delete '/widgets/1'
#
# Although REST::Client can be instantiated directly, the more common use is to subclass
# it for a particular service. For example:
#
#   class MyApp < REST::Client
#
#     def initialize subdomain, userid, password
#       @host       = subdomain + ".myapp.com"
#       @userid     = userid
#       @password   = password
#       @user_agent = "MyApp.rb/1.0 RestClient.rb/1.0"
#     end
#
#   end
#
# The Rest::Client#resource method takes a path and returns a REST::Resource instance, which
# provides convienient access to the data. For example:
#
#   acme = MyApp.new 'acme', 'me', 'secret' # => #<MyApp:2991360 http://acme.myapp.com>
#   users = acme.resource "/users" # => #<REST::Resource:2940210 http://acme.myapp.com/users>
#   users.data # => (XML data)
#   users.data = "(new XML data)"
#   users.save
#
# To easily model resource collections, use the +has_many+ method. For example:
#
#   class MyApp < REST::Client
#
#     def initialize
#       # @host = ...
#       has_many :widgets
#     end
#
#   end
#
#   acme = MyApp.new 'acme', 'me', 'secret' # => #<MyApp:2991360 http://acme.myapp.com>
#   acme.widgets      # => #<REST::Resource:2961070 http://acme.myapp.com/widgets>
#   acme.widgets.size # => 3
#   acme.widgets.keys # => [1, 2, 3]
#   acme.widgets[1]   # => #<REST::Resource:2961071 http://acme.myapp.com/widgets/1>
#
# In this example, +acme.widgets+ creates an instance of REST::Resource
# corresponding to the URL "http://acme.myapp.com/widgets", and +acme.widgets[1]+ creates
# an instance of REST::Resource corresponding to the URL "http://acme.myapp.com/widgets/1".
# Both objects are lazy-loading, so instantiating won't fetch anything; the resources won't
# actually be requested until their data is needed. You can provide query string options to
# a collection as well:
#
#   acme.widgets(:foo => 'bar') # (http://acme.myapp.com/widgets?foo=bar)
#
# You can also represent nested resources:
#
#   has_many :widgets do |widget|
#     widget.has_many :sprockets
#   end
#
#   acme.widgets[1].sprockets     # (http://acme.myapp.com/widgets/1/sprockets)
#   acme.widgets[1].sprockets[2]  # (http://acme.myapp.com/widgets/1/sprockets/2)
#
# Resources are assumed to be XML, and accessors are available for each element of the root
# node. For example:
#
#   widget = acme.widgets[1] # => #<REST::Resource:2961070 http://acme.myapp.com/widgets/1>
#   widget.name # => "My Widget"
#   widget.name = "Your Widget"
#   widget.save
#
# Real-world example: https://www.blinksale.com/api/blinksale.rb
# Licensed as MIT:    https://www.blinksale.com/api/MIT-LICENSE
# Questions/patches:  Scott Raymond <sco@scottraymond.net>
# Requires XmlNode:   https://www.blinksale.com/api/xml_node.rb
# Exception handling code inspired by ActiveResource.
#
require 'net/https'
require 'blinksale/xml_node'

# _why's metaid: http://whytheluckystiff.net/articles/seeingMetaclassesClearly.html
class Object
  # The hidden singleton lurks behind everyone
  def metaclass; class << self; self; end; end
  def meta_eval &blk; metaclass.instance_eval &blk; end

  # Adds methods to a metaclass
  def meta_def name, &blk
    meta_eval { define_method name, &blk }
  end

  # Defines an instance method within a class
  def class_def name, &blk
    class_eval { define_method name, &blk }
  end
end

module REST

  class Client

    attr_accessor :host, :port, :userid, :password, :media_type, :headers, :use_ssl, :user_agent

    # The root resource instance for the client
    def root; resource :path => '/'; end

    # Creates a new collection resource on the root resource
    # and creates an access method on the singleton class
    def has_many(resource_name, options = {}, &block)
      root.has_many resource_name, options, block
      meta_def resource_name do |*filter|
        root.send(resource_name, *filter)
      end
    end

    # Returns a resource instance with the given options (of which :path is required).
    # Instances are cached according to the :path and :filter options.
    def resource(options = {})
      options = { :path => options } if options.is_a? String
      raise ArgumentError unless options[:path]
      options = { :client => self }.merge(options)
      query_string = Resource.query_string(options[:filter] || {})
      (@resources ||= {})[options[:path] + query_string] ||= Resource.new(options)
    end

    def url
      scheme = "https://"
      host   = @host || ''
      port   = (@port.nil? or @port==80 or @port==443) ? "" : ":#{@port}"
      scheme + host + port
    end

    def inspect
      "\#<#{self.class}:#{object_id} #{url}>"
    end

    %w( get post put delete ).each do |verb|
      define_method verb do |*params|
        options = params.last.is_a?(Hash) ? params.pop : {}
        path = params.shift
        body = params.shift
        handle_response http.request(request(verb, path, body, options)), options[:expected_response]
      end
    end

    private

      def request(verb, path, body = nil, options = {})
        request_class = Net::HTTP.const_get verb.to_s.capitalize
        request = request_class.new path
        request.body = body
        request.initialize_http_header headers(options[:headers] || {})
        request.basic_auth(@userid, @password) unless @userid.nil?
        request
      end

      def headers(extras = {})
        { 'Accept'       => (@media_type || 'application/xml'),
          'Content-type' => (@media_type || 'application/xml'),
          'User-Agent'   => (@user_agent || 'RestClient.rb/1.0')
        }.merge(@headers || {}).merge(extras)
      end

      def http(refresh = false)
        if @http.nil? or refresh
          @http = Net::HTTP.new @host, (@port || 443)
          @http.use_ssl = true
          @http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        end
        @http
      end

      # Raises exceptions from Net::HTTP for response codes outside of the 200 range
      # or different than the expected response
      def handle_response(response, expected = nil)
        response.value
        # todo: pick a better exception
        raise "Expected a #{expected} response" if expected and expected != response.code.to_i
        response
      end

  end

  class Resource

    # Blank slate
    #instance_methods.each { |m| undef_method m unless m =~ /^__|instance_eval$/ }

    attr_accessor :path

    def self.query_string params = {}
      return '' unless params.any?
      '?' + params.map.sort{ |a,b| a.first.to_s <=> b.first.to_s  }.map{ |a| "#{a.first}=#{a.last}" }.join('&')
    end

    def initialize(options = {})
      options.each{ |k, v| instance_variable_set "@#{k.to_s}", v } # would accessors work?
    end

    # Adds a new method to the singleton class that will return a collection resource
    def has_many(resource_name, options = {}, block = nil)
      meta_def resource_name do |*params|
        path = (path_with_slash  + (options[:path] || resource_name.to_s))
        filter = params.first || {}
        collection = @client.resource(:path => path, :parent => self, :block => block, :filter => filter, :extend => options[:extend])
        collection.extend(CollectionMethods) # unless?
        collection.extend(options[:extend]::CollectionMethods) if options[:extend] # unless?
        collection
      end
    end

    # todo: turn these into procs, so they're pluggable
    def self.unserialize(data); XmlNode.from_xml data; end
    def self.serialize(document); document.to_s; end
    def get(name); document.send(name) ? document.send(name).node_value : document[name]; end
    def set(name, value); document.send(name).node_value = value; end

    # Returns whether +name+ is an attribute on document. If @partial_data exists,
    # it's looked at first; @data is fetched if necessary.
    def attribute?(name)
      return true if document.send(name) or document[name]
      (@data.nil? and refresh) ? attribute?(name) : false
    end

    def data=(data); @data = data; @document = nil; end

    def data(refresh = false)
      return @data unless @data.nil? or refresh
      return @partial_data unless @partial_data.nil? or refresh
      response = @client.get filtered_path, :expected_response => 200
      @data, @partial_data, @document = response.body, nil, nil
      @data
    end

    def document; @document ||= self.class.unserialize(data); end
    def serialized; Resource.serialize(document); end
    def new_record?; @path.nil?; end
    def refresh; @data, @partial_data, @document = nil, nil, nil; self; end
    def save; new_record? ? create : update; end

    def create
      response = @client.post @parent.path, serialized, :expected_response => 201
      @data, @document, @path = response.body, nil, @parent.send(:path_for, response['Location'])
      @parent.refresh
      true
    end

    def update
      response = @client.put @path, serialized, :expected_response => 200
      @data, @document = response.body, nil
      true
    end

    def delete
      response = @client.delete path, :expected_response => 200
      @parent.refresh
      true
    end

    def get_type(media_type)
      response = @client.get path, :headers => { "Accept" => media_type }, :expected_response => 200
      response.body
    end

    def filtered_path; @path + Resource.query_string(@filter || {}); end
    def path_with_slash; (@path.match(/\/$/) ? @path : "#{@path}/"); end
    def url; @client.url + filtered_path || ''; end
    def inspect; "\#<#{self.class}:#{object_id} #{url}>"; end

    def method_missing(method_symbol, *params)
      method_name = method_symbol.to_s
      setter = method_name.to_s.gsub!(/=/,'')
      return super unless attribute?(method_name)
      setter ? set(method_name, params.first) : get(method_name)
    end

  end

  # Mixed into resources that act as collections
  module CollectionMethods

    include Enumerable
    def each(&block) data; resources.each &block; end
    def resources; keys.map{ |k| send(:[], k) }; end

    def keys; paths.collect { |p| p.gsub("#{path}/",'').to_i }; end
    def size; keys.size; end
    alias :length :size

    def [](id)
      resource = @client.resource :path => path_from(id), :parent => self, :partial_data => partial_data_for(id)
      @block.call(resource) if @block
      resource.extend(@extend::ResourceMethods) if @extend # unless?
      resource
    end

    def new(data) Resource.new :parent => self, :data => data, :client => @client; end
    def create(data) send(:new, data).save; end

    private

      def paths; document.node.root.elements.collect{ |e| path_for e.attributes['uri'] }; end
      def path_for(url); URI.parse(url).path; end
      def id_from(path); path.gsub("#{@path}/",'').to_i; end
      def path_from(id); "#{@path}/#{id}"; end
      def element_for(id); document.node.root.elements.detect{ |n| path_for(n.attributes['uri'])==path_from(id) }; end
      def partial_data_for(id); @data.nil? ? nil : element_for(id).to_s end

  end

end
