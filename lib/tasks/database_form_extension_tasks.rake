namespace :radiant do
  namespace :extensions do
    namespace :database_form do
      
      desc "Runs the migration of the Database Form extension"
      task :migrate => :environment do
        require 'radiant/extension_migrator'
        if ENV["VERSION"]
          DatabaseFormExtension.migrator.migrate(ENV["VERSION"].to_i)
        else
          DatabaseFormExtension.migrator.migrate
        end
      end
    
      desc "Copies the Database Form extension assets to the public directory"
      task :update => :environment do
        FileUtils.cp DatabaseFormExtension.root + "/public/javascripts/validation.js", RAILS_ROOT + "/public/javascripts"
      end
    end
  end
end
