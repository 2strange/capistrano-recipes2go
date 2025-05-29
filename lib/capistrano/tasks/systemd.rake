namespace :load do
  task :defaults do

    set :systemd_roles,               -> { :app }

    set :keep_logs_for_days,          -> { 14 } # Number of days to keep logs
    set :log_cleanup_service_name,    -> { "#{fetch(:application)}_#{fetch(:stage)}_log_cleanup" }

  end
end

namespace :systemd do


  desc "Upload and enable log cleanup systemd service and timer"
  task :daily_log_cleanup do
    on roles fetch(:systemd_roles) do
      service_name = fetch(:log_cleanup_service_name, "#{fetch(:application)}_#{fetch(:stage)}_log_cleanup")

      %w[service timer].each do |type|
        template2go("clean_logs_#{type}", "/tmp/#{service_name}.#{type}")
        execute :sudo, :mv, "/tmp/#{service_name}.#{type}", "/etc/systemd/system/#{service_name}.#{type}"
      end

      execute :sudo, :systemctl, :daemon_reload
      execute :sudo, :systemctl, :enable, "--now", "#{service_name}.timer"
    end
  end


  desc "Zeige aktive systemd Timer für Log-Cleanup"
  task :log_cleanup_timers do
    on roles fetch(:systemd_roles) do
      execute :sudo, :systemctl, "list-timers | grep #{fetch(:log_cleanup_service_name)} || true"
    end
  end

  desc "Zeige Journal-Logs des Log-Cleanup-Services"
  task :log_cleanup_journal do
    on roles fetch(:systemd_roles) do
      execute :sudo, :journalctl, "-u", "#{fetch(:log_cleanup_service_name)}.service", "--no-pager", "-n", "50"
    end
  end

  
end
