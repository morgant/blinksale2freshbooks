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

TODO: Write usage instructions here

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
* https://stackoverflow.com/a/10112179

LICENSE
-------

Copyright (c) 2017 Morgan T. Aldridge. All rights reserved.

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
