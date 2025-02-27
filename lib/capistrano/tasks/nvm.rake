namespace :load do
  task :defaults do
    set :nvm_roles,         -> { :app }
    set :nvm_install_path,  -> { "$HOME/.nvm" }

    set :nvm_version,       -> { 'v0.39.7' }  # Change for newer versions
    set :nvm_node_version,  -> { '23' }  # Default Node.js version
  end
end

namespace :nvm do

  desc "Install NVM (Node Version Manager) if not already installed"
  task :install do
    on roles fetch(:nvm_roles) do
      unless test("[ -d #{fetch(:nvm_install_path)} ]")
        # Backup original .bashrc
        execute :cp, "$HOME/.bashrc", "$HOME/bashrc_backup"

        # Install NVM
        execute "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/#{fetch(:nvm_version)}/install.sh | bash"

        # Create new .bashrc with NVM at the top
        execute "echo '# Load NVM script at the top, so it is available in non-interactiv sessions' > $HOME/bashrc_new"
        execute "echo 'export NVM_DIR=\"$HOME/.nvm\"' >> $HOME/bashrc_new"
        execute "echo '[ -s \"$NVM_DIR/nvm.sh\" ] && . \"$NVM_DIR/nvm.sh\"' >> $HOME/bashrc_new"
        execute "echo '[ -s \"$NVM_DIR/bash_completion\" ] && . \"$NVM_DIR/bash_completion\"' >> $HOME/bashrc_new"
        execute "echo ' ' >> $HOME/bashrc_new"

        # Append the rest of the original .bashrc
        execute "cat $HOME/bashrc_backup >> $HOME/bashrc_new"

        # Replace .bashrc with the new version
        execute :mv, "$HOME/bashrc_new", "$HOME/.bashrc"

        # Clean up backup
        execute "rm -f $HOME/bashrc_backup"

        # Reload bashrc
        execute "bash -c 'source $HOME/.bashrc'"
      else
        puts "✅ NVM is already installed, skipping."
      end
    end
  end

  desc "Install Node.js if not already installed"
  task :install_node do
    on roles fetch(:nvm_roles) do
      unless test("source #{fetch(:nvm_install_path)}/nvm.sh && nvm which #{fetch(:nvm_node_version)}")
        execute "source #{fetch(:nvm_install_path)}/nvm.sh && nvm install #{fetch(:nvm_node_version)}"
      else
        puts "✅ Node.js #{fetch(:nvm_node_version)} is already installed, skipping."
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
      execute "source #{fetch(:nvm_install_path)}/nvm.sh && nvm alias default #{fetch(:nvm_node_version)}"
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
