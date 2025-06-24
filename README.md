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

The gem already includes `capistrano`, `capistrano-rails` and `capistrano-rvm` .. so actually thats all you need to deploy your rails app.


In Capfile:
```ruby

require "capistrano/rvm"
require "capistrano/bundler"
require "capistrano/rails/assets"
require "capistrano/rails/migrations"

require 'capistrano/recipes2go/server'      # Setup Debian12 / Ubuntu24 server tasks

require 'capistrano/recipes2go/certbot'     # Lets-Encrypt helpers
require 'capistrano/recipes2go/db'          # Database helpers (seed + yaml_db tasks)
require 'capistrano/recipes2go/dragonfly'   # Dragonfly image exchange helpers
require 'capistrano/recipes2go/keys'        # Rails KEY and CONFIG helpers
require 'capistrano/recipes2go/monit'       # Monit helpers
require 'capistrano/recipes2go/nginx'       # Nginx helpers
require 'capistrano/recipes2go/nvm'         # Node Version Manager helpers
require 'capistrano/recipes2go/postgresql'  # Postgresql .. taken from capistrano-postgresql, which is not maintained anymore
require 'capistrano/recipes2go/proxy_nginx' # Proxy-Nginx helpers (1 proxy => 1 app-server)
require 'capistrano/recipes2go/puma'        # Puma (App-Server) helpers
require 'capistrano/recipes2go/redis'       # Redis helpers
require 'capistrano/recipes2go/redis_uns'   # Redis-UnNameSpace helpers (Sidekiq 7+)
require 'capistrano/recipes2go/sidekiq'     # Sidekiq helpers
require 'capistrano/recipes2go/systemd'     # Systemd clean Log-Files helper
require 'capistrano/recipes2go/thin'        # Thin (App-Server) helpers
require 'capistrano/recipes2go/ufw'         # Linux FireWall helpers


```

## 📜 Documentation

#### Server Setup

- [Server Setup](docs/server.md) - Setup a new server with Capistrano


#### App Deployment

- [**db** - Database Backups](docs/db.md) - Manage your database with Capistrano
- [**systemd** - Log Cleanup](docs/systemd.md) - Manage daily log cleanup with systemd
- [**redis_uns** - Redis UnNameSpacing](docs/redis_uns.md) - Migrate Redis keys without namespaces (for Sidekiq 7+)
- [**monit** - Monit Integration](docs/monit.md) - Integrate Monit for process monitoring
- [**proxy_nginx** - Nginx Integration](docs/proxy_nginx.md) - Proxy-Nginx helpers (1 proxy => 1 app-server)






#### Sample Config for minimal proxy setup

```ruby

set :user,                  "deploy"

## Application-Server:
server "180.11.22.11", user: fetch(:user), roles: %w{app web}
## Proxy-Server: (no-release)
server "180.11.22.22", user: fetch(:user), roles: %w{proxy},    no_release: true

set :deploy_to,             "/home/#{ fetch(:user) }/#{ fetch(:application) }_#{fetch(:stage)}"
set :branch,                'master'

## App-Server upstream
set :nginx_upstream_host,   "150.11.22.33"
set :nginx_upstream_port,   "3000"

## NginX
set :nginx_domains,         ['example.com']

## ssl-handling
set :nginx_use_ssl,         true
set :certbot_email,         "mail@example.com"
set :certbot_roles,         [:proxy]
set :certbot_webroot,       "/var/www/html"

```


## Contributing
Contribution directions go here.

## License
The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
