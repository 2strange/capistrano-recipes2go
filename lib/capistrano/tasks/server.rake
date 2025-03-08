namespace :load do
  task :defaults do
    # Default user for deployment, uses `fetch(:user, "deploy")` if not explicitly set
    set :srvr_user,                 -> { fetch(:user, "deploy") }

    # Default roles for server
    set :server_roles,              -> { :web }
    
    # Whether to create the deploy user if it does not exist
    set :srvr_create_user,          -> { false }

    # Ruby version and RVM installation
    set :srvr_install_rvm,          -> { true }
    set :srvr_rvm_ruby_version,     -> { fetch(:rvm_ruby_version, "3.3.5") }

    # Node.js version and NVM installation
    set :srvr_install_nvm,          -> { true }
    set :srvr_nvm_version,          -> { fetch(:nvm_version, 'v0.39.7') }
    set :srvr_nvm_node_version,     -> { fetch(:nvm_node_version, "23") }

    # Install core services
    set :srvr_install_nginx,        -> { true }
    set :srvr_install_postgres,     -> { true }
    set :srvr_install_certbot,      -> { true }
    set :srvr_install_redis,        -> { true }

    set :srvr_install_thin,         -> { false }    # activate if you want to use Thin

    # Enable firewall and allow additional ports
    set :srvr_enable_firewall,      -> { true }
    set :srvr_ufw_additional_ports, -> { fetch(:ufw_additional_ports, []) } # Example: ["2224", "8080"]
  end
end


