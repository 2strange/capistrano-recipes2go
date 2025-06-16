require 'capistrano/recipes2go/base_helpers'
require 'capistrano/recipes2go/nginx_helpers'
include Capistrano::Recipes2go::BaseHelpers
include Capistrano::Recipes2go::NginxHelpers

namespace :load do
  task :defaults do
    # === GENERAL NGINX SETTINGS (can be overridden or used by both) ===
    set :nginx_user,              -> { 'www-data' } # User Nginx runs as (Debian/Ubuntu)
    set :nginx_group,             -> { 'www-data' } # Group Nginx runs as (Debian/Ubuntu)

    # === PROXY NGINX SETTINGS ===
    set :nginx_proxy_roles,       -> { :proxy }
    # Pfad relativ zur Rake-Datei (tasks/nginx.rake -> ../templates/)
    set :nginx_proxy_template,    -> { :default }
    set :nginx_proxy_site_name,   -> { "#{fetch(:application)}_#{fetch(:stage)}_proxy" }



    # Domains and SSL settings are primarily for the proxy
    set :nginx_domains,           -> { [] }
    set :nginx_major_domain,      -> { false }
    set :nginx_remove_www,        -> { true }
    set :nginx_use_ssl,           -> { false } # Proxy handles SSL termination

    # also allow http access, if ssl is enabled (full http block will be created, but only if this is set to true)
    set :nginx_also_allow_http,   -> { false }


    ## Rails Application Server
    set :app_instances,           -> { 1 }
    set :rails_app_server,        -> { :puma }  # Default to Puma, can be :thin







    set :nginx_ssl_cert,          -> { "/etc/letsencrypt/live/#{ cert_domain }/fullchain.pem" }
    set :nginx_ssl_key,           -> { "/etc/letsencrypt/live/#{ cert_domain }/privkey.pem" }
    # For old domain certs if major_domain is set
    set :nginx_other_ssl_cert,    -> { "/etc/letsencrypt/live/#{ cert_domain }/fullchain.pem" }
    set :nginx_other_ssl_key,     -> { "/etc/letsencrypt/live/#{ cert_domain }/privkey.pem" }

    set :nginx_strict_security,   -> { fetch(:nginx_use_ssl, false) } # For HSTS header
    set :nginx_ssl_ciphers,       -> {
      "TLS_AES_128_GCM_SHA256:TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256:" \
      "ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-GCM-SHA256:" \
      "ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-GCM-SHA384:" \
      "ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-CHACHA20-POLY1305"
    }
    set :allow_well_known_proxy,  -> { true } # For Certbot on proxy
    set :nginx_proxy_well_known_root, -> { "/var/www/html" } # Standard path for Certbot webroot on proxy

    set :nginx_proxy_log_folder,  -> { "/var/log/nginx" } # Standard Nginx log folder for proxy
    set :nginx_proxy_hooks,       -> { true }


    # Upstream App Server (where the App-Nginx runs)
    # WICHTIG: Diese in config/deploy/<stage>.rb setzen!
    # z.B. set :nginx_upstream_host, '10.0.0.5'
    #      set :nginx_upstream_port, 8080
    ## new style: Use these variables to define the upstream app server, falling back to old style if not set
    set :nginx_upstream_host,     -> { fetch(:nginx_upstream_app_host, nil) }
    set :nginx_upstream_port,     -> { fetch(:nginx_upstream_app_port, 4500) } # Port App-Nginx is exposed on (e.g. Docker mapped port or direct)


    # === APP NGINX SETTINGS ===
    set :nginx_app_roles,         -> { :app }
    set :nginx_app_template,      -> { :default }
    set :nginx_app_site_name,     -> { "#{fetch(:application)}_#{fetch(:stage)}_app" }

    # App specific paths (relative to shared_path for linked_dirs)
    set :nginx_root_folder,       -> { "#{shared_path}/public" }    # JS app static files (Nuxt default: "dist")
    set :nginx_static_dir,        -> { "#{shared_path}/public" }
    set :nginx_log_folder,        -> { "log" }    # App Nginx logs

    # This is from your original setup, relevant for the app server.
    # append :linked_dirs, fetch(:nginx_root_folder), fetch(:nginx_log_folder)

    set :nginx_app_hooks,         -> { true }
    set :allow_well_known_app,    -> { false } # Usually handled by proxy


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

  # --- PROXY NGINX TASKS ---
  namespace :proxy do
    # Helper task to ensure upstream variables are set for the proxy
    task :ensure_upstream_vars_set do
      unless fetch(:nginx_upstream_host)
        error "FEHLER: Bitte `:nginx_upstream_host` in deiner Stage-Konfiguration setzen (z.B. config/deploy/#{fetch(:stage)}.rb)."
        info "Beispiel: set :nginx_upstream_host, 'interne.ip.des.app.servers'"
        info "          set :nginx_upstream_port, 8080"
        exit 1
      end
    end

    namespace :site do
      desc "Upload Proxy Nginx site configuration"
      task :upload do
        invoke "nginx:proxy:ensure_upstream_vars_set"
        on roles fetch(:nginx_proxy_roles) do
          config_file = fetch(:nginx_proxy_template)
          target_config = fetch(:nginx_proxy_site_name)

          puts "📤 [PROXY] Uploading Nginx config: #{target_config} from #{config_file}"
          if config_file == :default
            puts "📤 [PROXY] Using default template"
            template2go("nginx_proxy.conf", "/tmp/#{target_config}")
          else
            puts "📤 [PROXY] Using custom template #{config_file}"
            template2go(config_file, "/tmp/#{target_config}")
          end
          execute :sudo, :mv, "/tmp/#{target_config}", "/etc/nginx/sites-available/#{target_config}"
        end
      end

      desc "Enable Proxy Nginx site"
      task :enable do
        on roles fetch(:nginx_proxy_roles) do
          enabled_path = "/etc/nginx/sites-enabled/#{fetch(:nginx_proxy_site_name)}"
          available_path = "/etc/nginx/sites-available/#{fetch(:nginx_proxy_site_name)}"
          unless test "[ -h #{enabled_path} ]"
            puts "🔗 [PROXY] Enabling Nginx site..."
            execute :sudo, :ln, "-s", available_path, enabled_path
            invoke "nginx:proxy:service:reload"
          else
            puts "✅ [PROXY] Nginx site is already enabled!"
          end
        end
      end

      desc "Disable Proxy Nginx site"
      task :disable do
        on roles fetch(:nginx_proxy_roles) do
          enabled_path = "/etc/nginx/sites-enabled/#{fetch(:nginx_proxy_site_name)}"
          if test "[ -h #{enabled_path} ]"
            puts "🚫 [PROXY] Disabling Nginx site..."
            execute :sudo, :rm, "-f", enabled_path
            invoke "nginx:proxy:service:reload"
          else
            puts "⚠️  [PROXY] Nginx site is not enabled!"
          end
        end
      end

      desc "Remove Proxy Nginx site configuration"
      task :remove do
        on roles fetch(:nginx_proxy_roles) do
          available_path = "/etc/nginx/sites-available/#{fetch(:nginx_proxy_site_name)}"
          if test "[ -f #{available_path} ]"
            puts "🗑 [PROXY] Removing Nginx site configuration..."
            execute :sudo, :rm, "-f", available_path
          else
            puts "⚠️  [PROXY] Nginx site configuration does not exist!"
          end
        end
      end

      task :prepare do
        on roles fetch(:nginx_proxy_roles) do
          puts "⚙️  [PROXY] Ensuring Nginx directories exist..."
          execute :sudo, "mkdir -p /etc/nginx/sites-available /etc/nginx/sites-enabled"
          if fetch(:allow_well_known_proxy)
            execute :sudo, "mkdir -p #{fetch(:nginx_proxy_well_known_root)}"
            # Optional: set owner for nginx_proxy_well_known_root if certbot runs as different user
            # execute :sudo, "chown #{fetch(:nginx_user)}:#{fetch(:nginx_group)} #{fetch(:nginx_proxy_well_known_root)}"
          end
          invoke "nginx:proxy:site:upload"
          puts "✅ [PROXY] Nginx setup completed! Enable with `cap #{fetch(:stage)} nginx:proxy:site:enable`"
        end
      end
    end # end site

    namespace :service do
      %w[start stop restart reload].each do |command|
        desc "#{command.capitalize} Proxy Nginx service"
        task command do
          on roles fetch(:nginx_proxy_roles) do
            puts "🔄 [PROXY] Running: systemctl #{command} nginx..."
            execute :sudo, "systemctl #{command} nginx"
          end
        end
      end
      desc "Check Proxy Nginx configuration"
      task :check_config do
        on roles fetch(:nginx_proxy_roles) do
          puts "🧐 [PROXY] Checking nginx configuration..."
          execute :sudo, "nginx -t"
        end
      end
      desc "Check Proxy Nginx status"
      task :check_status do
        on roles fetch(:nginx_proxy_roles) do
          puts "🔍 [PROXY] Checking nginx status..."
          execute :sudo, "systemctl status nginx --no-pager"
        end
      end
    end # end service

    desc "Update Proxy Nginx (Upload, Enable if needed, Reload/Restart)"
    task :update do
      on roles fetch(:nginx_proxy_roles) do
        puts "🔄 [PROXY] Reconfiguring Nginx..."
        invoke "nginx:proxy:site:upload"
        enabled_path = "/etc/nginx/sites-enabled/#{fetch(:nginx_proxy_site_name)}"
        if test "[ -h #{enabled_path} ]"
          puts "🔗 [PROXY] Site already enabled, reloading."
        else
          invoke "nginx:proxy:site:enable" # This will also reload
        end
        invoke! "nginx:proxy:service:restart" # Or :restart if significant changes
        puts "✅ [PROXY] Nginx reconfiguration complete!"
      end
    end
  end # end :proxy namespace


## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## 
## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## 


  # --- APP NGINX TASKS ---
  namespace :app do
    namespace :site do
      desc "Upload App Nginx site configuration"
      task :upload do
        on roles fetch(:nginx_app_roles) do
          config_file = fetch(:nginx_app_template)
          target_config = fetch(:nginx_app_site_name)

          puts "📤 [APP] Uploading Nginx config: #{target_config} from #{config_file}"
          if config_file == :default
            template2go("nginx_app.conf", "/tmp/#{target_config}")
          else
            template2go(config_file, "/tmp/#{target_config}")
          end
          execute :sudo, :mv, "/tmp/#{target_config}", "/etc/nginx/sites-available/#{target_config}"
        end
      end

      desc "Enable App Nginx site"
      task :enable do
        on roles fetch(:nginx_app_roles) do
          enabled_path = "/etc/nginx/sites-enabled/#{fetch(:nginx_app_site_name)}"
          available_path = "/etc/nginx/sites-available/#{fetch(:nginx_app_site_name)}"
          unless test "[ -h #{enabled_path} ]"
            puts "🔗 [APP] Enabling Nginx site..."
            execute :sudo, :ln, "-s", available_path, enabled_path
            invoke "nginx:app:service:reload" # Or :restart if it's a container
          else
            puts "✅ [APP] Nginx site is already enabled!"
          end
        end
      end

      desc "Disable App Nginx site"
      task :disable do
        on roles fetch(:nginx_app_roles) do
          enabled_path = "/etc/nginx/sites-enabled/#{fetch(:nginx_app_site_name)}"
          if test "[ -h #{enabled_path} ]"
            puts "🚫 [APP] Disabling Nginx site..."
            execute :sudo, :rm, "-f", enabled_path
            invoke "nginx:app:service:reload" # Or :restart
          else
            puts "⚠️  [APP] Nginx site is not enabled!"
          end
        end
      end

      desc "Remove App Nginx site configuration"
      task :remove do
        on roles fetch(:nginx_app_roles) do
          available_path = "/etc/nginx/sites-available/#{fetch(:nginx_app_site_name)}"
          if test "[ -f #{available_path} ]"
            puts "🗑 [APP] Removing Nginx site configuration..."
            execute :sudo, :rm, "-f", available_path
          else
            puts "⚠️  [APP] Nginx site configuration does not exist!"
          end
        end
      end

      task :prepare do
        on roles fetch(:nginx_app_roles) do
          puts "⚙️  [APP] Ensuring Nginx directories exist..."
          execute :sudo, "mkdir -p /etc/nginx/sites-available /etc/nginx/sites-enabled"
          # Ensure shared directories for logs and app root exist and have Nginx access
          # This is usually handled by Capistrano's deploy:check and linked_dirs setup
          invoke "nginx:app:site:upload"
          puts "✅ [APP] Nginx setup completed! Enable with `cap #{fetch(:stage)} nginx:app:site:enable`"
        end
      end
    end # end site

    namespace :service do
      # Adjust commands if App Nginx is in a Docker container
      # Example: set :nginx_app_cmd_prefix, "sudo docker exec my_nginx_container"
      # execute "#{fetch(:nginx_app_cmd_prefix, 'sudo')} systemctl #{command} nginx"
      %w[start stop restart reload].each do |command|
        desc "#{command.capitalize} App Nginx service"
        task command do
          on roles fetch(:nginx_app_roles) do
            # IF DOCKER: Replace with docker command e.g.
            # execute :sudo, "docker restart #{fetch(:nginx_app_container_name)}" if command == 'restart'
            # execute :sudo, "docker exec #{fetch(:nginx_app_container_name)} nginx -s #{command == 'restart' ? 'reload' : command}" # for reload, stop
            puts "🔄 [APP] Running: systemctl #{command} nginx..."
            execute :sudo, "systemctl #{command} nginx"
          end
        end
      end
      desc "Check App Nginx configuration"
      task :check_config do
        on roles fetch(:nginx_app_roles) do
          # IF DOCKER: execute :sudo, "docker exec #{fetch(:nginx_app_container_name)} nginx -t"
          puts "🧐 [APP] Checking nginx configuration..."
          execute :sudo, "nginx -t"
        end
      end
      desc "Check App Nginx status"
      task :check_status do
        on roles fetch(:nginx_app_roles) do
          # IF DOCKER: execute :sudo, "docker ps -f name=#{fetch(:nginx_app_container_name)}"
          puts "🔍 [APP] Checking nginx status..."
          execute :sudo, "systemctl status nginx --no-pager"
        end
      end
    end # end service

    desc "Update App Nginx (Upload, Enable if needed, Reload/Restart)"
    task :update do
      on roles fetch(:nginx_app_roles) do
        puts "🔄 [APP] Reconfiguring Nginx..."
        invoke "nginx:app:site:upload"
        enabled_path = "/etc/nginx/sites-enabled/#{fetch(:nginx_app_site_name)}"
        if test "[ -h #{enabled_path} ]"
          puts "🔗 [APP] Site already enabled, reloading."
        else
          invoke "nginx:app:site:enable"
        end
        invoke! "nginx:app:service:restart" # Or :restart
        puts "✅ [APP] Nginx reconfiguration complete!"
      end
    end

    desc "Fix App Nginx folder rights (if permission problems occur)"
    task :fix_folder_rights do
      on roles fetch(:nginx_app_roles) do # Only on app servers
        puts "🛡️  [APP] Fixing folder rights..."
        execute :sudo, "chmod o+x /home/#{fetch(:user)}"
        execute :sudo, "chmod o+x #{fetch(:deploy_to)}"
        execute :sudo, "chmod o+x #{current_path}" # current_path might not be fully set if deploy failed
        execute :sudo, "chmod o+x #{shared_path}"
        # Nginx (user www-data) needs read access to app files and write to logs
        # These commands assume nginx_root_folder and nginx_log_folder are under shared_path
        execute :sudo, "chown -R #{fetch(:user)}:#{fetch(:nginx_group)} #{shared_path}/#{fetch(:nginx_root_folder)}"
        execute :sudo, "chown -R #{fetch(:user)}:#{fetch(:nginx_group)} #{shared_path}/#{fetch(:nginx_log_folder)}"
        execute :sudo, "chmod -R g+rX,o-rwx #{shared_path}/#{fetch(:nginx_root_folder)}" # Group read/execute
        execute :sudo, "chmod -R g+rwX,o-rwx #{shared_path}/#{fetch(:nginx_log_folder)}" # Group read/write/execute
        # If Nginx runs as www-data and deploy user is different, you might need to add www-data to deploy user's group or use ACLs.
        # A simpler (but less secure for shared hosts) approach for www-data to read:
        # execute :sudo, "chmod -R o+rX #{shared_path}/#{fetch(:nginx_root_folder)}"
        # execute :sudo, "find #{shared_path}/#{fetch(:nginx_root_folder)} -type d -exec chmod o+x {} \\;" # Ensure directories are executable
      end
    end
  end # end :app namespace


  # --- COMBINED/UTILITY TASKS ---
  desc "Setup Nginx for both Proxy and App roles defined in current stage"
  task :setup_all do
    if roles(fetch(:nginx_proxy_roles)).any?
      invoke 'nginx:proxy:site:prepare'
    else
      puts "ℹ️ No :proxy roles defined for stage #{fetch(:stage)}, skipping proxy setup."
    end
    if roles(fetch(:nginx_app_roles)).any?
      invoke 'nginx:app:site:prepare'
    else
      puts "ℹ️ No :app roles defined for stage #{fetch(:stage)}, skipping app Nginx setup."
    end
  end

  desc "Update Nginx configurations for both Proxy and App roles defined in current stage"
  task :update_all do
    if roles(fetch(:nginx_proxy_roles)).any?
      invoke 'nginx:proxy:update'
    else
      puts "ℹ️ No :proxy roles defined for stage #{fetch(:stage)}, skipping proxy update."
    end
    if roles(fetch(:nginx_app_roles)).any?
      invoke 'nginx:app:update'
    else
      puts "ℹ️ No :app roles defined for stage #{fetch(:stage)}, skipping app Nginx update."
    end
  end

end # end :nginx namespace


# --- DEPLOY HOOKS ---
# Your original global setup hook. You might want to make it more specific
# or use the new `nginx:setup_all` task manually or hooked elsewhere.
# task :setup do
#   # invoke 'nginx:proxy:site:prepare' # If always proxy
#   # invoke 'nginx:app:site:prepare'   # If always app
#   invoke 'nginx:setup_all' # This will check roles
# end

namespace :deploy do
  after 'deploy:finishing', :update_nginx_configurations do
    # Update Proxy Nginx if hooks enabled and proxy roles exist for the stage
    if fetch(:nginx_proxy_hooks) && roles(fetch(:nginx_proxy_roles)).any?
      puts "훅: nginx:proxy:update wird aufgerufen"
      invoke "nginx:proxy:update"
    end

    # Update App Nginx if hooks enabled and app roles exist for the stage
    if fetch(:nginx_app_hooks) && roles(fetch(:nginx_app_roles)).any?
      puts "훅: nginx:app:update wird aufgerufen"
      invoke "nginx:app:update"
    end
  end
end