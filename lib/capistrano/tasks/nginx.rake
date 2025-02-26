require 'capistrano/recipes2go/base_helpers'
require 'capistrano/recipes2go/nginx_helpers'
include Capistrano::Recipes2go::BaseHelpers
include Capistrano::Recipes2go::NginxHelpers

namespace :load do
  task :defaults do
    set :nginx_domains,               -> { [] }
    set :nginx_major_domain,          -> { false }
    set :nginx_domain_wildcard,       -> { false }
    set :nginx_redirect_subdomains,   -> { false }
    set :nginx_remove_www,            -> { true }
    set :default_site,                -> { false }
    set :app_instances,               -> { 1 }
    set :nginx_service_path,          -> { 'systemctl' } # ✅ Use systemd instead of service
    set :nginx_roles,                 -> { :web }
    set :nginx_log_path,              -> { "#{shared_path}/log" }
    set :nginx_root_path,             -> { "/etc/nginx" }
    set :nginx_static_dir,            -> { "public" }
    set :nginx_sites_enabled,         -> { "sites-enabled" }
    set :nginx_sites_available,       -> { "sites-available" }
    set :nginx_template,              -> { :default }
    set :nginx_use_ssl,               -> { false }

    ## SSL Paths
    set :nginx_ssl_cert,  -> { "/etc/letsencrypt/live/#{fetch(:nginx_major_domain, fetch(:nginx_domains).first)}/fullchain.pem" }
    set :nginx_ssl_key,   -> { "/etc/letsencrypt/live/#{fetch(:nginx_major_domain, fetch(:nginx_domains).first)}/privkey.pem" }

    set :app_server_ip,   -> { "127.0.0.1" }
    set :nginx_hooks,     -> { true }
    set :allow_well_known, -> { true }  # ✅ Allow ACME challenge
    set :nginx_strict_security, -> { fetch(:nginx_use_ssl, false) }

    ## Diffie-Hellman settings (Deprecated in favor of ECDH)
    set :nginx_use_diffie_hellman, -> { false } # ❌ Default to false (use ECDH instead)
    set :nginx_diffie_hellman_path, -> { "/etc/ssl/certs/dhparam.pem" }

    ## Modern SSL Cipher Suite (Mozilla Intermediate)
    set :nginx_ssl_ciphers, -> { 
      "TLS_AES_128_GCM_SHA256:TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256:" \
      "ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-GCM-SHA256:" \
      "ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-GCM-SHA384:" \
      "ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-CHACHA20-POLY1305"
    }

    ## Proxy Caching (Performance Improvements)
    set :proxy_cache_rails,       -> { false }
    set :proxy_cache_media,       -> { false }
    set :proxy_cache_media_path,  -> { "media" }
  end
end

namespace :nginx do

  task :load_vars do
    set :sites_available,       -> { File.join(fetch(:nginx_root_path), fetch(:nginx_sites_available)) }
    set :sites_enabled,         -> { File.join(fetch(:nginx_root_path), fetch(:nginx_sites_enabled)) }
    set :enabled_application,   -> { File.join(fetch(:sites_enabled), "#{fetch(:application)}_#{fetch(:stage)}") }
    set :available_application, -> { File.join(fetch(:sites_available), "#{fetch(:application)}_#{fetch(:stage)}") }
  end

  %w[start stop restart reload].each do |command|
    desc "#{command.capitalize} nginx service"
    task command do
      on release_roles fetch(:nginx_roles) do
        if command == 'stop' || test("[ $(sudo nginx -t 2>&1 | grep -c 'fail') -eq 0 ]")
          execute :sudo, "systemctl #{command} nginx"
        end
      end
    end
  end

  desc "Check nginx configuration"
  task :check_conf do
    on release_roles fetch(:nginx_roles) do
      execute :sudo, "nginx -t"
    end
  end

  desc "Check nginx status"
  task :check_status do
    on release_roles fetch(:nginx_roles) do
      execute :sudo, "systemctl status nginx --no-pager"
    end
  end

  desc "Fix port conflicts (80)"
  task :fix_port80 do
    on release_roles fetch(:nginx_roles) do
      execute :sudo, "ss -tulpn | grep ':80' && sudo fuser -k 80/tcp || echo 'No process on port 80'"
    end
  end

  desc "Fix port conflicts (443)"
  task :fix_port443 do
    on release_roles fetch(:nginx_roles) do
      execute :sudo, "ss -tulpn | grep ':443' && sudo fuser -k 443/tcp || echo 'No process on port 443'"
    end
  end
  
  
  namespace :site do
    desc "List available and enabled sites"
    task :list do
      on release_roles fetch(:nginx_roles) do
        execute :sudo, "ls -l #{fetch(:nginx_sites_available)}"
        execute :sudo, "ls -l #{fetch(:nginx_sites_enabled)}"
      end
    end


    desc 'Creates and uploads the Nginx site configuration'
    task :add do
      on release_roles fetch(:nginx_roles) do
        # Explicitly invoke load_vars to ensure variables are loaded
        # invoke 'nginx:load_vars'

        available_path = fetch(:sites_available)

        # Ensure sites_available is set correctly
        if available_path.to_s.strip.empty?
          error_message = "⚠️ ERROR: 'sites_available' is empty! Make sure 'nginx:load_vars' sets it correctly."
          puts error_message
          exit 1
        end
        
        within available_path do
          config_file = fetch(:nginx_template)
          target_config = "#{fetch(:application)}_#{fetch(:stage)}"
        
          if config_file == :default
            template2go("nginx.conf", "/tmp/#{target_config}")
          else
            template2go(config_file, "/tmp/#{target_config}")
          end
        
          execute :sudo, :mv, "/tmp/#{target_config}", "#{available_path}/#{target_config}"
        end
      end
    end


    desc 'Enable site by creating a symbolic link'
    task :enable do
      on release_roles fetch(:nginx_roles) do
        
        if test "! [ -h #{fetch(:enabled_application)} ]"
          execute :sudo, :ln, "-s", fetch(:available_application), fetch(:enabled_application)
          invoke "nginx:reload"
        end
      end
    end

    desc 'Disable site by removing symbolic link'
    task :disable do
      on release_roles fetch(:nginx_roles) do
        if test "[ -h #{fetch(:enabled_application)} ]"
          execute :sudo, :rm, "-f", fetch(:enabled_application)
          invoke "nginx:reload"
        end
      end
    end

    desc 'Remove the Nginx site configuration'
    task :remove do
      on release_roles fetch(:nginx_roles) do
        if test "[ -f #{fetch(:available_application)} ]"
          execute :sudo, :rm, "-f", fetch(:available_application)
        end
      end
    end
    
  end

  # Explicitly invoke load_vars to ensure variables are loaded
  before 'nginx:site', :load_vars

end

namespace :deploy do
  after 'deploy:finishing', :restart_nginx_app do
    if fetch(:nginx_hooks)
      invoke "nginx:site:add"
      invoke "nginx:site:enable"
      invoke "nginx:restart"
    end
  end
end
