require 'capistrano/recipes2go/base_helpers'
require 'capistrano/recipes2go/nginx_helpers'
include Capistrano::Recipes2go::BaseHelpers
include Capistrano::Recipes2go::NginxHelpers

namespace :load do
  task :defaults do
    set :nginx_domains,           -> { [] }
    set :nginx_major_domain,      -> { false }
    set :nginx_domain_wildcard,   -> { false }
    set :nginx_redirect_subdomains, -> { false }
    set :nginx_remove_www,        -> { true }
    set :default_site,            -> { false }


    ## Rails Application Server
    set :app_instances,             -> { 1 }
    set :rails_application_server,  -> { :puma }  # Default to Puma, can be :thin


    set :nginx_roles,             -> { :web }
    set :nginx_log_path,          -> { "#{shared_path}/log" }
    set :nginx_root_path,         -> { "/etc/nginx" }
    set :nginx_static_dir,        -> { "public" }
    set :nginx_template,          -> { :default }
    set :nginx_use_ssl,           -> { false }

    # Define Nginx Site Name
    set :nginx_site_name,        -> { "#{fetch(:application)}_#{fetch(:stage)}" }

    # SSL Paths
    set :nginx_ssl_cert,  -> { "/etc/letsencrypt/live/#{ cert_domain }/fullchain.pem" }
    set :nginx_ssl_key,   -> { "/etc/letsencrypt/live/#{ cert_domain }/privkey.pem" }

    set :app_server_ip,   -> { "127.0.0.1" }
    set :nginx_hooks,     -> { true }
    set :allow_well_known, -> { true }
    set :nginx_strict_security, -> { fetch(:nginx_use_ssl, false) }

    # SSL Cipher Suite
    set :nginx_ssl_ciphers, -> { 
      "TLS_AES_128_GCM_SHA256:TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256:" \
      "ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-GCM-SHA256:" \
      "ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-GCM-SHA384:" \
      "ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-CHACHA20-POLY1305"
    }
  end
end

namespace :nginx do

  namespace :site do
    desc "Upload Nginx site configuration"
    task :upload do
      on release_roles fetch(:nginx_roles) do
        config_file = fetch(:nginx_template)
        target_config = fetch(:nginx_site_name)

        puts "📤 Uploading Nginx config: #{target_config}..."
      
        if config_file == :default
          template2go("nginx.conf", "/tmp/#{target_config}")
        else
          template2go(config_file, "/tmp/#{target_config}")
        end

        execute :sudo, :mv, "/tmp/#{target_config}", "/etc/nginx/sites-available/#{target_config}"
      end
    end

    desc "Enable Nginx site (creates symlink)"
    task :enable do
      on release_roles fetch(:nginx_roles) do
        enabled_path = "/etc/nginx/sites-enabled/#{fetch(:nginx_site_name)}"
        available_path = "/etc/nginx/sites-available/#{fetch(:nginx_site_name)}"

        unless test "[ -h #{enabled_path} ]"
          puts "🔗 Enabling Nginx site..."
          execute :sudo, :ln, "-s", available_path, enabled_path
          invoke "nginx:reload"
        else
          puts "✅ Nginx site is already enabled!"
        end
      end
    end

    desc "Disable Nginx site (removes symlink)"
    task :disable do
      on release_roles fetch(:nginx_roles) do
        enabled_path = "/etc/nginx/sites-enabled/#{fetch(:nginx_site_name)}"
        
        if test "[ -h #{enabled_path} ]"
          puts "🚫 Disabling Nginx site..."
          execute :sudo, :rm, "-f", enabled_path
          invoke "nginx:reload"
        else
          puts "⚠️  Nginx site is not enabled!"
        end
      end
    end

    desc "Remove Nginx site configuration"
    task :remove do
      on release_roles fetch(:nginx_roles) do
        available_path = "/etc/nginx/sites-available/#{fetch(:nginx_site_name)}"
        
        if test "[ -f #{available_path} ]"
          puts "🗑 Removing Nginx site configuration..."
          execute :sudo, :rm, "-f", available_path
        else
          puts "⚠️  Nginx site configuration does not exist!"
        end
      end
    end

    desc "Reconfigure Nginx (Upload, Enable if needed, Restart)"
    task :reconfigure do
      on release_roles fetch(:nginx_roles) do
        puts "🔄 Reconfiguring Nginx..."
        invoke "nginx:site:upload"
        
        unless test "[ -h /etc/nginx/sites-enabled/#{fetch(:nginx_site_name)} ]"
          invoke "nginx:site:enable"
        else
          puts "🔗 Site already enabled, skipping enable step!"
        end
        
        invoke "nginx:service:restart"
        puts "✅ Nginx reconfiguration complete!"
      end
    end


    ## Initiate Task, no desc .. so not in cap -T list
    task :prepare do
      on roles fetch(:nginx_roles) do
        puts "⚙️  Ensuring Nginx directories exist..."
        execute :sudo, "mkdir -p /etc/nginx/sites-available /etc/nginx/sites-enabled"
        invoke "nginx:site:upload"
        puts "✅ Nginx setup completed! Enable it when ready with `cap nginx:site:enable`"
      end
    end

  end

  namespace :service do
    %w[start stop restart reload].each do |command|
      desc "#{command.capitalize} nginx service"
      task command do
        on release_roles fetch(:nginx_roles) do
          puts "🔄 Running: systemctl #{command} nginx..."
          execute :sudo, "systemctl #{command} nginx"
        end
      end
    end

    desc "Check nginx configuration"
    task :check_config do
      on release_roles fetch(:nginx_roles) do
        puts "🧐 Checking nginx configuration..."
        execute :sudo, "nginx -t"
      end
    end

    desc "Check nginx status"
    task :check_status do
      on release_roles fetch(:nginx_roles) do
        puts "🔍 Checking nginx status..."
        execute :sudo, "systemctl status nginx --no-pager"
      end
    end
  end
end

namespace :setup do
  desc "Prepare Nginx: Upload config but don't enable yet"
  task :prepare do
    on roles fetch(:nginx_roles) do
      puts "⚙️  Ensuring Nginx directories exist..."
      execute :sudo, "mkdir -p /etc/nginx/sites-available /etc/nginx/sites-enabled"
      invoke "nginx:site:upload"
      puts "✅ Nginx setup completed! Enable it when ready with `cap nginx:site:enable`"
    end
  end
end

### Add keys:setup to the main setup task
task :setup do
  invoke 'keys:site:prepare'
end



namespace :deploy do
  after 'deploy:finishing', :restart_nginx_app do
    if fetch(:nginx_hooks)
      invoke "nginx:site:reconfigure"
    end
  end
end
