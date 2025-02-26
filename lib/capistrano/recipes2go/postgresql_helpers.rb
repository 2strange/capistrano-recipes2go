require 'securerandom'
require 'erb'
require 'stringio'

module Capistrano
  module Recipes2go
    module PostgresqlHelpers

      ## Base Helpers
      def extension_exists?(extension)
        psql 'test', fetch(:pg_database), "-p #{fetch(:pg_port)} -tAc", %Q{"SELECT 1 FROM pg_extension WHERE extname='#{extension}';" | grep -q 1}
      end

      def remove_extensions
        if Array( fetch(:pg_extensions) ).any?
          on roles :db do
            # remove in reverse order if extension is present
            Array( fetch(:pg_extensions) ).reverse.each do |ext|
              next if [nil, false, ""].include?(ext)
              psql 'execute', fetch(:pg_database), "-p #{fetch(:pg_port)} -c", %Q{"DROP EXTENSION IF EXISTS #{ext};"} if extension_exists?(ext)
            end
          end
        end
      end

      def generate_database_yml_io
        StringIO.open do |s|
          s.puts "#{fetch(:pg_env)}:"
          {
              adapter: 'postgresql',
              encoding: fetch(:pg_encoding),
              database: fetch(:pg_database),
              pool: fetch(:pg_pool),
              username: fetch(:pg_username),
              password: fetch(:pg_password),
              host: fetch(:pg_host),
              socket: fetch(:pg_socket),
              port: fetch(:pg_port),
              timeout: fetch(:pg_timeout)
          }.each { |option_name,option_value| s.puts "  #{option_name}: #{option_value}" } # Yml does not support tabs. There are two spaces leading the config option line
          s.puts 'gssencmode: "disable"'  if fetch(:pg_disable_gssencmode, false)  # Add gssencmode: "disable" to the end of the file
          s.string
        end
      end

      def pg_template(update=false,archetype_file=nil)
        config_file = "#{fetch(:pg_templates_path)}/postgresql.yml.erb"
        if update
          raise('Regeneration of archetype database.yml need the original file to update from.') if archetype_file.nil?
          raise('Cannot update a custom postgresql.yml.erb file.') if File.exist?(config_file) # Skip custom postgresql.yml.erb if we're updating. It's not supported
          # Update yml file from settings
          generate_database_yml_io
        else
          if File.exist?(config_file) # If there is a customized file in your rails app template directory, use it and convert any ERB
            StringIO.new( ERB.new(File.read(config_file)).result(binding) ).string
          else # Else there's no customized file in your rails app template directory, proceed with the default.
            # Build yml file from settings
            ## We build the file line by line to avoid overwriting existing files
            generate_database_yml_io
          end
        end

      end

      # location of database.yml file on clients
      def database_yml_file
        raise(":deploy_to in your app/config/deploy/#{fetch(:rails_env)}.rb file cannot contain ~") if shared_path.to_s.include?('~') # issues/27
        shared_path.join('config/database.yml')
      end

      # location of archetypal database.yml file created on primary db role when user and database are first created
      def archetype_database_yml_file
        raise(":deploy_to in your app/config/deploy/#{fetch(:rails_env)}.rb file cannot contain ~") if shared_path.to_s.include?('~') # issues/27
        deploy_path.join('db/database.yml')
      end


      ## Password Helpers
      def generate_random_password
        # SecureRandom.hex(10)
        # => use more secure password generation ( 0-9 + a-z )
        # SecureRandom.base36(42)               # method not available.. so we use hex and convert it to base36
        SecureRandom.hex(28).to_i(16).to_s(36)  # generates ~ 44 characters
      end

      def pg_password_generate
        if fetch(:pg_password, nil)
          fetch(:pg_password)
        elsif fetch(:pg_ask_for_password)
          ask :pg_password, "PostgreSQL database password for the app: "
        else
          generate_random_password
        end
      end


      ## psql Helpers
      def psql(type, database, *args)
        if fetch(:pg_without_sudo)
          # Add the :pg_system_user to psql command since we aren't using sudo anymore
          cmd = [ :psql, "-d #{database}", *args.unshift("-U #{fetch(:pg_system_user)}") ]
        else
          cmd = [:sudo, "-i -u #{fetch(:pg_system_user)}", :psql, *args]
        end
        # Allow us to execute the different sshkit commands
        if type == 'test'
          test *cmd
        elsif type == 'capture'
          capture *cmd
        else
          execute *cmd
        end
      end

      def database_user_exists?
        psql 'test', fetch(:pg_system_db),"-p #{fetch(:pg_port)} -tAc", %Q{"SELECT 1 FROM pg_roles WHERE rolname='#{fetch(:pg_username)}';" | grep -q 1}
      end

      def database_user_password_different?
        current_password_md5 = psql 'capture', fetch(:pg_system_db),"-p #{fetch(:pg_port)} -tAc", %Q{"select passwd from pg_shadow WHERE usename='#{fetch(:pg_username)}';"}
        new_password_md5 = "md5#{Digest::MD5.hexdigest("#{fetch(:pg_password)}#{fetch(:pg_username)}")}"
        current_password_md5 == new_password_md5 ? false : true
      end

      def database_exists?
        psql 'test', fetch(:pg_system_db), "-p #{fetch(:pg_port)} -tAc", %Q{"SELECT 1 FROM pg_database WHERE datname='#{fetch(:pg_database)}';" | grep -q 1}
      end

    end
  end
end

