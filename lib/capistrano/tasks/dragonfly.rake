require 'capistrano/recipes2go/base_helpers'
include Capistrano::Recipes2go::BaseHelpers



namespace :load do
  task :defaults do
    
    set :backup_attachment_roles,       -> { :web }
    set :backup_attachment_name,        -> { 'dragonfly' }
    set :backup_attachment_user,        -> { fetch(:user, 'deploy') } # Default user for backup operations
    set :backup_attachment_host,        -> { "#{server.hostname}" } # Default host for backup operations
    set :backup_attachment_remote_path, -> { "#{shared_path}/public/system/dragonfly/live" }
    set :backup_attachment_local_path,  -> { "backups/#{ fetch(:backup_attachment_name) }/#{ fetch(:stage) }" }
    set :backup_attachment_rsync_path, -> { "#{fetch(:backup_attachment_user)}@#{fetch(:backup_attachment_host)}:#{fetch(:backup_attachment_remote_path)}" }
    
  end
end



namespace :dragonfly do

  desc "download attachment files from server"
  task :get_attachments do
    on roles fetch(:backup_attachment_roles) do
      run_locally do
        execute :mkdir, "-p #{fetch(:backup_attachment_local_path)}"
      end
      run_locally { execute "rsync -av --delete #{ fetch(:backup_attachment_rsync_path) }/ #{ fetch(:backup_attachment_local_path) }" }
    end
  end

  desc "upload attachment files from local machine"
  task :push_attachment do
    on roles fetch(:backup_attachment_roles) do
      execute :mkdir, "-p #{fetch(:backup_attachment_remote_path)}"
      run_locally { execute "rsync -av --delete #{ fetch(:backup_attachment_local_path) }/ #{ fetch(:backup_attachment_rsync_path) }" }
    end
  end


end