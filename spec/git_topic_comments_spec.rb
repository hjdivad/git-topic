# encoding: utf-8
require 'spec_helper'


describe GitTopic do

  describe "#comments" do

    describe "with an argument" do

      before( :each )   { use_repo 'in-progress' }


      it "shows comments for the supplied topic" do
        git_branch.should                     == 'master'
        GitTopic.should_receive( :git ) do |cmd|
          cmd.should =~ /log/
          cmd.should =~ %r{origin/master\.\.}
          cmd.should =~ /--no-standard-notes/
          cmd.should =~ %r{--show-notes=refs/notes/reviews/#{@user}/krakens}
        end
        GitTopic.comments 'krakens'
      end

      it "should strip fully qualified namespaces" do
        git_branch.should                     == 'master'
        GitTopic.should_receive( :git ) do |cmd|
          cmd.should =~ /log/
          cmd.should =~ %r{origin/master\.\.}
          cmd.should =~ /--no-standard-notes/
          cmd.should =~ %r{--show-notes=refs/notes/reviews/#{@user}/krakens}
        end
        GitTopic.comments "rejected/#{@user}/krakens"
      end

      it "should list comments for a user's review branches, if requested" do
        GitTopic.work_on  'krakens'
        GitTopic.done
        git_remote_branches.should            include "review/#{@user}/krakens"
        GitTopic.should_receive( :git ) do |cmd|
          cmd.should =~ /log/
          cmd.should =~ %r{origin/master\.\.}
          cmd.should =~ /--no-standard-notes/
          cmd.should =~ %r{--show-notes=refs/notes/reviews/#{@user}/krakens}
        end
        GitTopic.comments "krakens"
      end

      it "should strip partially qualified namespaces" do
        git_branch.should                     == 'master'
        GitTopic.should_receive( :git ) do |cmd|
          cmd.should =~ /log/
          cmd.should =~ %r{origin/master\.\.}
          cmd.should =~ /--no-standard-notes/
          cmd.should =~ %r{--show-notes=refs/notes/reviews/#{@user}/krakens}
        end
        GitTopic.comments "#{@user}/krakens"
      end

      it "should strip fully qualified namespaces for other users" do
        git_branch.should                     == 'master'
        GitTopic.should_receive( :git ) do |cmd|
          cmd.should =~ /log/
          cmd.should =~ %r{origin/master\.\.}
          cmd.should =~ /--no-standard-notes/
          cmd.should =~ %r{--show-notes=refs/notes/reviews/user24601/ninja-basic}
        end
        GitTopic.comments "review/user24601/ninja-basic"
      end

      it "should strip partially qualified namespaces for other users" do
        git_branch.should                     == 'master'
        GitTopic.should_receive( :git ) do |cmd|
          cmd.should =~ /log/
          cmd.should =~ %r{origin/master\.\.}
          cmd.should =~ /--no-standard-notes/
          cmd.should =~ %r{--show-notes=refs/notes/reviews/user24601/ninja-basic}
        end
        GitTopic.comments "user24601/ninja-basic"
      end

    end

    describe "with no argument" do

      describe "on a branch with no comments" do

        before( :each ) do
          use_repo            'in-progress'
          GitTopic.work_on    'pirates-advanced'
        end

        it "should report that there are no comments" do
          lambda{ GitTopic.comments }.should_not      raise_error
          @output.should_not                          be_nil
          @output.should                              =~ /no comments/i
        end
      end


      describe "on a branch with comments" do

        before( :each ) do
          use_repo            'in-progress'
          GitTopic.work_on    'krakens'
        end


        it "should invoke git log to display the comments" do
          GitTopic.should_receive( :git ) do |cmd|
            cmd.should =~ /log/
            cmd.should =~ %r{origin/master\.\.origin/wip/#{@user}/krakens}
            cmd.should =~ /--no-standard-notes/
            cmd.should =~ %r{--show-notes=refs/notes/reviews/#{@user}/krakens}
          end

          lambda{ GitTopic.comments }.should_not      raise_error
        end
      end

      describe "on a commit named by a topic branch with comments" do

        before( :each ) do
          use_repo        'in-progress'
          system          "git checkout origin/rejected/#{@user}/krakens > /dev/null 2> /dev/null"
        end

        it "should report the topic it's guessing to look for comments on" do
          lambda{ GitTopic.comments }.should_not      raise_error
          @output.should                              =~ /no topic branch/i
          @output.should                              =~ /krakens/i
        end

        it "should guess a topic and show its comments" do
          GitTopic.should_receive( :git ) do |cmd|
            cmd.should =~ /log/
            cmd.should =~ %r{origin/master\.\.}
            cmd.should =~ /--no-standard-notes/
            cmd.should =~ %r{--show-notes=refs/notes/reviews/#{@user}/krakens}
          end

          lambda{ GitTopic.comments }.should_not      raise_error
        end

      end
    end

  end

end
