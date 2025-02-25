namespace :server do
  desc "Setup Debian 12 Server with required dependencies"
  task :setup do
    on roles(:web) do
      deploy_user = fetch(:deploy_user, "deploy")

      puts "🚀 Server-Setup für Capistrano-Deployments beginnt..."
      
      # 1️⃣ System aktualisieren
      puts "📦 System aktualisieren..."
      execute :sudo, "apt update -y && apt upgrade -y"
      execute :sudo, "apt install -y build-essential bison curl git-core git rsync"

      # 2️⃣ ImagMagick & Libraries installieren
      puts "🖼️ Installiere ImageMagick und benötigte Bibliotheken..."
      execute :sudo, "apt install -y libpng-dev libjpeg-dev libtiff-dev imagemagick"

      # 3️⃣ PostgreSQL installieren
      puts "🐘 Installiere PostgreSQL..."
      execute :sudo, "apt install -y postgresql-common"
      execute :sudo, "/usr/share/postgresql-common/pgdg/apt.postgresql.org.sh"
      execute :sudo, "apt install -y postgresql libpq-dev"
      execute :sudo, "systemctl restart postgresql"
      execute :sudo, "systemctl enable postgresql"

      # 4️⃣ RVM & Ruby installieren
      puts "💎 Installiere RVM und Ruby..."
      execute :sudo, "gpg --keyserver keyserver.ubuntu.com --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB"
      execute :sudo, "curl -sSL https://get.rvm.io | bash -s master"
      execute "source /home/#{deploy_user}/.rvm/scripts/rvm"
      execute "echo 'gem: --no-rdoc --no-ri' >> ~/.gemrc"
      execute "rvm install 3.3.5"
      
      # 5️⃣ Nginx installieren und aktivieren
      puts "🕸️ Installiere und konfiguriere Nginx..."
      execute :sudo, "apt update -y"
      execute :sudo, "apt install -y nginx"
      execute :sudo, "systemctl enable nginx"
      execute :sudo, "systemctl start nginx"

      # 6️⃣ Redis installieren
      puts "📂 Installiere Redis..."
      execute :sudo, "apt install -y redis-server"
      execute :sudo, "systemctl enable redis-server"
      execute :sudo, "systemctl start redis"

      # 7️⃣ SSH-Key für GitLab generieren (Falls noch nicht vorhanden)
      puts "🔑 Überprüfe GitLab SSH-Key..."
      if test("[ ! -f ~/.ssh/id_rsa.pub ]")
        execute "ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ''"
        execute "cat ~/.ssh/id_rsa.pub"
        puts "🚀 SSH-Key generiert! Füge ihn in GitLab unter https://gitlab.com/-/user_settings/ssh_keys hinzu."
      end

      # 8️⃣ Thin Webserver installieren
      puts "🔥 Installiere Thin..."
      execute :sudo, "apt install -y thin"

      # 9️⃣ Node.js & NVM installieren
      puts "⚙️ Installiere NVM und Node.js..."
      execute "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash"
      execute "export NVM_DIR=\"$HOME/.nvm\" && source \"$NVM_DIR/nvm.sh\""
      execute "nvm install 18"

      puts "✅ Server-Setup abgeschlossen!"
    end
  end
end
