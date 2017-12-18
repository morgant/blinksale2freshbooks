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

  class OAuth2Token
    attr_accessor :access_token, :refresh_token, :token_type, :created_at, :expires_in
    
    def authorization_headers
      unless @token_type.nil? || @access_token.nil?
        { 'Authorization' => "#{@token_type} #{@access_token}" }
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
    
    def refresh_token
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