blinksale2freshbooks
====================
by Morgan T. Aldridge <morgant@makkintosshu.com>

OVERVIEW
--------

Ruby gem & tool for migrating data (clients, invoices, etc.) from Blinksale to FreshBooks (the newer cloud accounting version, not FreshBooks Classic) using their respective APIs.

INSTALLATION
------------

Add this line to your application's Gemfile:

```ruby
gem 'blinksale2freshbooks'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install blinksale2freshbooks

USAGE
-----

There are two ways to use this:

1) Include & use the module in your own ruby script/project
2) Use the `blinksale2freshbooks` CLI tool

### The Ruby Module

1) Require `blinksale2freshbooks` in your code:  
  require 'blinksale2freshbooks`  
2) [Create a FreshBooks application](https://my.freshbooks.com/#/developer) and get your auth code
3) Configure the module with your Blinksale & FreshBooks accounts:  
  Blinksale2FreshBooks.configure do |config|  
    config.blinksale_id = "your_blinksale_company_id"  
    config.blinksale_username = "your_account@example.com"  
    config.blinksale_password = "some_password"  
    config.freshbooks_api_client_id = "your_client_id"  
    config.freshbooks_api_secret = "your_secret"  
    config.freshbooks_api_redirect_uri = "https://localhost:8080/"  
    config.freshbooks_api_auth_code = "your_auth_code"  
  end  
4) Call the `connect` method to open the connection to Blinksale & FreshBooks:  
  Blinksale2FreshBooks.connect  
5) Call the `migrate` method to migrate data from Blinksale to FreshBooks:  
  Blinksale2FreshBooks.migrate(true)  # specify true for dry-run (no changes will be made to FreshBooks or false to apply changes)

### The `blinksale2freshbooks` CLI Tool

Run `bin/blinksale2freshbooks -h` for all options, but a basic migration would be run as follows (you can remove the `--dry-run` option to allow changes to be made to FreshBooks):

  bin/blinksale2freshbooks --blinksale-id "your_blinksale_company_id" --blinksale-user "your_account@example.com" --blinksale-pass "some_password" --freshbooks-client "your_client_id" --freshbooks-secret "your_secret" --freshbooks-redirect-url "https://localhost:8080/" --freshbooks-code "your_auth_code" --dry-run

DEVELOPMENT
-----------

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

CONTRIBUTING
------------

Bug reports and pull requests are welcome on GitHub at https://github.com/morgant/blinksale2freshbooks.

REFERENCE
---------

* [Blinksale API](https://www.blinksale.com/api/)
  * https://application.blinksale.com/api/blinksale.rb
  * https://application.blinksale.com/api/rest_client.rb
  * https://application.blinksale.com/api/xml_node.rb
* [FreshBooks API](https://www.freshbooks.com/api/start) (not FreshBooks Classic)
* http://guides.rubygems.org/make-your-own-gem/#documenting-your-code
* https://bundler.io/v1.13/guides/creating_gem
* https://blog.codeship.com/exploring-structure-ruby-gems/
* http://lizabinante.com/blog/creating-a-configurable-ruby-gem/
* https://stackoverflow.com/a/10112179

LICENSE
-------

Copyright (c) 2017 Morgan T. Aldridge. All rights reserved.

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
