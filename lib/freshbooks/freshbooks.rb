# = FreshBooks.rb
#
require 'freshbooks/oauth2_rest_client'

class FreshBooks < REST::OAuth2Client

  def initialize(client_id, client_secret, redirect_uri, auth_code)
    @host             = "api.freshbooks.com"
    @oauth2_client_id = client_id
    @oauth2_secret    = client_secret
    @oauth2_redirect_uri = redirect_uri
    @oauth2_auth_uri  = "https://my.freshbooks.com/service/auth/oauth/authorize?client_id=#{@oauth2_client}&response_type=code&redirect_uri=#{@oauth2_redirect_uri}"
    @oauth2_auth_code = auth_code
    @user_agent       = "FreshBooks.rb/1.0 RestClient.rb/1.0"
    @media_type       = "application/json"
    @headers          = { 'Api-Version' => 'alpha' }
    
    get_authorization_token("/auth/oauth/token")
  end

end