namespace :server do
  # Update and upgrade system packages
  desc "Update and upgrade system packages"
  task :update_packages do
    on roles(fetch(:server_roles)) do
      execute :sudo, "apt update -y"
      execute :sudo, "apt upgrade -y"
    end
  end

  # Install needed packages
  desc "Install needed packages"
  task :needed_packages do
    on roles(fetch(:server_roles)) do
      execute :sudo, "apt install -y build-essential bison curl git-core git rsync"
    end
  end

  # Create deploy user if needed
  desc "Create deploy user if needed"
  task :create_user do
    on roles(fetch(:server_roles)) do
      user = fetch(:srvr_user)
      puts "👤 Creating deploy user '#{user}' if not present..."
      execute :sudo, "id #{user} || adduser --disabled-password --gecos '' #{user}"
      execute :sudo, "usermod -aG sudo #{user}"
      execute :sudo, "echo '#{user} ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/#{user}"
    end
  end

  # Install ImageMagick and libraries
  desc "Install ImageMagick and libraries"
  task :install_imagemagick do
    on roles(fetch(:server_roles)) do
      puts "🖼️ Installing ImageMagick and libraries..."
      execute :sudo, "apt install -y libpng-dev libjpeg-dev libtiff-dev imagemagick"
    end
  end

  # Install PostgreSQL database server
  desc "Install PostgreSQL"
  task :install_postgres do
    on roles(fetch(:server_roles)) do
      puts "🐘 Installing PostgreSQL..."
      execute :sudo, "apt install -y postgresql-common"
      execute :sudo, "bash -c 'echo | /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh'"
      execute :sudo, "apt install -y postgresql libpq-dev"
      execute :sudo, "systemctl enable --now postgresql"
    end
  end

  # Install Nginx web server
  desc "Install Nginx"
  task :install_nginx do
    on roles(fetch(:server_roles)) do
      puts "🕸️ Installing Nginx..."
      execute :sudo, "apt install -y nginx"
      execute :sudo, "systemctl enable --now nginx"
    end
  end

  # Install Redis in-memory database
  desc "Install Redis"
  task :install_redis do
    on roles(fetch(:server_roles)) do
      puts "📂 Installing Redis..."
      execute :sudo, "apt install -y redis-server"
      execute :sudo, "systemctl enable --now redis-server"
    end
  end

  # Install RVM and Ruby
  desc "Install RVM and Ruby"
  task :install_rvm do
    on roles(fetch(:server_roles)) do
      ruby_version = fetch(:srvr_rvm_ruby_version)
      puts "💎 Installing RVM & Ruby #{ruby_version}..."
      execute :sudo, "curl -sSL https://rvm.io/mpapis.asc | gpg --dearmor -o /usr/share/keyrings/rvm.gpg || true"
      execute :sudo, "curl -sSL https://get.rvm.io | bash -s master"
      execute "source /home/#{fetch(:srvr_user)}/.rvm/scripts/rvm && rvm install #{ruby_version} --default"
    end
  end

  # Install NVM and Node.js
  desc "Install NVM and Node.js"
  task :install_nvm do
    on roles(fetch(:server_roles)) do
      node_version = fetch(:srvr_nvm_node_version)
      unless test("[ -d \"$HOME/.nvm\" ]")
        puts "⚙️ Installing NVM & Node.js #{node_version}..."

        # Backup original .bashrc
        execute :cp, "$HOME/.bashrc", "$HOME/bashrc_backup"

        # Install NVM
        execute "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/#{fetch(:srvr_nvm_version)}/install.sh | bash"

        # Create new .bashrc with NVM at the top
        execute "echo '# Load NVM script at the top, so it is available in non-interactive sessions' > $HOME/bashrc_new"
        execute "echo 'export NVM_DIR="$HOME/.nvm"' >> $HOME/bashrc_new"
        execute "echo '[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"' >> $HOME/bashrc_new"
        execute "echo '[ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"' >> $HOME/bashrc_new"
        execute "echo ' ' >> $HOME/bashrc_new"

        # Append the rest of the original .bashrc
        execute "cat $HOME/bashrc_backup >> $HOME/bashrc_new"

        # Replace .bashrc with the new version
        execute :mv, "$HOME/bashrc_new", "$HOME/.bashrc"

        # Clean up backup
        execute "rm -f $HOME/bashrc_backup"

        # Reload bashrc
        execute "bash -c 'source $HOME/.bashrc'"

        # Test if nvm is available
        execute "command -v nvm"

        # Install the desired Node.js version
        execute "nvm install #{node_version} --default"
      else
        puts "✅ NVM is already installed. Skipping installation."
      end
    end
  end

  # Install Thin web server
  desc "Install Thin web server"
  task :install_thin do
    on roles(fetch(:server_roles)) do
      puts "🔥 Installing Thin..."
      execute :sudo, "apt install -y thin"
      thin_version = capture("thin -v").strip
      puts "✅ Thin Version: #{thin_version}"

      # Check if /etc/thin exists
      if test("[ -d /etc/thin ]")
        puts "✅ /etc/thin already exists, skipping symlink creation."
      else
        # Try to find a valid Thin config directory
        thin_path = capture("ls -d /etc/thin* 2>/dev/null || echo ''").strip

        # Ensure a valid path was found before proceeding
        if !thin_path.empty? && thin_path != "/etc/thin"
          puts "🔗 Creating symlink: /etc/thin → #{thin_path}"
          execute :sudo, "ln -sfn #{thin_path} /etc/thin"
        else
          puts "⚠️ No alternative Thin config directory found, skipping symlink."
        end
      end
    end
  end

  # Install Certbot for Let's Encrypt
  desc "Install Certbot"
  task :install_certbot do
    on roles(fetch(:server_roles)) do
      puts "🔒 Installing Certbot..."
      execute :sudo, "apt update"
      execute :sudo, "apt install -y certbot"
    end
  end

  # Configure UFW firewall
  desc "Setup UFW firewall"
  task :setup_firewall do
    on roles(fetch(:server_roles)) do
      if fetch(:srvr_enable_firewall)
        puts "🛡️ Configuring UFW firewall..."
        execute :sudo, "apt install -y ufw"
        execute :sudo, "ufw --force reset"
        execute :sudo, "ufw default deny incoming"
        execute :sudo, "ufw default allow outgoing"
        execute :sudo, "ufw allow OpenSSH"
        execute :sudo, "ufw allow 80"
        execute :sudo, "ufw allow 443"
        fetch(:srvr_ufw_additional_ports, []).each do |port|
          execute :sudo, "ufw allow #{port}"
        end
        execute :sudo, "ufw --force enable"
        puts "✅ UFW enabled!"
      end
    end
  end

  # Ensure GitLab SSH key exists and display it
  desc "Ensure GitLab SSH key exists and display it"
  task :setup_gitlab_key do
    on roles(fetch(:server_roles)) do
      puts "🔑 Checking GitLab SSH Key..."
      unless test("[ -f ~/.ssh/id_rsa.pub ]")
        execute "ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ''"
      end
      output = capture(:cat, '~/.ssh/id_rsa.pub')
      puts " "
      puts "🔍 SSH Key generated! Displaying public key:"
      puts "==========================================="
      puts output
      puts "==========================================="
      puts "🚀 Add it to GitLab under https://gitlab.com/-/user_settings/ssh_keys"
      puts " "
    end
  end

  # Full server setup by invoking all necessary tasks
  # Setup Debian-12 or Ubuntu-24 Server with required dependencies
  desc "Full server setup"
  task :setup do
    invoke "server:update_packages"
    invoke "server:needed_packages"
    invoke "server:create_user"           if fetch(:srvr_create_user)
    invoke "server:install_imagemagick"
    invoke "server:install_postgres"      if fetch(:srvr_install_postgres)
    invoke "server:install_nginx"         if fetch(:srvr_install_nginx)
    invoke "server:install_redis"         if fetch(:srvr_install_redis)
    invoke "server:install_rvm"           if fetch(:srvr_install_rvm)
    invoke "server:install_nvm"           if fetch(:srvr_install_nvm)
    invoke "server:install_thin"          if fetch(:srvr_install_thin)
    invoke "server:install_certbot"       if fetch(:srvr_install_certbot)
    invoke "server:setup_firewall"        if fetch(:srvr_enable_firewall)
    invoke "server:setup_gitlab_key"
    puts "✅ Server setup completed!"
  end
end
