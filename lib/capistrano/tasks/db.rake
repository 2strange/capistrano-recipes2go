namespace :load do
  task :defaults do
    set :db_roles,                    -> { :db }
    set :db_backup_on_deploy,         -> { false }
    set :db_backup_type,              -> { :yaml_dumb } # or :pg_dump
    set :db_remote_backup_dir,        -> { "#{shared_path}/backups" }
    set :db_local_backup_dir,         -> { "db/backups" }
    set :db_pg_db,                    -> { fetch(:pg_database, "#{fetch(:application)}_#{fetch(:stage)}") }
    set :db_pg_user,                  -> { fetch(:pg_username, fetch(:user)) }
    set :db_pg_pass,                  -> { fetch(:pg_password, nil) }
    set :db_pg_host,                  -> { fetch(:pg_host, 'localhost') }
    set :db_pg_port,                  -> { fetch(:pg_port, 5432) }
    set :db_pg_keep_backups,          -> { 3 } # Number of backups to keep locally
    set :db_pg_backup_suffix,         -> { "#{fetch(:application)}_#{fetch(:stage)}_pg" } # Suffix for pg_dump files ([time]_[suffix].dump)
    set :db_redis_db_config,          -> { {} } # Redis backup config (db, port, host, namespace)
    set :db_redis_backup_suffix,      -> { "#{fetch(:application)}_#{fetch(:stage)}_redis" } # Suffix for redis backup files ([time]_[suffix].json)
    set :db_redis_keep_backups,       -> { 3 } # Number of Redis backups to keep
    set :db_redis_backup_namespace,   -> { nil }

  end
end

