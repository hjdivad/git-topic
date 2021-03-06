# encoding: utf-8
require 'spec_helper'


describe GitTopic do
  
  describe "#accept" do

    describe "while on a review branch" do
      before( :each ) do
        use_repo 'in-progress'
        GitTopic.review 'user24601/zombie-basic'
      end

      describe "with no specified argument" do
        it "
          should merge to master, push master and destroy the local and remote
          branches when the merge is a fast-forward merge
        ".oneline do

          git_branch.should               == 'review/user24601/zombie-basic'
          GitTopic.accept
          git_branch.should               == 'master'
          git_branches.should_not         include( 'review/user24601/zombie-basic' )
          git_remote_branches.should_not  include( 'review/user24601/zombie-basic' )

          git_head.should                 == '0ce06c616769768f09f5e629cfcc68eabe3dee81'
          git_origin_master.should        == '0ce06c616769768f09f5e629cfcc68eabe3dee81'
        end

        it "should provide feedback to the user" do
          GitTopic.accept
          $?.success?.should          == true
          @output.should_not          be_nil
          @output.should_not          be_empty
        end

        it "should fail if the working tree is dirty" do
          dirty_branch!
          λ{ GitTopic.accept }.should    raise_error
        end
      end
    end

    # Normally the user should not even wind up in this state because +review+
    # will complain if the branch does not automatically fast-forward.
    describe "while on a review branch that does not FF" do
      before( :each ) do
        use_repo 'in-progress'
        GitTopic.review 'user24601/zombie-basic'
        system "
          git checkout master > /dev/null 2> /dev/null && 
          git merge origin/wip/prevent-ff > /dev/null 2> /dev/null
        "
        @original_git_Head    = git_head
        system "git checkout --quiet review/user24601/zombie-basic"
      end

      it "should refuse to accept the review branch" do
        git_branch.should                 == 'review/user24601/zombie-basic'
        λ{ GitTopic.accept }.should  raise_error
        git_branch.should                 == 'review/user24601/zombie-basic'
        git_remote_branches.should        include( 'review/user24601/zombie-basic' )

        system "git checkout master > /dev/null 2> /dev/null"
        git_head.should                   == @original_git_Head
      end
    end

    describe "while not on a review branch" do
      before( :each ) { use_repo 'in-progress' }

      it "should fail" do
        λ{ GitTopic.accept }.should    raise_error
      end
    end
  end

end
