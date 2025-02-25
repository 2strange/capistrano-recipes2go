namespace :server do
  desc "Setup the server with all required dependencies"
  task :setup do
    on roles(:web) do
      deploy_user = fetch(:deploy_user, "deploy")

      # 1️⃣ Frage interaktiv ab, was installiert werden soll
      install_nginx = fetch(:install_nginx, true)
      install_postgres = fetch(:install_postgres, true)
      install_certbot = fetch(:install_certbot, true)
      install_rsync = fetch(:install_rsync, true)

      # 2️⃣ Erstelle den Deploy-User
      execute :sudo, "adduser --disabled-password --gecos '' #{deploy_user} || true"
      execute :sudo, "usermod -aG sudo #{deploy_user}"
      execute :sudo, "echo '#{deploy_user} ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/#{deploy_user}"

      # 3️⃣ SSH-Schlüssel für den Deploy-User hinzufügen
      execute "mkdir -p ~/.ssh"
      execute "touch ~/.ssh/authorized_keys"
      execute "chmod 700 ~/.ssh"
      execute "chmod 600 ~/.ssh/authorized_keys"

      # 4️⃣ Installiere notwendige Pakete
      execute :sudo, "apt update -y"
      execute :sudo, "apt install -y build-essential curl git unzip zlib1g-dev"

      execute :sudo, "apt install -y nginx" if install_nginx
      execute :sudo, "apt install -y postgresql libpq-dev" if install_postgres
      execute :sudo, "apt install -y certbot python3-certbot-nginx" if install_certbot
      execute :sudo, "apt install -y rsync" if install_rsync

      # 5️⃣ Setze Firewall-Regeln für Nginx
      if install_nginx
        execute :sudo, "ufw allow OpenSSH"
        execute :sudo, "ufw allow 'Nginx Full'"
        execute :sudo, "ufw enable"
      end

      puts "✅ Server-Setup abgeschlossen!"
    end
  end
end
