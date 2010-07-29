require 'spec_helper'

RejectFirstComment = %Q{
Spec 123:           I have some general comments, mostly relating to the quality
                    of our zombie-control policies.  Basically, they're not
                    working.

./zombies

  Line 2
    Spec 123:       I suggest we do the following instead:
                        zombies.each{ |z| reason_with( z )}
                        zomies.select do |z|
                          z.unconvinced?
                        end.each do |z|
                          destroy z
                        end
                    This should take care of our issues with zombies.
}.strip

describe GitTopic do
  
  describe "#reject" do


    describe "while on a review branch in a repo with no local refs/notes" do
      before( :each )   { use_repo 'in-progress' }
      after( :each )    { Dir.chdir '..' }

      it "should not error on a missing refs/notes" do
        File.exists?(
          "./.git/refs/notes/reviews/"
        ).should                                    == true
        FileUtils.rm_rf "./.git/refs/notes/"
        lambda{ GitTopic.review }.should_not        raise_error
        lambda{ GitTopic.reject }.should_not        raise_error
      end
    end


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

        it "should push any review comments" do
          GitTopic.stub!( :invoke_git_editor ) do |path|
            File.open( path, 'w' ) do |f|
              f.puts %Q{
                I have some general comments, mostly relating to the quality of our
                zombie-control policies.  Basically, they're not working.
              }.cleanup
            end
          end

          File.open( 'zombies', 'a' ) do |f|
            f.puts %Q{
              # I suggest we do the following instead:
              #     zombies.each{ |z| reason_with( z )}
              #     zomies.select do |z|
              #       z.unconvinced?
              #     end.each do |z|
              #       destroy z
              #     end
              # This should take care of our issues with zombies.
            }.cleanup
          end
          GitTopic.should_receive( :invoke_git_editor ).once
          GitTopic.should_receive(
            :git_author_name_short
          ).once.and_return( "Spec 123" )

          File.exists?(
            "../origin/refs/notes/reviews/user24601/zombie-basic"
          ).should                                == false

          lambda do
            GitTopic.comment
            GitTopic.reject
          end.should_not                          raise_error

          File.exists?(
            "../origin/refs/notes/reviews/user24601/zombie-basic"
          ).should                                == true
        end

        it "should provide feedback to the user" do
          GitTopic.reject
          $?.success?.should          == true
          @output.should_not          be_nil
          @output.should_not          be_empty
        end

        it "should auto-save comments with the --save-comments options" do
          GitTopic.stub!( :invoke_git_editor ) do |path|
            File.open( path, 'w' ) do |f|
              f.puts %Q{
                I have some general comments, mostly relating to the quality of our
                zombie-control policies.  Basically, they're not working.
              }.cleanup
            end
          end

          File.open( 'zombies', 'a' ) do |f|
            f.puts %Q{
              # I suggest we do the following instead:
              #     zombies.each{ |z| reason_with( z )}
              #     zomies.select do |z|
              #       z.unconvinced?
              #     end.each do |z|
              #       destroy z
              #     end
              # This should take care of our issues with zombies.
            }.cleanup
          end
          GitTopic.should_receive( :invoke_git_editor ).once
          GitTopic.should_receive(
            :git_author_name_short
          ).once.and_return( "Spec 123" )

          lambda do
            GitTopic.reject :save_comments => true 
          end.should_not                                  raise_error

          git_notes_list(
            "refs/notes/reviews/user24601/zombie-basic"
          ).should_not                                    be_empty

          git_notes_show(
            "refs/notes/reviews/user24601/zombie-basic",
            "origin/rejected/user24601/zombie-basic"
          ).should                                        == RejectFirstComment
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
