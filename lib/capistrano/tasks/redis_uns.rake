## Capistrano task to handle Redis namespace migration
## for Sidekiq 7+


namespace :load do
  task :defaults do
    set :redis_uns_roles, -> { :web }
    set :redis_uns_namespace, -> { "old_namespace" }
    set :redis_uns_old_redis, -> { {db: 0} }
    set :redis_uns_new_redis, -> { {db: 1} }
  end
end

def build_redis_config_hash(input, db = 0)
  return {db: db} if input == false || input.nil?
  raise ArgumentError, "Redis config must be a Hash or false" unless input.is_a?(Hash)
  {db: db}.merge(input)
end

namespace :redis_uns do

  desc "Lade das Redis-Namespace-Skript auf den Server (shared_path/upgrade_helpers)"
  task :upload_namespace_script do
    on roles(fetch(:redis_uns_roles)) do

      ensure_shared_path("#{shared_path}/upgrade_helpers")

      %w[copy_uns count_all list_all list_candidates].each do |script|
        template2go("redis/#{script}", "/tmp/redis_#{script}.rb")
        execute :sudo, :mv, "/tmp/redis_#{script}.rb", "#{shared_path}/upgrade_helpers/#{script}.rb"
      end

    end
  end


  %w[copy_uns list_candidates].each do |script|
    desc ( script == 'copy_uns' ? "Kopiere Keys mit Namespace aus einer DB in eine andere UnNameSpaced" : "Liste alle Keys mit Namespace auf" )
    task script.to_sym do
      on roles(fetch(:redis_uns_roles)) do
        script_remote_path = "#{shared_path}/upgrade_helpers/#{script}.rb"

        # ENV-Variablen definieren
        redis_namespace     = fetch(:redis_uns_namespace)
        source_config_json  = fetch(:redis_uns_old_redis).to_json
        target_config_json  = fetch(:redis_uns_new_redis).to_json

        # Skript mit Umgebungsvariablen ausführen
        within shared_path do
          execute %(REDIS_NAMESPACE=#{redis_namespace} REDIS_SOURCE_CONFIG='#{source_config_json}' REDIS_TARGET_CONFIG='#{target_config_json}' ruby #{script_remote_path})
        end
      end
    end
  end


  %w[count_all list_all].each do |script|
    ['old', 'new'].each do |rds|

      desc "#{script.to_s.gsub(/_/,' ').titleize} Redis-Keys in all dbs .. #{rds} DB"
      task "#{script}_#{rds}".to_sym do
        on roles(fetch(:redis_uns_roles)) do
          script_remote_path = "#{shared_path}/upgrade_helpers/#{script}.rb"

          # ENV-Variablen definieren
          source_config_json  = fetch(:redis_uns_old_redis).to_json
          target_config_json  = fetch(:redis_uns_new_redis).to_json

          uns_config_json = ( rds == 'new' ? target_config_json : source_config_json )

          # Skript mit Umgebungsvariablen ausführen
          within shared_path do
            execute %(REDIS_UNS_CONFIG='#{uns_config_json}' ruby #{script_remote_path})
          end
        end
      end

    end
  end


end
