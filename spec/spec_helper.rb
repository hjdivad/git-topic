# encoding: utf-8

require 'fileutils'

require 'git_topic'
require 'git_topic/cli'


# Testing-specific monkeypatching # {{{

# Disable caching on GitTopic for specs since we're calling the methods directly
# rather than assuming atmoic invocations.
class << GitTopic
  %w( current_branch remote_branches remote_branches_organized branches
      ).each do |m|

    define_method( "#{m}_with_nocache" ) do
      send( "#{m}_without_nocache" ).tap do
        GitTopic::Naming::ClassMethods.class_variable_set(  "@@#{m}", nil )
        GitTopic::Git::ClassMethods.class_variable_set(     "@@#{m}", nil )
      end
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

  def invoke_git_editor file
    raise "
      invoke_git_editor invoked with (#{file}).  If you expect this method to be
      called, mock or stub it.
    ".oneline
  end

end

class << GitTopic::Logger
  def logger_with_nocache
    logger_without_nocache.tap{ @logger = nil }
  end
  alias_method_chain :logger, :nocache
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

    $debugging = true
    require 'ruby-debug'
    debugger
  end
end

# }}}


Rspec.configure do |c|

  c.before( :all ) do
    @starting_dir   = Dir.pwd
    @user           = ENV['USER'] || `whoami`
    ENV['HOME']     = "#{@starting_dir}/tmp/home"
  end

  c.before( :each ) do
    # setup the directories
    FileUtils.rm_rf   './tmp'
    FileUtils.mkdir   './tmp'
    FileUtils.mkdir   './tmp/home'

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
      if File.exists? ".git/refs/notes/reviews/USER"
        FileUtils.mv  ".git/refs/notes/reviews/USER",
                      ".git/refs/notes/reviews/#{@user}"
      end
      if File.exists? "./refs/notes/reviews/USER"
        FileUtils.mv  "./refs/notes/reviews/USER",
                      "./refs/notes/reviews/#{@user}"
      end
      Dir.chdir @starting_dir
    end
    Dir.chdir         "#{@starting_dir}/tmp"

    # capture output
    @output         = ''
    @err            = ''
    $stdout.stub!( :write ) { |*args| @output.<<( *args )}
    $stderr.stub!( :write ) { |*args| @err.<<( *args )}
  end
  c.after( :each ) { Dir.chdir @starting_dir }


  c.before( :each ) do
    GitTopic::global_opts[:verbose] = true
  end
end


# helpers # {{{

def use_repo( repo )
  Dir.chdir( "#{@starting_dir}/tmp/#{repo}" )
  # Exit if e.g. GIT_DIR is set
  raise "Spec error" unless git_dir == '.git'
end


def git_dir
  `git rev-parse --git-dir 2> /dev/null`.chomp
end

def git_branch
  all_branches    = `git branch --no-color`.split( "\n" )
  current_branch  = all_branches.find{|b| b =~ /^\*/}

  current_branch[ 2..-1 ] unless current_branch.nil?
end

def git_head  suffix=nil
  `git rev-parse HEAD#{suffix}`.chomp
end

def git_remote  branch
  ref = branch
  ref = "origin/#{ref}" unless ref =~ %r{^origin}
  `git rev-parse #{ref}`.chomp
end

def git_origin_master
  `git rev-parse origin/master`.chomp
end

def git_config  key 
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

def git_notes_list  ref
  `git notes --ref #{ref}`.split( "\n" )
end

def git_notes_show( ref, commit='HEAD' )
  `git notes --ref #{ref} show #{commit}`.chomp
end

def git_diff
  `git diff --no-color`.chomp
end


def dirty_branch!
  File.open( 'dirty', 'w' ){|f| f.puts "some content" }
  system "git add -N dirty"
end


def with_argv *val 
  restore = ARGV.dup
  ARGV.replace( val.flatten )
  rv = yield
  ARGV.replace( restore )
  rv
end


# }}}

