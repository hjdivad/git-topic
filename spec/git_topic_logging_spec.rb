# encoding: utf-8
require 'spec_helper'

describe GitTopic do

  describe "logging" do
    before :each do
      use_repo  'in-progress'
      @log_path = "#{@starting_dir}/tmp/home/.git_topic/log"
    end


    it "should log to $HOME/.git_topic/log" do
      File.exists?( @log_path ).should    be_false
      with_argv( %w( work-on something origin/review/user24601/ninja-basic )) do
        GitTopic.run
      end
      File.exists?( @log_path ).should    be_true
    end

    it "should log complete commands" do
      with_argv( %w( work-on something origin/review/user24601/ninja-basic )) do
        GitTopic.run
      end
      File.exists?( @log_path ).should    be_true
      log = File.read @log_path

      log.should      =~ %r{work-on something origin/review/user24601/ninja-basic}
    end

    it "should log all git commands invoked" do
      with_argv( %w( work-on something origin/review/user24601/ninja-basic )) do
        GitTopic.run
      end
      File.exists?( @log_path ).should    be_true
      log = File.read @log_path

      [
        "git branch -r --no-color",
        "git push origin HEAD:refs/heads/wip/#{@user}/something",
        "git branch",
        "git checkout -b wip/#{@user}/something origin/wip/#{@user}/something",
        "git reset --hard origin/review/user24601/ninja-basic",
        "git branch",
      ].each do |cmd|
        log.should      =~ %r{#{cmd}}
      end
    end

    it "should log all errors from git" do
      with_argv( %w( work-on something totally/invalid/upstream )) do
        GitTopic.run
      end
      File.exists?( @log_path ).should    be_true
      log = File.read @log_path

      [
        "fatal: ambiguous argument 'totally/invalid/upstream': unknown revision",
      ].each do |cmd|
        log.should      =~ %r{#{cmd}}
      end
    end

    it "should not log if --no-log is specified" do
      File.exists?( @log_path ).should    be_false
      with_argv( %w( --no-log work-on something origin/review/user24601/ninja-basic )) do
        GitTopic.run
      end
      File.exists?( @log_path ).should    be_false
    end
  end

end

