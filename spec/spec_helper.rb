# encoding: utf-8

require 'fileutils'

require 'git_topic'


# Testing-specific monkeypatching # {{{

# Disable caching on GitTopic for specs since we're calling the methods directly
# rather than assuming atmoic invocations.
class << GitTopic
  %w( current_branch remote_branches remote_branches_organized branches
      ).each do |m|

    define_method( "#{m}_with_nocache" ) do
      rv = send( "#{m}_without_nocache" )
      GitTopic::Naming::ClassMethods.class_variable_set( "@@#{m}", nil )
      rv
    end
    alias_method_chain m.to_sym, :nocache
  end

  def git_with_implicit_capture( cmds=[], opts={} )
    if opts[:show]
      puts capture_git( cmds )
    else
      git_without_implicit_capture( cmds, opts )
    end
  end
  alias_method_chain  :git, :implicit_capture
end


# Track original $stdout, $stderr write methods so we can “unmock” them for
# debugging

class << $stdout
  alias_method :real_write, :write
end
class << $stderr
  alias_method :real_write, :write
end


class Object
  def debug
    # For debugging, restore stubbed write
    class << $stdout
      alias_method :write, :real_write
    end
    class << $stderr
      alias_method :write, :real_write
    end

    require 'ruby-debug'
    debugger
  end
end

# }}}


Rspec.configure do |c|

  c.before( :all ) do
    @starting_dir   = Dir.pwd
    @user           = ENV['USER'] || `whoami`
  end

  c.before( :each ) do
    # setup the directories
    FileUtils.rm_rf   './tmp'
    FileUtils.mkdir   './tmp'

    # Copy our repos into tmp
    %w(fresh in-progress).each do |d|
      FileUtils.mkdir "./tmp/#{d}"
      FileUtils.cp_r "spec/template/#{d}",          "./tmp/#{d}/.git"
    end
    FileUtils.cp_r "spec/template/origin",          './tmp'
    FileUtils.cp_r "spec/template/origin-fresh",    './tmp'

    %w(origin origin-fresh fresh in-progress).each do |repo|
      # set template branches to their proper name (i.e. matching @user)
      Dir.chdir "./tmp/#{repo}"
      git_branches.each do |orig_name|
        new_name = orig_name.gsub( 'USER', @user )
        system(
          "git branch -m #{orig_name} #{new_name}"
        ) unless orig_name == new_name
        system "git fetch --prune > /dev/null 2> /dev/null"
      end
      Dir.chdir @starting_dir
    end
    Dir.chdir         './tmp'

    # capture output
    @output         = ''
    @err            = ''
    $stdout.stub!( :write ) { |*args| @output.<<( *args )}
    $stderr.stub!( :write ) { |*args| @err.<<( *args )}
  end

  c.after( :each ) { Dir.chdir @starting_dir }
end


# helpers # {{{

def use_repo( repo )
  Dir.chdir( repo )
  # Exit if e.g. GIT_DIR is set
  raise "Spec error" unless `git rev-parse --git-dir`.chomp == '.git'
end


def git_branch
  all_branches    = `git branch --no-color`.split( "\n" )
  current_branch  = all_branches.find{|b| b =~ /^\*/}

  current_branch[ 2..-1 ] unless current_branch.nil?
end

def git_head
  `git rev-parse HEAD`.chomp
end

def git_origin_master
  `git rev-parse origin/master`.chomp
end

def git_config( key )
  `git config #{key}`.chomp
end

def git_branch_merge
  git_config "branch.#{git_branch}.merge"
end

def git_branch_remote
  git_config "branch.#{git_branch}.remote"
end

def git_branches
  `git branch --no-color`.split( "\n" ).map do |bn|
    bn.gsub /^\*?\s*/, ''
  end
end

def git_remote_branches
  `git branch -r --no-color`.split( "\n" ).map do |bn|
    bn.gsub! %r{^\s*origin/}, ''
    bn.gsub! %r{ ->.*$}, ''
    bn
  end
end

# }}}

