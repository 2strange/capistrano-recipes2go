# Capistrano::Recipes2go

collection of my most used capistrano recipes

## Usage
How to use my plugin.

## Installation
Add this line to your application's Gemfile:

```ruby
group :development do
  gem "capistrano-recipes2go",  require: false,   github: "2strange/capistrano-recipes2go"
end
```

And then execute:
```bash
$ bundle
```

The gem already includes `capistrano`, `capistrano-rails` and `capistrano-rvm` .. so actually thats all you need to deploy your app.


In Capfile:
```ruby

require "capistrano/rvm"
require "capistrano/bundler"
require "capistrano/rails/assets"
require "capistrano/rails/migrations"

require 'capistrano/recipes2go/db'
require 'capistrano/recipes2go/keys'
require 'capistrano/recipes2go/lets_encrypt'

```


## Contributing
Contribution directions go here.

## License
The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
