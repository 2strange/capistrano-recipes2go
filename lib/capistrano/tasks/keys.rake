require 'capistrano/recipes2go/base_helpers'
include Capistrano::Recipes2go::BaseHelpers

namespace :load do
  task :defaults do

    ## Wanna use and deploy configuration.yml ?
    set :keys_use_configuration, -> { false }

    append :linked_files, 'config/master.key', 'config/credentials.yml.enc'
    # append :linked_files, 'config/configuration.yml' if fetch(:keys_use_configuration, false)

  end
end

Rake::Task['deploy:starting'].enhance do
  if fetch(:keys_use_configuration)
    append :linked_files, 'config/configuration.yml'
  end
end


namespace :keys do

  def upload_file(file)
    on roles %w{app db web} do
      puts "📤 Syncing: #{file}"
      local_dir = "./config/#{file}"
      remote_dir = "#{host.user}@#{host.hostname}:#{shared_path}/config/#{file}"
      
      # Ensure the config folder exists
      ensure_shared_config_path()

      run_locally { execute "rsync -av --delete #{local_dir} #{remote_dir}" }
    end
  end

  desc "Upload master.key & credentials.yml.enc"
  task :upload_master do
    %w(master.key credentials.yml.enc).each { |file| upload_file(file) }
  end

  desc "Upload configuration.yml (if enabled)"
  task :upload_config do
    upload_file("configuration.yml") if fetch(:keys_use_configuration, false)
  end

  desc "Check if required Rails keys exist"
  task :check_keys do
    on roles(:app) do
      %w(master.key credentials.yml.enc configuration.yml).each do |file|
        next unless fetch(:keys_use_configuration, false) || file != "configuration.yml"
        unless test("[ -s #{shared_path}/config/#{file} ]")
          puts "⚠️  WARNING: #{file} is empty or missing! Upload it manually."
        end
      end
    end
  end

  desc "Check config directory on server"
  task :check_config do
    on roles %w{app db web} do
      execute :ls, "-al", "#{shared_path}/config/"
    end
  end

  desc 'Setup Rails credentials and config files'
  task :setup do
    puts "* ===== KEYS Setup ===== *"
    invoke 'keys:upload_master'
    invoke 'keys:upload_config' if fetch(:keys_use_configuration, false)
  end
end

### Add keys:setup to the main setup task
task :setup do
  invoke 'keys:setup'
end


namespace :deploy do
  before :starting, :update_config do
    on roles %w{app db web} do
      invoke 'keys:upload_config' if fetch(:keys_use_configuration, false)
    end
  end
end