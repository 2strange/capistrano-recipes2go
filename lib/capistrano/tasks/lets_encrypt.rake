namespace :load do
  task :defaults do
    set :certbot_roles,         -> { :web }
    set :certbot_path,          -> { "~" }
    set :certbot_domains,       -> { fetch(:nginx_major_domain,false) ? [fetch(:nginx_major_domain)] + Array(fetch(:nginx_domains)) : Array(fetch(:nginx_domains)) }
    set :certbot_www_domains,   -> { false }
    set :certbot_job_log,       -> { "#{shared_path}/log/lets_encrypt_cron.log" }
    set :certbot_job_type,      -> { 'systemd' }  # systemd / cron
    set :certbot_email,         -> { "ssl@example.com" }
    set :certbot_dh_path,       -> { fetch(:nginx_diffie_hellman_path, "/etc/ssl/certs/dhparam.pem")}
    set :certbot_snap,          -> { false }
  end
end

namespace :certbot do
  
  desc "Install certbot LetsEncrypt"
  task :install do
    on release_roles fetch(:certbot_roles) do
      within fetch(:certbot_path) do
        if fetch(:certbot_snap, false)
          execute :sudo, "apt update"
          execute :sudo, "apt install -y snapd"
          execute :sudo, "snap install core"
          execute :sudo, "snap refresh core"
          execute :sudo, "snap install --classic certbot"
          execute :sudo, "ln -s /snap/bin/certbot /usr/bin/certbot"
          execute :sudo, "snap set certbot trust-plugin-with-root=ok"
        else
          execute :sudo, "apt update"
          execute :sudo, "apt install -y certbot"
        end
      end
    end
  end
  
  
  desc "Generate LetsEncrypt certificate"
  task :generate do
    on release_roles fetch(:certbot_roles) do
      # 1️⃣ E-Mail-Check mit Erklärung
      certbot_email = fetch(:certbot_email, "").strip
      if certbot_email.empty?
        puts "⚠️  Es ist keine E-Mail-Adresse für Let's Encrypt hinterlegt!"
        puts "➡️  Diese ist erforderlich, um Benachrichtigungen über ablaufende Zertifikate zu erhalten."
        puts "➡️  Bitte gib eine gültige E-Mail-Adresse ein:"
        certbot_email = ask(:certbot_email, "E-Mail für Let's Encrypt:")
        set(:certbot_email, certbot_email)
      end

      # 2️⃣ Domain-Check für `--expand`
      certbot_domains = Array(fetch(:certbot_domains))
      use_www_domains = fetch(:certbot_www_domains, false)

      should_expand = false

      # Falls eine Major-Domain existiert oder mehrere Domains angegeben wurden, nachfragen
      if use_www_domains || certbot_domains.length > 1
        puts "🔍  Es scheint, dass du bereits Zertifikate hast oder neue Domains hinzufügen möchtest."
        puts "➡️  Falls du bestehende Zertifikate um neue Domains erweitern möchtest, wähle 'ja'."
        should_expand = ask(:certbot_expand, "Soll `--expand` genutzt werden? (ja/nein)").downcase.strip == "ja"
      end

      expand_option = should_expand ? "--expand" : ""

      # 3️⃣ Certbot-Befehl mit den Domains generieren
      domain_args = certbot_domains.map do |d|
        base_domain = d.gsub(/^\*?\./, "")
        domain_entry = "-d #{base_domain}"
        domain_entry += " -d www.#{base_domain}" if use_www_domains
        domain_entry
      end.join(" ")

      # 4️⃣ Certbot ausführen
      execute :sudo, "certbot --non-interactive --agree-tos --allow-subset-of-names --email #{certbot_email} certonly --webroot -w #{current_path}/public #{domain_args} #{expand_option}"
    end
  end
  
  
  desc "Upload and setup LetsEncrypt Auto-renew-job"
  task :setup_auto_renew do
    on release_roles fetch(:certbot_roles) do
      if fetch(:certbot_job_type, 'systemd') == 'cron'
        # just once a week
        execute :sudo, "echo '0 0 * * 0 root certbot renew --no-self-upgrade --allow-subset-of-names --post-hook \"#{fetch(:nginx_service_path)} restart\"  >> #{ fetch(:certbot_job_log) } 2>&1' | cat > #{ fetch(:certbot_path) }/lets_encrypt_cronjob"
        execute :sudo, "mv -f #{ fetch(:certbot_path) }/lets_encrypt_cronjob /etc/cron.d/lets_encrypt"
        execute :sudo, "chown -f root:root /etc/cron.d/lets_encrypt"
        execute :sudo, "chmod -f 0644 /etc/cron.d/lets_encrypt"
      else
        ## enable systemd timer (every 12 hours)
        execute :sudo, "systemctl enable certbot.timer"
        execute :sudo, "systemctl start certbot.timer"
        ## restart nginx if renewed
        execute :sudo, "mkdir -p /etc/systemd/system/certbot.service.d"
        execute :sudo, "echo -e '[Service]\nExecStartPost=/bin/systemctl restart nginx' | sudo tee /etc/systemd/system/certbot.service.d/override.conf"
        execute :sudo, "systemctl daemon-reload"
      end
    end
  end
  
  desc "Show logs for LetsEncrypt Auto-renew-job"
  task :auto_renew_logs do
    on release_roles fetch(:certbot_roles) do
      if fetch(:certbot_job_type, 'systemd') == 'cron'
        execute :sudo, "tail -n 50 #{fetch(:certbot_job_log)}"
      else
        execute :sudo, "journalctl -u certbot.timer --no-pager --since '7 days ago'"
        execute :sudo, "journalctl -u certbot.service --no-pager --since '7 days ago'"
      end
    end
  end
  
  desc "Remove LetsEncrypt Auto-renew-job"
  task :remove_auto_renew do
    on release_roles fetch(:certbot_roles) do
      if fetch(:certbot_job_type, 'systemd') == 'cron'
        execute :sudo, "rm -f /etc/cron.d/lets_encrypt"
      else
        execute :sudo, "systemctl stop certbot.timer"
        execute :sudo, "systemctl disable certbot.timer"
        execute :sudo, "rm -rf /etc/systemd/system/certbot.service.d"
        execute :sudo, "systemctl daemon-reload"
      end
    end
  end
  
  
  desc "Dry-Run Renew LetsEncrypt"
  task :dry_renew do
    on release_roles fetch(:certbot_roles) do
      # execute :sudo, "#{ fetch(:certbot_path) }/certbot-auto renew --dry-run"
      output = capture(:sudo, "certbot renew --dry-run")
      puts "#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#"
      output.each_line do |line|
          puts line
      end
      puts "#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#"
    end
  end
  
  
  desc "Generate Strong Diffie-Hellman Group"
  task :generate_dhparam do
    on release_roles fetch(:certbot_roles) do
      dh_path = fetch(:certbot_dh_path).to_s.split("/")
      dh_path.pop
      execute :sudo, "mkdir -p #{ dh_path.join("/") }"
      execute :sudo, "openssl dhparam -out #{ fetch(:certbot_dh_path) } 2048"
    end
  end
  
  
  

  
end



