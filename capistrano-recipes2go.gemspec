$:.push File.expand_path("../lib", __FILE__)

require_relative "lib/capistrano/recipes2go/version"

Gem::Specification.new do |spec|
  spec.name        = "capistrano-recipes2go"
  spec.version     = Capistrano::Recipes2go::VERSION
  spec.authors     = ["Torsten Wetzel"]
  spec.email       = ["trendgegner@gmail.com"]
  spec.homepage    = "https://github.com/2strange/capistrano-recipes2go"
  spec.summary     = "Capistrano::Recipes2go collection of my most used capistrano recipes"
  spec.description = "Capistrano::Recipes2go .. a collection of my most used capistrano recipes"
  spec.license     = "MIT"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/2strange/capistrano-recipes2go"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{config,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  ## Its a rails only plugin, so require rails 
  spec.add_dependency       "rails",              ">= 6.0"
  
  ## require capistrano
  spec.add_dependency       "capistrano",         ">= 3.15"
  
  ## require gems needed to deploy
  spec.add_dependency       "ed25519",            ">= 1.2", "< 2.0"
  spec.add_dependency       "bcrypt_pbkdf",       ">= 1.0", "< 2.0"
  
  ## This gem is for rails apps so include rails related gems
  spec.add_dependency       "capistrano-rails",   ">= 1.6"
  
  ## I always use RVM so include it as well
  spec.add_dependency       "capistrano-rvm",     ">= 0.1.2"
  
  ## Dependency for db - tasks
  spec.add_dependency       "yaml_db"
  
  
end
