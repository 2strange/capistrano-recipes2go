require 'capistrano/recipes2go/base_helpers'
require 'capistrano/recipes2go/nginx_helpers'
include Capistrano::Recipes2go::BaseHelpers
include Capistrano::Recipes2go::NginxHelpers

namespace :load do
  task :defaults do
    set :nginx_domains,           -> { [] }
    set :nginx_major_domain,      -> { false }
    set :nginx_remove_www,        -> { true }
    set :nginx_use_ssl,           -> { false }


    ## Rails Application Server
    set :app_instances,           -> { 1 }
    set :rails_app_server,        -> { :puma }  # Default to Puma, can be :thin


    set :nginx_roles,             -> { :web }
    set :nginx_log_path,          -> { "#{shared_path}/log" }
    set :nginx_static_dir,        -> { "#{current_path}/public" }
    set :nginx_template,          -> { :default }

    # Define Nginx Site Name
    set :nginx_site_name,         -> { "#{fetch(:application)}_#{fetch(:stage)}" }

    # SSL Paths
    set :nginx_ssl_cert,          -> { "/etc/letsencrypt/live/#{ cert_domain }/fullchain.pem" }
    set :nginx_ssl_key,           -> { "/etc/letsencrypt/live/#{ cert_domain }/privkey.pem" }

    # SSL Paths for old domain certificates, if major domain is set
    set :nginx_other_ssl_cert,    -> { "/etc/letsencrypt/live/#{ cert_domain }/fullchain.pem" }
    set :nginx_other_ssl_key,     -> { "/etc/letsencrypt/live/#{ cert_domain }/privkey.pem" }

    set :nginx_hooks,             -> { true }
    set :allow_well_known,        -> { true }
    
    # SSL strict security settings
    set :nginx_strict_security,   -> { fetch(:nginx_use_ssl, false) }

    # SSL Cipher Suite
    set :nginx_ssl_ciphers, -> { 
      "TLS_AES_128_GCM_SHA256:TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256:" \
      "ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-GCM-SHA256:" \
      "ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-GCM-SHA384:" \
      "ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-CHACHA20-POLY1305"
    }


    ## NginX Proxy-Caching
    # Cache Rails
    set :proxy_cache_rails,           -> { false }
    set :proxy_cache_rails_directory, -> { "#{shared_path}/tmp/proxy_cache/rails" }
    set :proxy_cache_rails_levels,    -> { "1:2" }
    set :proxy_cache_rails_name,      -> { "RAILS_#{fetch(:application)}_#{fetch(:stage)}_CACHE" }
    set :proxy_cache_rails_size,      -> { "4m" }
    set :proxy_cache_rails_time,      -> { "24h" }
    set :proxy_cache_rails_max,       -> { "1g" }
    set :proxy_cache_rails_200,       -> { false }
    set :proxy_cache_rails_404,       -> { "60m" }
    set :proxy_cache_rails_stale,     -> { ["error", "timeout", "invalid_header", "updating"] }
    # Cache Media (Dragonfly)
    set :proxy_cache_media,           -> { false }
    set :proxy_cache_media_path,      -> { "media" }
    set :proxy_cache_media_directory, -> { "#{shared_path}/tmp/proxy_cache/media" }
    set :proxy_cache_media_levels,    -> { "1:2" }
    set :proxy_cache_media_name,      -> { "MEDIA_#{fetch(:application)}_#{fetch(:stage)}_CACHE" }
    set :proxy_cache_media_size,      -> { "2m" }
    set :proxy_cache_media_time,      -> { "48h" }
    set :proxy_cache_media_max,       -> { "1g" }

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
          invoke "nginx:service:reload"
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
          invoke "nginx:service:reload"
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
  

  desc "Update Apps Nginx (Upload, Enable if needed, Restart)"
  task :update do
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
  
end



### Add nginx setup to the main setup task
task :setup do
  invoke 'nginx:site:prepare'
end



namespace :deploy do
  after 'deploy:finishing', :restart_nginx_app do
    if fetch(:nginx_hooks)
      invoke "nginx:update"
    end
  end
end
