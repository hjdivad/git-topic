require 'rubygems'
require 'rake'

Dir[ 'lib/tasks/**/*' ].each{ |l| require l }


# TODO 2: git topic install-aliases
# TODO 1: deploy to github
# TODO 2: depoy to gemcutter?
begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = "git-topic"
    gem.summary = %Q{git command around reviewed topic branches}
    # TODO 1: longer description of gem
    gem.description = %Q{gem command around reviewed topic branches}
    gem.email = "git-topic@hjdivad.com"
    gem.homepage = "http://github.com/hjdivad/git-topic"
    gem.authors = ["David J. Hamilton"]
    gem.add_development_dependency "rspec", ">= 1.2.9"
    gem.add_development_dependency "yard", ">= 0"
    gem.add_development_dependency "cucumber", ">= 0"
    # gem is a Gem::Specification... see http://www.rubygems.org/read/chapter/20 for additional settings
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: gem install jeweler"
end

desc "Run all specs."
task :spec do
  sh "bundle exec rspec spec"
end


begin
  require 'yard'
  YARD::Rake::YardocTask.new
rescue LoadError
  task :yardoc do
    abort "YARD is not available. In order to run yardoc, you must: sudo gem install yard"
  end
end
