require 'rubygems'
require 'rake'

Dir[ 'lib/tasks/**/*' ].each{ |l| require l }

# TODO 1: cleanup specs (possibly have specs setup repos, or possibly tar up
#         repos and extract them)
# TODO 2: topic abandon <topic>
# TODO 1: handle malformed args
# TODO 1: git-topic comment
#           edit files & have the diffs pulled into notes?

# TODO 1: git work-on <topic> should kill review branch


begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = "git-topic"
    gem.summary = %Q{git command around reviewed topic branches}
    gem.description = %Q{
      gem command around reviewed topic branches.  Supports workflow of the form:

      # alexander:
      git work-on <topic>
      git done

      # bismarck:
      git status    # notice a review branch
      git review <topic>
      # happy, merge into master, push and cleanup
      git accept

      git review <topic2>
      # unhappy
      git reject

      # alexander:
      git status    # notice rejected topic
      git work-on <topic>

      see README.rdoc for more (any) details.
    }
    gem.email = "git-topic@hjdivad.com"
    gem.homepage = "http://github.com/hjdivad/git-topic"
    gem.authors = ["David J. Hamilton"]

    if File.exists? 'Gemfile'
      require 'bundler'
      bundler = Bundler.load
      bundler.dependencies_for( :runtime ).each do |dep|
        gem.add_dependency              dep.name, dep.requirement.to_s
      end
      bundler.dependencies_for( :development ).each do |dep|
        gem.add_development_dependency  dep.name, dep.requirement.to_s
      end
    end
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
  desc "Try (and fail) to run yardoc to get an error message."
  task :yard do
    abort "YARD is not available. In order to run yardoc, you must: sudo gem install yard"
  end
end
