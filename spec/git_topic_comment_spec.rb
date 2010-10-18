require 'spec_helper'

GeneralCommentOnly = %Q{
Spec 123:           I have some general comments, mostly relating to the quality
                    of our zombie-control policies.  Basically, they're not
                    working.
}.strip

FirstComment = %Q{
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

FirstCommentUpdated = %Q{
Spec 123:           I agree, though I wonder if maybe we've become a little too
                    obsessed with bacon. Umm, wait, sorry, wrong thread.
                                There is no way this is going to work.  Sorry, but there's just not.

./ninjas

  Line 2
    Spec 123:       I suggest we do the following instead:
                      everyone.giveup
                    This should take care of our issues with zombies.
}.strip

FirstCommentReply = %Q{
# Spec 123:         I have some general comments, mostly relating to the quality
#                   of our zombie-control policies.  Basically, they're not
#                   working.

I agree, though I wonder if maybe we've become a little too obsessed with bacon. Umm, wait, sorry, wrong thread.

#
# ./zombies
#
#   Line 2
#     Spec 123:     I suggest we do the following instead:
#                       zombies.each{ |z| reason_with( z )}
#                       zomies.select do |z|
#                         z.unconvinced?
#                       end.each do |z|
#                         destroy z
#                       end
#                   This should take care of our issues with zombies.
            There is no way this is going to work.  Sorry, but there's just not.
}.strip

SecondComment = %Q{
Spec 123:           I have some general comments, mostly relating to the quality
                    of our zombie-control policies.  Basically, they're not
                    working.
Spec 123:           I agree, though I wonder if maybe we've become a little too
                    obsessed with bacon. Umm, wait, sorry, wrong thread.

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
    Spec 123:       There is no way this is going to work.  Sorry, but there's
                    just not.
}.strip

SecondCommentWithReply = %Q{
Spec 123:           I have some general comments, mostly relating to the quality
                    of our zombie-control policies.  Basically, they're not
                    working.
Spec 234:           I agree, though I wonder if maybe we've become a little too
                    obsessed with bacon. Umm, wait, sorry, wrong thread.

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
    Spec 234:       There is no way this is going to work.  Sorry, but there's
                    just not.
}.strip


describe GitTopic do

  describe "#comment" do

    before( :each ) do
      GitTopic.stub!( :invoke_git_editor ) do |path|
        File.open( path, 'w' ) do |f|
          f.puts %Q{
            I have some general comments, mostly relating to the quality of our
            zombie-control policies.  Basically, they're not working.
          }.unindent
        end
      end
    end

    describe "on a review branch with no comments" do

      before( :each ) do
        use_repo 'in-progress' 
        GitTopic.review 'user24601/zombie-basic'
      end


      it "should fail if the diff includes added lines not prefixed with #" do
        File.open( 'zombies', 'a' ){ |f| f.puts "a line" }
        lambda{ GitTopic.comment }.should     raise_error
      end

      it "should fail if the diff includes removed lines" do
        File.open( 'zombies', 'w' ){ |f| f.puts '' }
        lambda{ GitTopic.comment }.should     raise_error
      end

      it "should fail if there are new files." do
        File.open( 'new-untracked-file', 'w' ){ |f| f.puts 'content' }
        system "git add new-untracked-file > /dev/null 2> /dev/null"
        lambda{ GitTopic.comment }.should     raise_error
      end

      it "should fail if files have been deleted." do
        FileUtils.rm 'zombies'
        lambda{ GitTopic.comment }.should     raise_error
      end

      it "should fail if file modes have been modified." do
        FileUtils.chmod 0744, 'zombies'
        lambda{ GitTopic.comment }.should     raise_error
      end

      it "should fail if git config user.name is not set" do
        GitTopic::Git::ClassMethods.class_variable_set( "@@git_author_name_short", nil )
        GitTopic.stub( :` ) do |cmd|
          if cmd =~ %r{^git config user.name}
            $?.instance_eval do
              def success?; false; end
            end
            ""
          else
            %x{#{cmd}}
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
        lambda{ GitTopic.comment }.should     raise_error
      end

      it "should allow general comments if there is no diff" do
        git_diff.should                                 be_empty

        GitTopic.should_receive( :invoke_git_editor ).once
        GitTopic.should_receive(
          :git_author_name_short
        ).once.and_return( "Spec 123" )

        lambda{ GitTopic.comment }.should_not           raise_error

        git_notes_list(
          "refs/notes/reviews/user24601/zombie-basic"
        ).should_not                                    be_empty

        git_notes_show(
          "refs/notes/reviews/user24601/zombie-basic"
        ).should                                        == GeneralCommentOnly
      end

      it "
        should convert added lines to notes, formatted appropriately, and save
        them in refs/notes/reviews/<user>/<topic>.
      ".oneline do
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

        lambda{ GitTopic.comment }.should_not           raise_error
        git_notes_list(
          "refs/notes/reviews/user24601/zombie-basic"
        ).should_not                                    be_empty

        git_notes_show(
          "refs/notes/reviews/user24601/zombie-basic"
        ).should                                        == FirstComment

        git_diff.should                                 be_empty
      end

    end


    describe "on a review branch with existing comments" do

      before( :each ) do
        use_repo( 'in-progress' )
        GitTopic.review 'user24601/ninja-basic'

        GitTopic.stub!( :invoke_git_editor ) do |path|
          File.open( path, 'w' ) do |f|
            f.write FirstCommentReply
          end
        end
      end


      it "should fail if the working tree is dirty" do
        File.open( 'ninjas', 'a' ) do |f|
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

        lambda{ GitTopic.comment }.should             raise_error
      end

      it "should replace existing comments with --force" do
        File.open( 'ninjas', 'a' ) do |f|
          f.puts %Q{
            # I suggest we do the following instead:
            #   everyone.giveup
            # This should take care of our issues with zombies.
          }.unindent
        end

        GitTopic.should_receive( :invoke_git_editor ).once
        GitTopic.should_receive(
          :git_author_name_short
        ).once.and_return( "Spec 123" )


        lambda do
          GitTopic.comment  :force_update => true
        end.should_not                                  raise_error

        git_notes_list(
          "refs/notes/reviews/user24601/ninja-basic"
        ).should_not                                    be_empty

        git_notes_show(
          "refs/notes/reviews/user24601/ninja-basic"
        ).should                                        == FirstCommentUpdated

        git_diff.should                                 be_empty
      end

      it "should append comments (without --force-update)" do
        git_notes_list(
          "refs/notes/reviews/user24601/ninja-basic"
        ).should_not                                    be_empty
        git_notes_show(
          "refs/notes/reviews/user24601/ninja-basic"
        ).should                                        == FirstComment

        GitTopic.should_receive( :invoke_git_editor ).once
        GitTopic.should_receive(
          :git_author_name_short
        ).once.and_return( "Spec 123" )

        lambda{ GitTopic.comment }.should_not           raise_error
        git_notes_list(
          "refs/notes/reviews/user24601/ninja-basic"
        ).should_not                                    be_empty

        git_notes_show(
          "refs/notes/reviews/user24601/ninja-basic"
        ).should                                        == SecondComment
      end

      it "should report success to the user" do
        GitTopic.should_receive( :invoke_git_editor ).once
        GitTopic.should_receive(
          :git_author_name_short
        ).once.and_return( "Spec 123" )

        lambda{ GitTopic.comment }.should_not           raise_error
        @output.should                                  =~ /comments have been saved/i
      end

      it "should fail (and report the failure) if the user entered no comments" do
        git_notes_list(
          "refs/notes/reviews/user24601/ninja-basic"
        ).should_not                                    be_empty
        git_notes_show(
          "refs/notes/reviews/user24601/ninja-basic"
        ).should                                        == FirstComment

        GitTopic.stub!( :invoke_git_editor ) do |path|
          File.open( path, 'w' ) do |f|
            f.write FirstComment.lines.map{ |l| "# #{l}" }.join
          end
        end
        GitTopic.should_receive( :invoke_git_editor ).once
        GitTopic.should_receive(
          :git_author_name_short
        ).once.and_return( "Spec 123" )

        lambda{ GitTopic.comment }.should_not           raise_error
        git_notes_list(
          "refs/notes/reviews/user24601/ninja-basic"
        ).should_not                                    be_empty

        git_notes_show(
          "refs/notes/reviews/user24601/ninja-basic"
        ).should                                        == FirstComment

        @output.should                                  =~ /nothing to save/i
      end
    end


    describe "on a wip branch with no comments" do
      before( :each ) { use_repo 'in-progress' }

      it "should report that there is nothing to do" do
        GitTopic.work_on 'pirates-advanced'
        lambda{ GitTopic.comment }.should_not           raise_error

        git_notes_list(
          "refs/notes/reviews/#{@user}/pirates-advanced"
        ).should                                        be_empty
        @output.should_not                              be_empty
      end
    end


    describe "on a wip branch with existing comments" do
      before( :each ) do
        use_repo              'in-progress'
        GitTopic.work_on      'rejected/krakens'

        GitTopic.stub!( :invoke_git_editor ) do |path|
          File.open( path, 'w' ) do |f|
            f.puts FirstCommentReply
          end
        end
      end


      it "should fail if the working tree is dirty" do
        File.open( 'kraken', 'a' ) do |f|
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

        lambda{ GitTopic.comment }.should               raise_error
      end

      it "should append comments" do
        GitTopic.should_receive( :invoke_git_editor ).once
        GitTopic.should_receive(
          :git_author_name_short
        ).once.and_return( "Spec 234" )

        lambda{ GitTopic.comment }.should_not           raise_error
        git_notes_list(
          "refs/notes/reviews/#{@user}/krakens"
        ).should_not                                    be_empty

        git_notes_show(
          "refs/notes/reviews/#{@user}/krakens"
        ).should                                        == SecondCommentWithReply
      end
    end

  end
end

