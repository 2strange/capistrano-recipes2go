namespace :load do
  task :defaults do
    # Default user for deployment, uses `fetch(:user, "deploy")` if not explicitly set
    set :srvr_user,                 -> { fetch(:user, "deploy") }
    
    # Whether to create the deploy user if it does not exist
    set :srvr_create_user,          -> { false }

    # Ruby version and RVM installation
    set :srvr_install_nvm,          -> { true }
    set :srvr_rvm_ruby_version,     -> { fetch(:rvm_ruby_version, "3.3.5") }

    # Node.js version and NVM installation
    set :srvr_install_nvm,          -> { true }
    set :srvr_nvm_node_version,     -> { "23" }

    # Install core services
    set :srvr_install_nginx,        -> { true }
    set :srvr_install_postgres,     -> { true }
    set :srvr_install_certbot,      -> { true }
    set :srvr_install_redis,        -> { true }
    set :srvr_install_thin,         -> { true }

    # Enable firewall and allow additional ports
    set :srvr_enable_firewall,      -> { true }
    set :srvr_ufw_additional_ports, -> { fetch(:ufw_additional_ports, []) } # Example: ["2224", "8080"]
  end
end

namespace :server do
  desc "Setup Debian-12 or Ubuntu-24 Server with required dependencies"
  task :setup do
    on roles(:web) do
      user = fetch(:srvr_user)
      create_user = fetch(:srvr_create_user)

      install_rvm = fetch(:srvr_install_rvm)
      rvm_ruby_version = fetch(:srvr_rvm_ruby_version)
      install_nvm = fetch(:srvr_install_nvm)
      nvm_node_version = fetch(:srvr_nvm_node_version)

      install_nginx = fetch(:srvr_install_nginx)
      install_postgres = fetch(:srvr_install_postgres)
      install_certbot = fetch(:srvr_install_certbot)
      install_redis = fetch(:srvr_install_redis)
      install_thin = fetch(:srvr_install_thin)

      enable_firewall = fetch(:srvr_enable_firewall)
      ufw_additional_ports = fetch(:srvr_ufw_additional_ports)

      puts "🚀 Starting server setup..."

      # Update and upgrade system packages
      execute :sudo, "apt update -y"
      execute :sudo, "apt upgrade -y"
      execute :sudo, "apt install -y build-essential bison curl git-core git rsync"

      # Create the deploy user if not already existing and required
      if create_user
        puts "👤 Creating deploy user '#{user}' if not present..."
        execute :sudo, "id #{user} || adduser --disabled-password --gecos '' #{user}"
        execute :sudo, "usermod -aG sudo #{user}"
        execute :sudo, "echo '#{user} ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/#{user}"
      end

      # Install ImageMagick and required libraries
      puts "🖼️ Installing ImageMagick and libraries..."
      execute :sudo, "apt install -y libpng-dev libjpeg-dev libtiff-dev imagemagick"

      # Install PostgreSQL database server
      if install_postgres
        puts "🐘 Installing PostgreSQL..."
        execute :sudo, "apt install -y postgresql-common"
        execute :sudo, "bash -c 'echo | /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh'"
        execute :sudo, "apt install -y postgresql libpq-dev"
        execute :sudo, "systemctl enable --now postgresql"
      end

      # Install Nginx web server
      if install_nginx
        puts "🕸️ Installing Nginx..."
        execute :sudo, "apt install -y nginx"
        execute :sudo, "systemctl enable --now nginx"
      end

      # Install Redis in-memory database
      if install_redis
        puts "📂 Installing Redis..."
        execute :sudo, "apt install -y redis-server"
        execute :sudo, "systemctl enable --now redis-server"
      end

      # Install Thin web server
      if install_thin
        puts "🔥 Installing Thin..."
        execute :sudo, "apt install -y thin"
        thin_version = capture("thin -v").strip
        puts "✅ Thin Version: #{thin_version}"

        # Create a symlink to /etc/thin if necessary
        thin_path = capture("ls -d /etc/thin* 2>/dev/null || echo ''").strip
        if !thin_path.empty? && thin_path != "/etc/thin"
          execute :sudo, "ln -sfn #{thin_path} /etc/thin"
          puts "🔗 Symlink created: /etc/thin → #{thin_path}"
        end
      end

      # Install RVM and the specified Ruby version
      if install_rvm
        puts "💎 Installing RVM & Ruby #{rvm_ruby_version}..."
        execute :sudo, "gpg --keyserver keyserver.ubuntu.com --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB"
        execute :sudo, "curl -sSL https://get.rvm.io | bash -s master"
        execute "source /home/#{user}/.rvm/scripts/rvm"
        execute "rvm install #{rvm_ruby_version} --default"
      end

      # Install NVM and Node.js
      if install_nvm
        puts "⚙️ Installing NVM & Node.js #{nvm_node_version}..."
        execute "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash"
        execute "export NVM_DIR=\"$HOME/.nvm\" && source \"$NVM_DIR/nvm.sh\""
        execute "nvm install #{nvm_node_version} --default"
      end

      # Install Certbot for Let's Encrypt
      if install_certbot
        puts "🔒 Installing Certbot..."
        execute :sudo, "apt update"
        execute :sudo, "apt install -y certbot"
      end

      # Configure UFW firewall
      if enable_firewall
        if test("[ -z \"$(command -v ufw)\" ]")
          puts "🔄 Installing UFW..."
          execute :sudo, "apt update && apt install -y ufw"
        end
        puts "🛡️ Configuring UFW firewall..."
        execute :sudo, "ufw allow OpenSSH"
        # execute :sudo, "ufw allow 'Nginx Full'" if install_nginx
        execute :sudo, "ufw allow 80"   # HTTP
        execute :sudo, "ufw allow 443"  # HTTPS
        ufw_additional_ports.each do |port|
          execute :sudo, "ufw allow #{port}"
        end
        execute :sudo, "ufw --force enable"
        puts "✅ UFW enabled!"
      end

      # Display GitLab SSH key at the end so the user sees it
      puts "🔑 Checking GitLab SSH Key..."
      if test("[ ! -f ~/.ssh/id_rsa.pub ]")
        execute "ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ''"
        puts "🔍 SSH Key generated! Displaying public key:"
        puts "==========================================="
        execute "cat ~/.ssh/id_rsa.pub"
        puts "==========================================="
        puts "🚀 Add it to GitLab under https://gitlab.com/-/user_settings/ssh_keys"
      end

      puts "✅ Server setup completed!"
    end
  end
end
