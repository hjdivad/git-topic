require 'spec_helper'


describe GitTopic do
  
  describe "#done" do

    describe "in in-progress" do

      before( :each ) { use_repo 'in-progress' }
      after( :each )  { Dir.chdir '..' }

      describe "without an argument" do

        it "should fail if the working tree is dirty" do
          GitTopic.work_on 'zombie-basic'
          dirty_branch!

          lambda{ GitTopic.done }.should raise_error
        end

        it "should fail if not on a wip branch" do
          `git checkout master > /dev/null 2> /dev/null`
          lambda{ GitTopic.done }.should raise_error
        end

        it "
          should push the wip branch to origin in the review namespace, delete the
          local branch, and leave the user on master
        ".oneline do

          git_branches.should             include( "wip/#{@user}/zombie-basic" )
          git_remote_branches.should_not  include( "review/#{@user}/zombie-basic" )
          GitTopic.work_on 'zombie-basic'
          GitTopic.done
         
          git_branches.should_not         include( "wip/#{@user}/zombie-basic" )
          git_remote_branches.should      include( "review/#{@user}/zombie-basic" )
          git_remote_branches.should_not  include( "wip/#{@user}/zombie-basic" )
          git_branch.should               == 'master'
        end
      end

      describe "with an argument" do

        it "should fail for non-wip branch arguments" do
          git_branches.should_not         include( "wip/#{@user}/invalid-branch" )
          lambda{ GitTopic.done( 'invalid-branch' )}.should raise_error
        end

        it "should succeed for superfluous wip-branch arguments" do
          git_branches.should             include( "wip/#{@user}/zombie-basic" )
          git_remote_branches.should_not  include( "review/#{@user}/zombie-basic" )
          GitTopic.work_on 'zombie-basic'
          GitTopic.done( 'zombie-basic' )
         
          git_branches.should_not         include( "wip/#{@user}/zombie-basic" )
          git_remote_branches.should      include( "review/#{@user}/zombie-basic" )
          git_remote_branches.should_not  include( "wip/#{@user}/zombie-basic" )
          git_branch.should               == 'master'
        end

        it "
          should succeed for wip-branch arguments, and leave the user on the
          same branch
        ".oneline do
          git_branches.should             include( "wip/#{@user}/pirates-advanced" )
          git_branches.should             include( "wip/#{@user}/zombie-basic" )
          git_remote_branches.should_not  include( "review/#{@user}/zombie-basic" )

          GitTopic.work_on  'pirates-advanced'
          GitTopic.done     'zombie-basic'

          git_branch.should               == "wip/#{@user}/pirates-advanced"
          git_branches.should_not         include( "wip/#{@user}/zombie-basic" )
          git_remote_branches.should      include( "review/#{@user}/zombie-basic" )
          git_remote_branches.should_not  include( "wip/#{@user}/zombie-basic" )
        end

        it "should succeed for fully-qualified wip-branch arguments" do
          git_branches.should             include( "wip/#{@user}/zombie-basic" )
          git_remote_branches.should_not  include( "review/#{@user}/zombie-basic" )
          GitTopic.done( "wip/#{@user}/zombie-basic" )
         
          git_branches.should_not         include( "wip/#{@user}/zombie-basic" )
          git_remote_branches.should      include( "review/#{@user}/zombie-basic" )
          git_remote_branches.should_not  include( "wip/#{@user}/zombie-basic" )
          git_branch.should               == 'master'
        end
      end
    end
  end

end
