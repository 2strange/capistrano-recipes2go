require 'securerandom'
require 'erb'
require 'stringio'

module Capistrano
  module Recipes2go
    module PostgresqlHelpers

      ## 🔹 PostgreSQL Extension Helpers
      def extension_exists?(extension)
        psql 'test', fetch(:pg_database), "-p #{fetch(:pg_port)} -tAc", %Q{"SELECT 1 FROM pg_extension WHERE extname='#{extension}';" | grep -q 1}
      end

      def remove_extensions
        Array(fetch(:pg_extensions)).reverse.each do |ext|
          next if ext.nil? || ext.empty?
          on roles :db do
            psql 'execute', fetch(:pg_database), "-p #{fetch(:pg_port)} -c", %Q{"DROP EXTENSION IF EXISTS #{ext};"} if extension_exists?(ext)
          end
        end
      end

      ## 🔹 Generate database.yml dynamically
      def generate_database_yml_io
        StringIO.open do |s|
          s.puts "#{fetch(:pg_rails_env)}:"
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
          }.each { |key, value| s.puts "  #{key}: #{value}" }

          s.puts 'gssencmode: "disable"' if fetch(:pg_disable_gssencmode, false)
          s.string
        end
      end

      ## 🔹 Database Template Handling
      def pg_template(update = false, archetype_file = nil)
        config_file = "#{fetch(:pg_templates_path)}/postgresql.yml.erb"

        if update
          raise 'Original archetype file required for update!' if archetype_file.nil?
          raise 'Custom postgresql.yml.erb files cannot be updated dynamically.' if File.exist?(config_file)

          generate_database_yml_io
        else
          if File.exist?(config_file)
            StringIO.new(ERB.new(File.read(config_file)).result(binding)).string
          else
            generate_database_yml_io
          end
        end
      end

      ## 🔹 Paths for database.yml
      def database_yml_file
        raise "❌ ERROR: `:deploy_to` in your deploy config cannot contain '~' (home dir expansion is unsupported)." if shared_path.to_s.include?('~')
        shared_path.join('config/database.yml')
      end

      def archetype_database_yml_file
        raise "❌ ERROR: `:deploy_to` in your deploy config cannot contain '~' (home dir expansion is unsupported)." if shared_path.to_s.include?('~')
        deploy_path.join('db/database.yml')
      end

      ## 🔹 PostgreSQL Password Handling
      def generate_random_password
        SecureRandom.hex(28).to_i(16).to_s(36) # ~ 44 chars, secure but readable
      end

      def pg_password_generate
        return fetch(:pg_password) if fetch(:pg_password, nil)
        return ask(:pg_password, "PostgreSQL database password for the app: ") if fetch(:pg_ask_for_password)

        generate_random_password
      end

      ## 🔹 PostgreSQL Command Helpers
      def psql(type, database, *args)
        cmd = if fetch(:pg_skip_sudo)
                [:psql, "-d #{database}", *args.unshift("-U #{fetch(:pg_system_user)}")]
              else
                [:sudo, "-i -u #{fetch(:pg_system_user)}", :psql, *args]
              end

        case type
        when 'test' then test(*cmd)
        when 'capture' then capture(*cmd)
        else execute(*cmd)
        end
      end

      ## 🔹 PostgreSQL User & Database Checks
      def database_user_exists?
        psql 'test', fetch(:pg_system_db), "-p #{fetch(:pg_port)} -tAc", %Q{"SELECT 1 FROM pg_roles WHERE rolname='#{fetch(:pg_username)}';" | grep -q 1}
      end

      def database_user_password_different?
        current_password_md5 = psql 'capture', fetch(:pg_system_db), "-p #{fetch(:pg_port)} -tAc", %Q{"SELECT passwd FROM pg_shadow WHERE usename='#{fetch(:pg_username)}';"}
        new_password_md5 = "md5#{Digest::MD5.hexdigest("#{fetch(:pg_password)}#{fetch(:pg_username)}")}"
        current_password_md5 != new_password_md5
      end

      def database_exists?
        psql 'test', fetch(:pg_system_db), "-p #{fetch(:pg_port)} -tAc", %Q{"SELECT 1 FROM pg_database WHERE datname='#{fetch(:pg_database)}';" | grep -q 1}
      end

    end
  end
end
