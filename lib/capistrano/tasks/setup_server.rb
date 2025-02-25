namespace :load do
  task :defaults do
    set :srvr_user, -> { fetch(:user, "deploy") }
    set :srvr_create_user, false

    set :srvr_use_rvm, true
    set :srvr_rvm_ruby_version, "3.3.5"

    set :srvr_use_nvm, true
    set :srvr_nvm_node_version, "18"

    set :srvr_install_nginx, true
    set :srvr_install_postgres, true
    set :srvr_install_certbot, true
    set :srvr_install_redis, true
    set :srvr_install_thin, true

    set :srvr_enable_firewall, true
    set :srvr_ufw_additional_ports, []
  end
end

namespace :server do
  desc "Setup Debian 12 or Ubuntu 24.04 Server with required dependencies"
  task :setup do
    on roles(:web) do
      user = fetch(:srvr_user)
      create_user = fetch(:srvr_create_user)

      use_rvm = fetch(:srvr_use_rvm)
      rvm_ruby_version = fetch(:srvr_rvm_ruby_version)
      use_nvm = fetch(:srvr_use_nvm)
      nvm_node_version = fetch(:srvr_nvm_node_version)

      install_nginx = fetch(:srvr_install_nginx)
      install_postgres = fetch(:srvr_install_postgres)
      install_certbot = fetch(:srvr_install_certbot)
      install_redis = fetch(:srvr_install_redis)
      install_thin = fetch(:srvr_install_thin)

      enable_firewall = fetch(:srvr_enable_firewall)
      ufw_additional_ports = fetch(:srvr_ufw_additional_ports)

      puts "🚀 Starte Server-Setup..."

      execute :sudo, "apt update -y && apt upgrade -y"
      execute :sudo, "apt install -y build-essential bison curl git-core git rsync"

      if create_user
        puts "👤 Erstelle Deploy-User '#{user}' falls nicht vorhanden..."
        execute :sudo, "id #{user} || adduser --disabled-password --gecos '' #{user}"
        execute :sudo, "usermod -aG sudo #{user}"
        execute :sudo, "echo '#{user} ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/#{user}"
      end

      puts "🖼️ Installiere ImageMagick..."
      execute :sudo, "apt install -y libpng-dev libjpeg-dev libtiff-dev imagemagick"

      if install_postgres
        puts "🐘 Installiere PostgreSQL..."
        execute :sudo, "apt install -y postgresql-common"
        execute :sudo, "/usr/share/postgresql-common/pgdg/apt.postgresql.org.sh"
        execute :sudo, "apt install -y postgresql libpq-dev"
        execute :sudo, "systemctl enable --now postgresql"
      end

      if install_nginx
        puts "🕸️ Installiere Nginx..."
        execute :sudo, "apt install -y nginx"
        execute :sudo, "systemctl enable --now nginx"
      end

      if install_redis
        puts "📂 Installiere Redis..."
        execute :sudo, "apt install -y redis-server"
        execute :sudo, "systemctl enable --now redis-server"
      end

      if install_thin
        puts "🔥 Installiere Thin..."
        execute :sudo, "apt install -y thin"
        thin_version = capture("thin -v").strip
        puts "✅ Thin Version: #{thin_version}"

        thin_path = capture("ls -d /etc/thin* 2>/dev/null || echo ''").strip
        if !thin_path.empty? && thin_path != "/etc/thin"
          execute :sudo, "ln -sfn #{thin_path} /etc/thin"
          puts "🔗 Symlink erstellt: /etc/thin → #{thin_path}"
        end
      end

      if use_rvm
        puts "💎 Installiere RVM & Ruby #{rvm_ruby_version}..."
        execute :sudo, "gpg --keyserver keyserver.ubuntu.com --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB"
        execute :sudo, "curl -sSL https://get.rvm.io | bash -s master"
        execute "source /home/#{user}/.rvm/scripts/rvm"
        execute "rvm install #{rvm_ruby_version} --default"
      end

      if use_nvm
        puts "⚙️ Installiere NVM & Node.js #{nvm_node_version}..."
        execute "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash"
        execute "export NVM_DIR=\"$HOME/.nvm\" && source \"$NVM_DIR/nvm.sh\""
        execute "nvm install #{nvm_node_version} --default"
      end

      if enable_firewall
        puts "🛡️ Konfiguriere Firewall..."
        execute :sudo, "ufw allow OpenSSH"
        execute :sudo, "ufw allow 'Nginx Full'" if install_nginx
        ufw_additional_ports.each do |port|
          execute :sudo, "ufw allow #{port}"
        end
        execute :sudo, "ufw --force enable"
        puts "✅ UFW aktiviert!"
      end

      puts "🔑 Überprüfe GitLab SSH-Key..."
      if test("[ ! -f ~/.ssh/id_rsa.pub ]")
        execute "ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ''"
        execute "cat ~/.ssh/id_rsa.pub"
        puts "🚀 SSH-Key generiert! Füge ihn in GitLab unter https://gitlab.com/-/user_settings/ssh_keys hinzu."
      end

      puts "✅ Server-Setup abgeschlossen!"
    end
  end
end
