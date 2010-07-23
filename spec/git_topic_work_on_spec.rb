require 'spec_helper'


describe GitTopic do

  describe "#work_on" do

    share_examples_for "#work_on general cases" do

      it "
        should trim namespaces from args and output a warning
      ".oneline do

        git_branch.should_not                   == "wip/#{@user}/topic"
        GitTopic.work_on "wip/#{@user}/topic"
        git_branch.should                       == "wip/#{@user}/topic"
      end

      it "should trim partial namespaces (with implicit ‘user’)" do
        git_branch.should_not                   == "wip/#{@user}/topic"
        GitTopic.work_on "wip/topic"
        git_branch.should                       == "wip/#{@user}/topic"
      end

    end

    describe "in fresh" do
      before( :each ) { use_repo( 'fresh' )}
      after( :each )  { Dir.chdir( '..' )}

      it_should_behave_like "#work_on general cases"

      it "
       should create (and switch to) a new branch with a name that matches the
       given topic, in the wip namespace.  A remote tracking branch should also
       be set up.
      ".oneline do

        GitTopic.work_on( 'topic' )
        git_branch.should               == "wip/#{@user}/topic"
        git_branch_remote.should        == 'origin'
        git_branch_merge.should         == "refs/heads/wip/#{@user}/topic"
      end

      it "should fail if no topic is given" do
        lambda { GitTopic.work_on( nil )}.should  raise_error
      end

      it "should provide feedback to the user" do
        GitTopic.work_on( 'topic' )
        $?.success?.should          == true
        @output.should_not          be_nil
        @output.should_not          be_empty
      end

    end

    describe "in in-progress" do

      before( :each ) { use_repo( 'in-progress' )}
      after( :each )  { Dir.chdir( '..' )}

      it_should_behave_like "#work_on general cases"

      it "should switch to (rather than create) an existing topic branch" do
        git_branches.should include( "wip/#{@user}/zombie-basic" )
        lambda{ GitTopic.work_on  'zombie-basic' }.should_not raise_error

        git_branch.should   == "wip/#{@user}/zombie-basic"
      end

      it "should accept upstream as an argument" do
        git_remote_branches.should include( "review/#{@user}/pirates" )
        lambda do
          GitTopic.work_on  'pirates-etc',
                            :upstream => "origin/review/#{@user}/pirates"
        end.should_not raise_error

        git_branch.should   == "wip/#{@user}/pirates-etc"
        git_head.should     == 'c0838ed2ee8f2e83c8bda859fc5e332b92f0a5a3'
      end

      it "
        should use (and then destroy) the rejected branch for the topic, if one
        exists
      ".oneline do

        git_remote_branches.should        include( "rejected/#{@user}/krakens" )
        GitTopic.work_on    'krakens'
        git_branch.should                 == "wip/#{@user}/krakens"
        git_remote_branches.should_not    include( "rejected/#{@user}/krakens" )
        git_remote_branches.should        include( "wip/#{@user}/krakens" )
        git_head.should                   == '44ffd9c9c8b52b201659e3ad318cdad6ec836b46'
      end

      it "
        should use (and then destroy) the review branch for the topic, if one
        exists
      ".oneline do

        git_remote_branches.should        include( "rejected/#{@user}/krakens" )
        GitTopic.work_on    'krakens'
        git_branch.should                 == "wip/#{@user}/krakens"
        git_remote_branches.should_not    include( "rejected/#{@user}/krakens" )
        git_remote_branches.should        include( "wip/#{@user}/krakens" )
        git_head.should                   == '44ffd9c9c8b52b201659e3ad318cdad6ec836b46'
      end

    end
  end
end
