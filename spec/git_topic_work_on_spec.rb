require 'spec_helper'


describe GitTopic do

  describe "#work_on" do

    share_examples_for "#work_on general cases" do

      it "should trim namespaces for a user's wip branch".oneline do

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
        λ { GitTopic.work_on( nil )}.should  raise_error
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

      it_should_behave_like "#work_on general cases"


      it "should trim namespaces for a different user's wip branch" do

        git_branch.should_not                   == "wip/user24601/pirates-with-hooks"
        GitTopic.work_on "wip/user24601/pirates-with-hooks"
        git_branch.should                       == "wip/user24601/pirates-with-hooks"
      end

      it "should switch to (rather than create) an existing topic branch" do
        git_branches.should include( "wip/#{@user}/zombie-basic" )
        λ{ GitTopic.work_on  'zombie-basic' }.should_not raise_error

        git_branch.should   == "wip/#{@user}/zombie-basic"
      end

      it "should accept upstream as an argument" do
        git_remote_branches.should include( "review/#{@user}/pirates" )
        λ do
          GitTopic.work_on  'pirates-etc',
                            :upstream => "origin/review/#{@user}/pirates"
        end.should_not raise_error

        git_branch.should   == "wip/#{@user}/pirates-etc"
        git_head.should     == 'c0838ed2ee8f2e83c8bda859fc5e332b92f0a5a3'
      end

      describe "--continue flag" do
        describe "when one has an as-yet unaccepted review branch" do
          it "should set <upstream> to the latest such branch" do
            λ do
              GitTopic.work_on  'pirates-etc'
              dirty_branch!
              system "git add . && git commit -a -m 'arrrrr' > /dev/null 2> /dev/null"
              GitTopic.done
            end.should_not        raise_error

            head = git_remote   "origin/review/#{@user}/pirates-etc"
            head.should_not     == '331d827fd47fb234af54e3a4bbf8c6705e9116cc'

            GitTopic.work_on    'yet-more-pirates',
                                :continue => true

            git_head.should     == head
          end
        end

        describe "when one has no pending review branches" do
          before( :each ){ use_repo 'fresh' }

          it "should have no effect" do
            GitTopic.work_on  'yet-more-pirates',
                              :continue => true

            git_head.should   == '331d827fd47fb234af54e3a4bbf8c6705e9116cc'
          end
        end

        describe "when an explicit <upstream> is also supplied" do
          it "should fail with an error" do
            λ do
              GitTopic.work_on  'pirates-etc',
                                :continue => true,
                                :upstream => "origin/review/#{@user}/pirates"
            end.should          raise_error
          end
        end
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
        git_remote(
          "wip/#{@user}/krakens"
        ).should                          == '44ffd9c9c8b52b201659e3ad318cdad6ec836b46'
      end

      it "should work when HEAD points to a commit downstream of master" do
        GitTopic.work_on  'new-topic'
        dirty_branch!
        system "git add . && git commit -q -a -m 'Non-FF' "

        git_remote_branches.should        include( "rejected/#{@user}/krakens" )
        GitTopic.work_on    'krakens'
        git_branch.should                 == "wip/#{@user}/krakens"
        git_remote_branches.should_not    include( "rejected/#{@user}/krakens" )
        git_remote_branches.should        include( "wip/#{@user}/krakens" )
        git_head.should                   == '44ffd9c9c8b52b201659e3ad318cdad6ec836b46'
        git_remote(
          "wip/#{@user}/krakens"
        ).should                          == '44ffd9c9c8b52b201659e3ad318cdad6ec836b46'
      end

      it "
        should report the presence of comments to the user, when the topic has
        been rejected.
      ".oneline do

        git_remote_branches.should        include( "rejected/#{@user}/krakens" )
        GitTopic.work_on    'krakens'
        @output.should                    =~ /comments/
      end

      it "
        should not report the presence of comments, for comments that belong to
        commits from an earlier topic branch of the same name
      ".oneline do

        git_remote_branches.should        include( "rejected/#{@user}/krakens" )
        refspecs = "origin/rejected/#{@user}/krakens:master :rejected/#{@user}/krakens"
        system "git push origin #{refspecs} > /dev/null 2> /dev/null"
        git_remote_branches.should_not    include( "rejected/#{@user}/krakens" )

        GitTopic.work_on    'krakens'
        git_head.should                   == '331d827fd47fb234af54e3a4bbf8c6705e9116cc'
        @output.should_not                =~ /comments/
      end

      it "
        should use (and then destroy) the review branch for the topic, if one
        exists
      ".oneline do

        git_remote_branches.should        include( "review/#{@user}/pirates" )
        GitTopic.work_on    'pirates'
        git_branch.should                 == "wip/#{@user}/pirates"
        git_remote_branches.should_not    include( "review/#{@user}/pirates" )
        git_remote_branches.should        include( "wip/#{@user}/pirates" )
        git_head.should                   == 'c0838ed2ee8f2e83c8bda859fc5e332b92f0a5a3'
      end

    end
  end
end
