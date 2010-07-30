require 'spec_helper'


describe GitTopic do
  
  describe "#review" do

    describe "with no review branches" do
      before( :each ) { use_repo 'fresh' }

      it "should report that there is nothing to do" do
        git_remote_branches.each do |b|
          b.should_not    =~ /review/
        end

        GitTopic.review
        @output.should    =~ /nothing to review/
      end
    end

    describe "with exactly one review branch" do
      before( :each ) do
        use_repo 'in-progress'
        seen_a_review_b = false
        git_remote_branches.each do |b|
          if b =~ %r{review/user24601/(?!zombie-basic)}
            system "git push origin :refs/heads/#{b} > /dev/null 2> /dev/null"
          end
        end
      end

      it "should switch to the sole review branch when given no arguments." do
        git_remote_branches.select do |branch|
          branch =~ %r{review/user24601}
        end.should                      == ['review/user24601/zombie-basic']
        GitTopic.review
        git_branch.should               == 'review/user24601/zombie-basic'
        git_branch_remote.should        == 'origin'
        git_branch_merge.should         == 'refs/heads/review/user24601/zombie-basic'
      end
    end

    describe "with some review branches" do
      before( :each ) { use_repo 'in-progress' }

      it "
        should create a local tracking branch for the oldest remote review
        branch if none was specified
      ".oneline do

        git_remote_branches.should      include 'review/user24601/zombie-basic'
        GitTopic.review
        git_branch.should               == 'review/user24601/zombie-basic'
        git_branch_remote.should        == 'origin'
        git_branch_merge.should         == 'refs/heads/review/user24601/zombie-basic'
      end

      it "should use the local tracking branch, if one exists" do
        git_remote_branches.should      include 'review/user24601/zombie-basic'

        GitTopic.review 'zombie-basic'
        system "git checkout master > /dev/null 2> /dev/null"

        git_branch.should                       == "master"
        lambda do
          GitTopic.review 'zombie-basic' 
        end.should_not                          raise_error
        git_branch.should                       == "review/user24601/zombie-basic"
      end

      it "should provide feedback to the user" do
        GitTopic.review
        $?.success?.should          == true
        @output.should_not          be_nil
        @output.should_not          be_empty
      end

      it "should create a local tracking branch for the specified topic" do
        git_remote_branches.should      include 'review/user24601/ninja-basic'
        GitTopic.review( 'user24601/ninja-basic' )
        git_branch.should               == 'review/user24601/ninja-basic'
        git_branch_remote.should        == 'origin'
        git_branch_merge.should         == 'refs/heads/review/user24601/ninja-basic'
      end

      it "
        should accept only a topic arg (vice <user>/<topic>) when the topic is
        unambiguous.
      ".oneline do
        git_remote_branches.should      include 'review/user24601/ninja-basic'
        GitTopic.review( 'ninja-basic' )
        git_branch.should               == 'review/user24601/ninja-basic'
        git_branch_remote.should        == 'origin'
        git_branch_merge.should         == 'refs/heads/review/user24601/ninja-basic'
      end

      it "should handle fully-qualified topic args" do
        git_remote_branches.should      include 'review/user24601/ninja-basic'
        lambda{ GitTopic.review( 'review/user24601/ninja-basic' )}.should_not raise_error
        git_branch.should               == 'review/user24601/ninja-basic'
        git_branch_remote.should        == 'origin'
        git_branch_merge.should         == 'refs/heads/review/user24601/ninja-basic'
      end

      it "should error if an illegal topic is specified" do
        lambda{ GitTopic.review( 'fakeuser/faketopic' )}.should raise_error
      end
    end

  end

end
