namespace :load do
  task :defaults do
    
    ## Wanna use and deploy configuration.yml ?
    set :keys_use_configuration, false
    
  end
end


namespace :keys do
  
    desc "upload master.key & credentials.yml.enc to #{ fetch(:application) } - #{fetch(:stage)}"
    task :upload_master do
      on roles %w{app db web} do
        %w(master.key credentials.yml.enc).each do |that|
          puts "syncing: #{that}"
          local_dir = "./config/#{ that }"
          remote_dir = "#{host.user}@#{host.hostname}:#{shared_path}/config/#{ that }"
          run_locally { execute "rsync -av --delete #{local_dir} #{remote_dir}" }
        end
      end
    end

    desc "upload configuration.yml to server #{ fetch(:application) } - #{fetch(:stage)}"
    task :upload_config do
      on roles %w{app db web} do
        that = 'configuration.yml' 
        puts "syncing: #{that}"
        local_dir = "./config/#{ that }"
        remote_dir = "#{host.user}@#{host.hostname}:#{shared_path}/config/#{ that }"
        run_locally { execute "rsync -av --delete #{local_dir} #{remote_dir}" }
      end
    end

    desc "check »config« dir on server #{ fetch(:application) } - #{fetch(:stage)}"
    task :check_config do
      on roles %w{app db web} do
        within shared_path do
            execute :ls, "-al config/"
        end
      end
    end
    
    
    desc 'App - KEYs setup tasks'
    task :setup do
      puts "* ===== KEYS Setup ===== *\n"
      puts " Upload:  master.key  &  credentials.yml.enc"
      invoke 'keys:upload_master'
      if fetch(:keys_use_configuration, false)
        puts " Upload:  configuration.yml"
      end
    end
    
    
    
    task :symlink_secrets_and_config do
      append :linked_files, 'config/master.key', 'config/credentials.yml.enc'
      append :linked_files, 'config/configuration.yml'  if fetch(:keys_use_configuration, false)
    end

    after 'deploy:started', ':keys::symlink_secrets_and_config'
    
    
end


desc 'Server setup tasks'
task :setup do
  invoke 'keys:setup'
end
