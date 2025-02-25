namespace :load do
  task :defaults do
    
    set :ufw_ssh_port,          -> { 22 }   # Default SSH port (can be overridden)
    set :ufw_additional_ports,  -> { [] }   # More ports to open (ie. 2224 for nydas worker)
    
  end
end

namespace :ufw do
  desc "Install UFW if not present"
  task :install do
    on roles(:web) do
      if test("[ -z \"$(command -v ufw)\" ]")
        puts "🔄 Installing UFW..."
        execute :sudo, "apt update && apt install -y ufw"
      else
        puts "✅ UFW is already installed."
      end
    end
  end

  desc "Setup UFW rules and enable firewall"
  task :setup do
    on roles(:web) do
      # Get ports from variables, fallback to defaults
      ssh_port = fetch(:ufw_ssh_port, 22)
      default_ports = [80, 443, ssh_port]
      additional_ports = fetch(:ufw_additional_ports, []) # New variable for extra ports

      all_ports = default_ports + additional_ports

      puts "🔧 Configuring UFW..."
      execute :sudo, "ufw --force reset"
      execute :sudo, "ufw default deny incoming"
      execute :sudo, "ufw default allow outgoing"

      all_ports.each do |port|
        puts "🔓 Allowing port #{port}"
        execute :sudo, "ufw allow #{port}"
      end

      puts "🚀 Enabling UFW..."
      execute :sudo, "ufw --force enable"
    end
  end

  desc "Disable UFW"
  task :disable do
    on roles(:web) do
      puts "⛔ Disabling UFW..."
      execute :sudo, "ufw disable"
    end
  end

  desc "Check UFW status"
  task :status do
    on roles(:web) do
      puts "📊 Checking UFW status..."
      execute :sudo, "ufw status verbose"
    end
  end

  desc "Show active UFW rules"
  task :rules do
    on roles(:web) do
      puts "📜 Listing all active UFW rules..."
      execute :sudo, "ufw show added"
    end
  end
end
