namespace :load do
  task :defaults do
    set :nvm_version, -> { 'v0.39.7' }  # Change for newer versions
    set :nvm_install_path, -> { "$HOME/.nvm" }
    set :node_version, -> { '23' }  # Default Node.js version
    set :nvm_roles, -> { :app }
  end
end

namespace :nvm do

  desc "Install NVM (Node Version Manager) if not already installed"
  task :install do
    on roles fetch(:nvm_roles) do
      unless test("[ -d #{fetch(:nvm_install_path)} ]")
        execute "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/#{fetch(:nvm_version)}/install.sh | bash"
      else
        puts "✅ NVM is already installed, skipping."
      end
    end
  end

  desc "Install Node.js if not already installed"
  task :install_node do
    on roles fetch(:nvm_roles) do
      unless test("source #{fetch(:nvm_install_path)}/nvm.sh && nvm which #{fetch(:node_version)}")
        execute "source #{fetch(:nvm_install_path)}/nvm.sh && nvm install #{fetch(:node_version)}"
      else
        puts "✅ Node.js #{fetch(:node_version)} is already installed, skipping."
      end
    end
  end

  desc "List installed Node.js versions"
  task :list_installed do
    on roles fetch(:nvm_roles) do
      execute "source #{fetch(:nvm_install_path)}/nvm.sh && nvm list"
    end
  end

  desc "List all available Node.js versions"
  task :list_available do
    on roles fetch(:nvm_roles) do
      execute "source #{fetch(:nvm_install_path)}/nvm.sh && nvm ls-remote"
    end
  end

  desc "Set default Node.js version"
  task :use do
    on roles fetch(:nvm_roles) do
      execute "source #{fetch(:nvm_install_path)}/nvm.sh && nvm alias default #{fetch(:node_version)}"
    end
  end
end

namespace :setup do
  desc "Setup NVM and Node.js (only needed once)"
  task :prepare do
    invoke "nvm:install"
    invoke "nvm:install_node"
    invoke "nvm:use"
    puts "✅ NVM & Node.js setup complete!"
  end
end
