require 'erb'
require 'stringio'

module Capistrano
  module Recipes2go
    module BaseHelpers
      
      def rvm_command
        ## Systemd requires absolute paths for RVM execution
        "/home/#{ fetch(:thin_daemon_user) }/.rvm/bin/rvm #{fetch(:rvm_ruby_version)} do"
      end
      

      def template2go(from, to)
        erb = get_template_file(from)
        upload! StringIO.new( ERB.new(erb).result(binding) ), to
      end
      
      
      def render2go(tmpl)
        erb = get_template_file(tmpl)
        ERB.new(erb).result(binding)
      end
      

      def template_with_role(from, to, role = nil)
        erb = get_template_file(from)
        upload! StringIO.new(ERB.new(erb).result(binding)), to
      end
      
      
      def get_template_file( from )
        [
            File.join('config', 'deploy', 'templates', "#{from}.erb"),
            File.join('config', 'deploy', 'templates', "#{from}"),
            File.join('lib', 'capistrano', 'templates', "#{from}.erb"),
            File.join('lib', 'capistrano', 'templates', "#{from}"),
            File.expand_path("../../../generators/capistrano/recipes2go/templates/#{from}.erb", __FILE__),
            File.expand_path("../../../generators/capistrano/recipes2go/templates/#{from}", __FILE__)
        ].each do |path|
          return File.read(path) if File.file?(path)
        end
        # false
        raise "File '#{from}' was not found!!!"
      end
      
      
    end
  end
end




