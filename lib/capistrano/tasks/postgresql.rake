require 'stringio'
require 'capistrano/recipes2go/postgres_helpers'
include Capistrano::Recipes2go::PostgresHelpers

namespace :load do
  task :defaults do
    set :pg_rails_env, -> { fetch(:rails_env) || fetch(:stage) }
    set :pg_encoding, 'unicode'
    set :pg_database, -> { "#{fetch(:application)}_#{fetch(:stage)}" }
    set :pg_pool, 13
    set :pg_username, -> { fetch(:pg_database) }
    set :pg_password, -> { pg_password_generate } # Always ensures a password is set
    set :pg_socket, ''
    set :pg_host, -> { release_roles(:all).count == 1 ? 'localhost' : primary(:db).hostname }
    set :pg_port, 5432
    set :pg_timeout, 5000 # 5 seconds (rails default)

    # System settings
    set :pg_skip_sudo, false
    set :pg_system_user, 'postgres'
    set :pg_system_db, 'postgres'
    set :pg_use_hstore, false
    set :pg_extensions, []
    set :pg_disable_gssencmode, false
    set :pg_templates_path, 'config/deploy/templates' # Allows custom templates

    append :linked_files, 'config/database.yml'
  end
end

namespace :postgresql do

  desc 'Remove all PostgreSQL-related data'
  task :remove_all do
    on release_roles :all do
      execute :rm, database_yml_file if test "[ -e #{database_yml_file} ]"
    end
    on primary :db do
      execute :rm, archetype_database_yml_file if test "[ -e #{archetype_database_yml_file} ]"
    end
    on roles :db do
      psql 'execute', fetch(:pg_system_db), "-p #{fetch(:pg_port)} -c", %Q{"DROP DATABASE IF EXISTS \\"#{fetch(:pg_database)}\\";"}
      psql 'execute', fetch(:pg_system_db), "-p #{fetch(:pg_port)} -c", %Q{"DROP USER IF EXISTS \\"#{fetch(:pg_username)}\\";"}
      remove_extensions
    end
    puts '✅ Removed database, user, and extensions'
  end

  desc 'Remove PostgreSQL extensions'
  task :remove_extensions do
    remove_extensions
  end

  desc 'Add PostgreSQL extensions'
  task :add_extensions do
    on roles :db do
      Array(fetch(:pg_extensions)).each do |ext|
        next if ext.nil? || ext.empty?
        psql 'execute', fetch(:pg_database), "-p #{fetch(:pg_port)} -c", %Q{"CREATE EXTENSION IF NOT EXISTS #{ext};"} unless extension_exists?(ext)
      end
    end
  end

  desc 'Create database user'
  task :create_database_user do
    on roles :db do
      unless database_user_exists?
        psql 'execute', fetch(:pg_system_db), "-p #{fetch(:pg_port)} -c", %Q{"CREATE USER \\"#{fetch(:pg_username)}\\" PASSWORD}, redact("'#{fetch(:pg_password)}'"), %Q{;"}
      end
      if database_user_password_different?
        psql 'execute', fetch(:pg_system_db), "-p #{fetch(:pg_port)} -c", %Q{"ALTER USER \\"#{fetch(:pg_username)}\\" WITH PASSWORD}, redact("'#{fetch(:pg_password)}'"), %Q{;"}
      end
    end
  end

  desc 'Create PostgreSQL database'
  task :create_database do
    on roles :db do
      unless database_exists?
        psql 'execute', fetch(:pg_system_db), "-p #{fetch(:pg_port)} -c", %Q{"CREATE DATABASE \\"#{fetch(:pg_database)}\\" OWNER \\"#{fetch(:pg_username)}\\";"}
      end
    end
  end

  desc 'Generate database.yml archetype'
  task :generate_database_yml_archetype do
    on primary :db do
      if test "[ -e #{archetype_database_yml_file} ]"
        upload!(StringIO.new(pg_template(true, download!(archetype_database_yml_file))), archetype_database_yml_file)
      else
        execute :mkdir, '-p', File.dirname(archetype_database_yml_file)
        upload!(StringIO.new(pg_template), archetype_database_yml_file)
      end
    end
  end

  desc 'Copy archetype database.yml to clients'
  task :generate_database_yml do
    database_yml_contents = nil
    on primary :db do
      database_yml_contents = download!(archetype_database_yml_file)
    end
    on release_roles :all do
      execute :mkdir, '-p', File.dirname(database_yml_file)
      upload!(StringIO.new(database_yml_contents), database_yml_file)
    end
  end

  desc 'PostgreSQL setup tasks'
  task :setup do
    puts "🔧 Setting up PostgreSQL..."
    
    if release_roles(:db).empty?
      warn "⚠️  No :db role found! Skipping PostgreSQL setup."
      next
    end

    invoke 'postgresql:create_database_user'
    invoke 'postgresql:create_database'
    invoke 'postgresql:add_extensions'
    invoke 'postgresql:generate_database_yml_archetype'
    invoke 'postgresql:generate_database_yml'
    
    puts "✅ PostgreSQL setup complete!"
  end
end

desc 'Server setup tasks'
task :setup do
  invoke 'postgresql:setup'
end
