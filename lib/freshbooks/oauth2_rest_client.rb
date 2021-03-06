# = OAuth2RestClient.rb
#
# Implements a client for an HTTP service with a RESTian interface which uses OAuth2
# 
# Licensed as MIT:    https://www.blinksale.com/api/MIT-LICENSE
# Questions/patches:  Morgan Aldridge <morgant@makkintosshu.com>
# Requires REST::Client: https://www.blinksale.com/api/rest_client.rb
# 
require 'blinksale/rest_client'
require 'json'

module REST

  class Resource
    # replace these REST::Resource methods so they support XML or JSON
    def self.unserialize(data, media_type)
      #puts "media_type: #{media_type}"
      if media_type.downcase == "application/json"
        json_key = nil
        json_data = JSON.parse(data)
        if json_data.key?("response") && json_data["response"].key?("result")
          #puts "data[response][result]: #{json_data['response']['result']}"
          json_key, json_data = json_data["response"]["result"].find {|k, v| v.is_a?(Array) || v.is_a?(Hash)}
        elsif json_data.key?("response")
          #puts "data[response]: #{json_data['response']}"
          json_data = json_data["response"]
        end
        [json_key, json_data]
      else
        XmlNode.from_xml(data)
      end
    end

    def self.serialize(document, key = nil)
      if document.is_a?(XmlNode)
        document.to_s
      else
        (key.nil?) ? document.to_json : { key => document }.to_json
      end
    end
    
    def get(name)
      if @client.media_type.downcase == "application/json"
        document[name]
      else
        document.send(name) ? document.send(name).node_value : document[name]
      end
    end
    
    def set(name, value)
      if @client.media_type == "application/json"
        document[name] = value
      else
        document.send(name).node_value = value
      end
    end
    
    def attribute?(name)
      if @client.media_type.downcase == "application/json"
        return true if document[name]
      else
        return true if document.send(name) or document[name]
      end
      (@data.nil? and refresh) ? attribute?(name) : false
    end
    
    def document
      unless @document
        @document = self.class.unserialize(data, @client.media_type)
        @key, @document = @document[0], @document[1] if @client.media_type == "application/json"
      end
      @document
    end

    def serialized; self.class.serialize(document, (@client.media_type == "application/json") ? @key : nil); end

    def create
      response = @client.post @parent.path, serialized, :expected_response => 200
      if @client.media_type.downcase == "application/json"
        @key = nil
        json_data = JSON.parse(response.body)
        if json_data.key?("response") && json_data["response"].key?("result")
          @key, json_data = json_data["response"]["result"].find {|k, v| v.is_a?(Array) || v.is_a?(Hash)}#[1]
        elsif json_data.key?("response")
          json_data = json_data["response"]
        end
        @data, @document, @path = response.body, nil, @parent.send(:path_from, json_data["id"])
      else
        @data, @document, @path = response.body, nil, @parent.send(:path_for, response['Location'])
      end
      @parent.refresh
      true
    end
    
    def parent
      @parent
    end

    private

    # add these REST::Resource methods to ease the support of JSON in addition to XML
  end

  module CollectionMethods
    private
    
    def paths
      if @client.media_type.downcase == "application/json"
        resource_name = @path.split('/').last
        document.collect { |e| path_from(e["id"]) if e.key?("id") }
      else
        document.node.root.elements.collect { |e| path_for e.attributes['uri'] }
      end
    end
    
    def element_for(id)
      if @client.media_type.downcase == "application/json"
        resource = document.detect { |e| e.key?("id") && e["id"] == id }
        JSON.generate(resource)
      else
        document.node.root.elements.detect{ |n| path_for(n.attributes['uri']) == path_from(id) }  
      end
    end
  end

  class OAuth2Token
    attr_accessor :access_token, :refresh_token, :token_type, :created_at, :expires_in
    
    def authorization_headers
      unless @token_type.nil? || @access_token.nil?
        { 'Authorization' => "#{@token_type.capitalize} #{@access_token}" }
      else
        nil
      end
    end
    
    def expired?
      (Time.now > Time.at(@created_at + @expires_in)) ? true : false
    end
  end

  class OAuth2Client < REST::Client

    attr_accessor :oauth2_auth_uri, :oauth2_client_id, :oauth2_secret, :oauth2_redirect_uri, :oauth2_token, :oauth2_grant_type, :oauth2_auth_code
    
    def get_token(path)
      response = post path, {
        'client_id' => @oauth2_client_id,
        'client_secret' => @oauth2_secret,
        'redirect_uri' => @oauth2_redirect_uri,
        'grant_type' => (@oauth2_grant_type || 'authorization_code'),
        'code' => @oauth2_auth_code
      }.to_json
      #puts "response: #{response.body}"
      json = JSON.parse(response.body, {symbolize_names: true}) unless response.nil?
      if !json.nil? && [:access_token, :refresh_token, :token_type].all? {|k| json.key?(k)}
        @oauth2_token = OAuth2Token.new
        @oauth2_token.access_token = json[:access_token]
        @oauth2_token.refresh_token = json[:refresh_token]
        @oauth2_token.token_type = json[:token_type]
        @oauth2_token.created_at = json[:created_at]
        @oauth2_token.expires_in = json[:expires_in]
      end
    end
    
    def refresh_token(path)
      response = post path, {
        'client_id' => @oauth2_client_id,
        'client_secret' => @oauth2_secret,
        'redirect_uri' => @oauth2_redirect_uri,
        'grant_type' => 'refresh_token',
        'refresh_token' => @oauth2_token.refresh_token
      }.to_json
      puts "response: #{response.body}"
      json = JSON.parse(response.body, {symbolize_names: true}) unless response.nil?
      if !json.nil? && [:access_token, :refresh_token, :token_type].all? {|k| json.key?(k)}
        @oauth2_token.access_token = json[:access_token]
        @oauth2_token.refresh_token = json[:refresh_token]
        @oauth2_token.token_type = json[:token_type]
        @oauth2_token.created_at = json[:created_at]
        @oauth2_token.expires_in = json[:expires_in]
      end
    end
    
    private

    def request(verb, path, body = nil, options = {})
      unless @oauth2_token.nil?
        options.merge!({:headers => @oauth2_token.authorization_headers})
      end
      super verb, path, body, options
    end
  end

end