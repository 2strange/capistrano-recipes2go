namespace :server do
  desc "Setup Debian 12 Server with required dependencies"
  task :setup do
    on roles(:web) do
      deploy_user = fetch(:deploy_user, "deploy")
      use_rvm = fetch(:use_rvm, true)
      rvm_ruby_version = fetch(:rvm_ruby_version, "3.3.5")
      use_nvm = fetch(:use_nvm, true)
      nvm_node_version = fetch(:nvm_node_version, "18")

      install_nginx = fetch(:install_nginx, true)
      install_postgres = fetch(:install_postgres, true)
      install_certbot = fetch(:install_certbot, true)
      install_redis = fetch(:install_redis, true)
      install_thin = fetch(:install_thin, true)

      puts "🚀 Server-Setup für Capistrano-Deployments beginnt..."
      
      # 1️⃣ System aktualisieren
      puts "📦 System aktualisieren..."
      execute :sudo, "apt update -y && apt upgrade -y"
      execute :sudo, "apt install -y build-essential bison curl git-core git rsync"

      # 2️⃣ ImagMagick & Libraries installieren
      puts "🖼️ Installiere ImageMagick und benötigte Bibliotheken..."
      execute :sudo, "apt install -y libpng-dev libjpeg-dev libtiff-dev imagemagick"

      # 3️⃣ PostgreSQL installieren (falls gewünscht)
      if install_postgres
        puts "🐘 Installiere PostgreSQL..."
        execute :sudo, "apt install -y postgresql-common"
        execute :sudo, "/usr/share/postgresql-common/pgdg/apt.postgresql.org.sh"
        execute :sudo, "apt install -y postgresql libpq-dev"
        execute :sudo, "systemctl restart postgresql"
        execute :sudo, "systemctl enable postgresql"
      end

      # 4️⃣ RVM & Ruby installieren (falls gewünscht)
      if use_rvm
        puts "💎 Installiere RVM und Ruby #{rvm_ruby_version}..."
        execute :sudo, "gpg --keyserver keyserver.ubuntu.com --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB"
        execute :sudo, "curl -sSL https://get.rvm.io | bash -s master"
        execute "source /home/#{deploy_user}/.rvm/scripts/rvm"
        execute "echo 'gem: --no-rdoc --no-ri' >> ~/.gemrc"
        execute "rvm install #{rvm_ruby_version}"
        execute "rvm use #{rvm_ruby_version} --default"
      end
      
      # 5️⃣ Nginx installieren und aktivieren (falls gewünscht)
      if install_nginx
        puts "🕸️ Installiere und konfiguriere Nginx..."
        execute :sudo, "apt install -y nginx"
        execute :sudo, "systemctl enable nginx"
        execute :sudo, "systemctl start nginx"
      end

      # 6️⃣ Redis installieren (falls gewünscht)
      if install_redis
        puts "📂 Installiere Redis..."
        execute :sudo, "apt install -y redis-server"
        execute :sudo, "systemctl enable redis-server"
        execute :sudo, "systemctl start redis"
      end

      # 7️⃣ SSH-Key für GitLab generieren (Falls noch nicht vorhanden)
      puts "🔑 Überprüfe GitLab SSH-Key..."
      if test("[ ! -f ~/.ssh/id_rsa.pub ]")
        execute "ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ''"
        execute "cat ~/.ssh/id_rsa.pub"
        puts "🚀 SSH-Key generiert! Füge ihn in GitLab unter https://gitlab.com/-/user_settings/ssh_keys hinzu."
      end

      # 8️⃣ Thin Webserver installieren (falls gewünscht)
      if install_thin
        puts "🔥 Installiere Thin..."
        execute :sudo, "apt install -y thin"
      end

      # 9️⃣ Node.js & NVM installieren (falls gewünscht)
      if use_nvm
        puts "⚙️ Installiere NVM und Node.js #{nvm_node_version}..."
        execute "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash"
        execute "export NVM_DIR=\"$HOME/.nvm\" && source \"$NVM_DIR/nvm.sh\""
        execute "nvm install #{nvm_node_version}"
        execute "nvm use #{nvm_node_version} --default"
      end

      puts "✅ Server-Setup abgeschlossen!"
    end
  end
end
