require 'yaml'

require 'rubygems'
require 'rake'

Dir[ 'lib/tasks/**/*' ].each{ |l| load l }


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


      To make use of bash autocompletion, you must do the following:

        1.  Make sure you source share/completion.bash before you source git's completion.
        2.  Optionally, copy git-topic-completion to your gem's bin directory.
            This is to sidestep ruby issue 3465 which makes loading gems far too
            slow for autocompletion.
    }
    gem.email = "git-topic@hjdivad.com"
    gem.homepage = "http://github.com/hjdivad/git-topic"
    gem.authors = ["David J. Hamilton"]

    gem.files.exclude 'git-topic'

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


desc "Write out build version.  You must supply BUILD."
task 'version:write:build' do
  unless ENV.has_key? 'BUILD'
    abort "Must supply BUILD=<build> to write out build version number." 
  end
  y = YAML::load_file( "VERSION.yml" )
  v = {
    :major => 0, :minor => 0, :patch => 0, :build => 0
  }
  v.merge!( y ) if y.is_a? Hash
  v[ :build ] = ENV['BUILD']

  v.each{|k,v| ENV[ k.to_s.upcase ] = v.to_s}
  Rake::Task["version:write"].invoke
end

task 'version:bump:build' do
  y = YAML::load_file( "VERSION.yml" )
  v = {
    :major => 0, :minor => 0, :patch => 0, :build => 0
  }
  v.merge!( y ) if y.is_a? Hash

  raise "Can't bump build: not a number" unless v[:build].is_a? Numeric
  v[ :build ] += 1

  v.each{|k,v| ENV[ k.to_s.upcase ] = v.to_s}
  Rake::Task["version:write"].invoke
end


desc "Run all specs."
task :spec do
  # Jeweler messes up specs by polluting ENV
  ENV.keys.grep( /git/i ).each{|k| ENV.delete k }
  sh "rspec spec"
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