namespace :db do
  
  
  desc "seed the database"
  task :seed do
    on release_roles fetch(:db_roles) do
      puts()
      puts()
      puts("   ! ! !     C A U T I O N !     ! ! ! ")
      puts()
      puts()
      puts("This will seed and   DELETE ALL DATA   in your #{ fetch(:stage) } DB!!")
      puts()
      ask(:are_you_sure, 'no')
      if fetch(:are_you_sure, 'no').to_s.downcase == 'yes'
        within current_path do
          execute :bundle, :exec, :rake, "db:seed RAILS_ENV=#{fetch(:stage)}"
        end
      else
        puts(".. stoped process ..")
      end
    end
  end
  
  desc 'YAML-Dumb database and download file'
  task :yaml_dumb do
    # create local backup-dir if not existing
    run_locally do
      execute :mkdir, "-p #{fetch(:db_local_backup_dir, 'db/backups')}" 
    end
    # download yaml version of current DB
    on roles :db do
      within current_path do
        execute :bundle, :exec, :rake, "db:data:dump RAILS_ENV=#{fetch(:stage)}"
        # => download! "#{current_path}/db/data.yml", "#{fetch(:db_local_backup_dir, 'db/backups')}/#{ Time.now.strftime("%y-%m-%d_%H-%M") }_#{fetch(:stage)}_db_data.yml"
        execute "cd #{current_path}/db ; tar -czvf data-dumb.tar.gz data.yml"
        download! "#{current_path}/db/data-dumb.tar.gz", "#{fetch(:db_local_backup_dir, 'db/backups')}/#{ Time.now.strftime("%y-%m-%d_%H-%M") }_#{fetch(:stage)}_db.tar.gz"
      end
    end
  end
  
  desc "PG-Dump database and download file"
  task :pg_dump do

    remote_dir = fetch(:db_remote_backup_dir, "#{shared_path}/backups")
    file_suffix = fetch(:db_pg_backup_suffix, "#{fetch(:application)}_#{fetch(:stage)}_pg")

    # Zeitstempel und Stage als Variable speichern
    timestamp = Time.now.strftime("%Y-%m-%d_%H-%M")
    filename = "#{timestamp}_#{file_suffix}.dump"
    filezip = "#{timestamp}_#{file_suffix}.tar.gz"
    
    db_password = fetch(:db_pg_pass, nil)
    if db_password.to_s.empty?
      # Passwort für DB-User abfragen (sicherer als hartcodiert)
      ask(:db_password, "Passwort für #{fetch(:db_pg_db)} eingeben:", echo: false)
      db_password = fetch(:db_password)
    end
      
    # Lokales Backup-Verzeichnis erstellen falls nicht vorhanden
    run_locally do
      execute :mkdir, "-p #{fetch(:db_local_backup_dir, 'db/backups')}"
    end
    
    # Auf dem Server: Datenbankdump erstellen
    on roles fetch(:db_roles) do

      execute :mkdir, "-p", remote_dir

      # Dump erstellen im shared_path
      within shared_path do
        # PGPASSWORD-Umgebungsvariable für pg_dump setzen
        execute %(PGPASSWORD=#{db_password} pg_dump -U #{fetch(:db_pg_user)} -h #{fetch(:db_pg_host)} -p #{fetch(:db_pg_port)} -d #{fetch(:db_pg_db)} -F c -f #{remote_dir}/#{filename})
        

        # Komprimieren des Dumps
        execute "tar -czvf #{remote_dir}/#{filezip} #{remote_dir}/#{filename}"

        # Dump herunterladen
        # download! "#{remote_dir}/#{filename}", "#{fetch(:db_local_backup_dir, 'db/backups')}/#{filename}"
        download! "#{remote_dir}/#{filezip}", "#{fetch(:db_local_backup_dir, 'db/backups')}/#{filezip}"
        
        # Temporären Dump auf dem Server löschen
        execute :rm, "#{remote_dir}/#{filezip}"
      end

      max_backups = fetch(:db_pg_keep_backups, 3)
      file_pattern = "*_#{file_suffix}.dump"

      within remote_dir do
        puts "🧹 Bereinige Backups in #{remote_dir}, behalte nur die letzten #{max_backups}..."

        # Das Kommando:
        # - listet Dateien nach Zeit (`ls -tp`)
        # - filtert nur reguläre Dateien (`grep -v '/'`)
        # - schneidet ab ab Zeile (max_backups + 1) (`tail -n +N`)
        # - löscht sie mit `xargs rm`
        execute :bash, "-c", %Q{
          cd #{remote_dir} &&
          ls -tp #{file_pattern} | grep -v '/$' | tail -n +#{max_backups + 1} | xargs -r rm --
        }
      end

    end
  end



  desc "Backup Redis DB with TTL as JSON on remote server"
  task :redis_dump do
    redis_config = { db: 0, port: 6379, host: '127.0.0.1' }.merge fetch(:db_redis_db_config, {})
    
    namespace    = fetch(:db_redis_backup_namespace, nil)
    
    remote_dir   = fetch(:db_remote_backup_dir, "#{shared_path}/backups")
    local_dir    = fetch(:db_local_backup_dir, 'db/backups')
    file_suffix  = fetch(:db_redis_backup_suffix, "#{fetch(:application)}_#{fetch(:stage)}_redis")
    timestamp    = Time.now.strftime("%Y-%m-%d_%H-%M")
    filename     = "#{timestamp}#{namespace.present? ? "__#{namespace}_" : ''}_#{file_suffix}.json"
    filezip      = "#{timestamp}#{namespace.present? ? "__#{namespace}_" : ''}_#{file_suffix}.tar.gz"

    run_locally do
      execute :mkdir, "-p #{local_dir}"
    end

    on roles fetch(:db_roles) do
      within shared_path do
        execute :mkdir, "-p", remote_dir

        script = <<~RUBY
          require 'redis'
          require 'json'
          require 'fileutils'

          FileUtils.mkdir_p("#{remote_dir}")
          redis = Redis.new(
            host: "#{host}",
            port: #{port},
            db: #{db_index},
            #{password ? "password: '#{password}'," : ""}
          )

          pattern = #{namespace ? "\"#{namespace}:*\"" : '"*"'}
          prefix_len = #{namespace ? namespace.length + 1 : 0}

          keys = redis.keys(pattern)
          File.open("#{remote_dir}/#{filename}", "w") do |f|
            keys.each do |key|
              short_key = key[prefix_len..-1] if #{namespace ? "true" : "false"}
              store_key = #{namespace ? "short_key || key" : "key"}

              type = redis.type(key)
              ttl  = redis.pttl(key)

              value = case type
                      when "string" then redis.get(key)
                      when "hash"   then redis.hgetall(key)
                      when "list"   then redis.lrange(key, 0, -1)
                      when "set"    then redis.smembers(key)
                      when "zset"   then redis.zrange(key, 0, -1, with_scores: true)
                      else nil
                      end

              f.puts({ key: store_key, type: type, value: value, ttl: ttl }.to_json)
            end
          end

          puts "✅ Redis-Backup geschrieben: #{remote_dir}/#{filename}"
        RUBY

        remote_script = "#{shared_path}/tmp/redis_backup_#{timestamp}.rb"
        upload! StringIO.new(script), remote_script
        execute :ruby, remote_script

        # Komprimieren
        execute "tar -czvf #{remote_dir}/#{filezip} -C #{remote_dir} #{filename}"
        download! "#{remote_dir}/#{filezip}", "#{local_dir}/#{filezip}"
        execute :rm, "#{remote_script} #{remote_dir}/#{filename} #{remote_dir}/#{filezip}"

        # Ältere Backups löschen
        keep = fetch(:db_redis_keep_backups, 3)
        file_pattern = "*_#{file_suffix}.json"

        within remote_dir do
          puts "🧹 Bereinige alte Redis-Backups, behalte nur die letzten #{keep}..."
          execute :bash, "-c", %Q{
            cd #{remote_dir} &&
            ls -tp #{file_pattern} | grep -v '/$' | tail -n +#{keep + 1} | xargs -r rm --
          }
        end
      end
    end
  end


  ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## 
  
  desc "upload data.yml to server and load it = DELETES EXISTING DATA"
  task :upload_and_replace_data do
    on roles fetch(:db_roles) do
      puts()
      puts()
      puts("   ! ! !     C A U T I O N !     ! ! ! ")
      puts()
      puts()
      puts("This will upload 'local-App/db/data.yml' and load it in current DB")
      puts()
      puts("This will   DELETE ALL DATA   in your #{ fetch(:stage) } DB!!")
      puts()
      ask(:are_you_sure, 'no')
      if fetch(:are_you_sure, 'no').to_s.downcase == 'yes'
        local_dir = "./db/data.yml"
        remote_dir = "#{host.user}@#{host.hostname}:#{release_path}/db/data.yml"
        puts(".. uploading db/data.yml")
        run_locally { execute "rsync -av --delete #{local_dir} #{remote_dir}" }
        puts(".. loading data.yml in #{ fetch(:stage) } DB")
        within release_path do
          execute :bundle, :exec, :rake, "db:data:load RAILS_ENV=#{fetch(:stage)}"
        end
      else
        puts(".. stoped process ..")
      end
    end
  end
  
end

namespace :deploy do
  before :starting, :backup_database do
    if fetch(:db_backup_on_deploy)
      if fetch(:db_backup_type, :yaml_dumb).to_s == 'pg_dump'
        invoke "db:pg_dump"
      else
        invoke "db:yaml_dumb"
      end
    end
  end
end