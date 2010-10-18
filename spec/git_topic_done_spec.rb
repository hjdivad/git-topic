require 'spec_helper'


describe GitTopic do
  
  describe "#done" do

    describe "while on a branch with no local refs/notes" do
      before( :each )   { use_repo 'in-progress' }
      
      it "should not error on a missing refs/notes" do
        File.exists?(
          "./.git/refs/notes/reviews/"
        ).should                                                == true
        FileUtils.rm_rf "./.git/refs/notes/"
        lambda{ GitTopic.work_on 'krakens' }.should_not         raise_error
        lambda{ GitTopic.done }.should_not                      raise_error
      end
    end

    describe "in in-progress" do

      before( :each ) { use_repo 'in-progress' }

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

        it "should push any replies to review comments" do
          GitTopic.stub!( :invoke_git_editor ) do |path|
            File.open( path, 'w' ) do |f|
              f.puts %Q{
                I have some general comments, mostly relating to the quality of our
                zombie-control policies.  Basically, they're not working.
              }.unindent
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
            }.unindent
          end
          GitTopic.should_receive( :invoke_git_editor ).once
          GitTopic.should_receive(
            :git_author_name_short
          ).once.and_return( "Spec 123" )

          old_review = File.read(
            "../origin/refs/notes/reviews/#{@user}/krakens"
          )

          lambda do
            GitTopic.work_on  'krakens'
            cmd = [
              "echo 'harder than you might think' >> kraken",
              "git commit kraken -m 'working on krakens'",
            ].join( " && " )
            cmd << " 2> /dev/null > /dev/null"
            system cmd
            GitTopic.comment
            GitTopic.done
          end.should_not                          raise_error

          new_review = File.read(
            "../origin/refs/notes/reviews/#{@user}/krakens"
          )
          new_review.should_not                   == old_review
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
