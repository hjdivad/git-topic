require 'spec_helper'


describe GitTopic do
  
  describe "#reject" do

    describe "while on a review branch" do
      before( :each ) do
        use_repo 'in-progress'
        GitTopic.review 'user24601/zombie-basic'
      end
      after( :each ) { Dir.chdir '..' }

      describe "with no specified argument" do
        it "
          should move branch to the rejected namespace and destroy the local and
          remote review branches
        ".oneline do

          git_branch.should               == 'review/user24601/zombie-basic'
          GitTopic.reject
          git_branch.should               == 'master'
          git_branches.should_not         include( 'review/user24601/zombie-basic' )
          git_remote_branches.should_not  include( 'review/user24601/zombie-basic' )
          git_remote_branches.should      include( 'rejected/user24601/zombie-basic' )
        end

        it "should provide feedback to the user" do
          GitTopic.reject
          $?.success?.should          == true
          @output.should_not          be_nil
          @output.should_not          be_empty
        end

        it "should fail if the working tree is dirty" do
          dirty_branch!
          lambda{ GitTopic.reject }.should    raise_error
        end
      end
    end
    
    describe "while not on a review branch" do
      before( :each ) { use_repo 'in-progress' }
      after( :each ) { Dir.chdir '..' }

      it "should fail" do
        lambda{ GitTopic.reject }.should    raise_error
      end
    end

  end

end
