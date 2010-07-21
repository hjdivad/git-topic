require 'spec_helper'

require 'fileutils'


describe GitTopic do

  before( :all ) do
    @starting_dir   = Dir.pwd
    @user           = ENV['USER'] || `whoami`
  end

  before( :each ) do
    # setup the directories
    FileUtils.rm_rf   './tmp'
    FileUtils.mkdir   './tmp'

    # Copy our repos into tmp
    %w(fresh in-progress).each do |d|
      FileUtils.mkdir "./tmp/#{d}"
      FileUtils.cp_r "spec/template/#{d}",          "./tmp/#{d}/.git"
    end
    FileUtils.cp_r "spec/template/origin",          './tmp'
    FileUtils.cp_r "spec/template/origin-fresh",    './tmp'

    %w(origin origin-fresh fresh in-progress).each do |repo|
      # set template branches to their proper name (i.e. matching @user)
      Dir.chdir "./tmp/#{repo}"
      git_branches.each do |orig_name|
        new_name = orig_name.gsub( 'USER', @user )
        system(
          "git branch -m #{orig_name} #{new_name}"
        ) unless orig_name == new_name
        system "git fetch --prune > /dev/null 2> /dev/null"
      end
      Dir.chdir @starting_dir
    end
    Dir.chdir         './tmp'

    # capture output
    @output         = ''
    @err            = ''
    $stdout.stub!( :write ) { |*args| @output.<<( *args )}
    $stderr.stub!( :write ) { |*args| @err.<<( *args )}
  end

  after( :each ) { Dir.chdir @starting_dir }


  # helpers # {{{

  def use_repo( repo )
    Dir.chdir( repo )
    # Exit if e.g. GIT_DIR is set
    raise "Spec error" unless `git rev-parse --git-dir`.chomp == '.git'
  end


  def git_branch
    all_branches    = `git branch --no-color`.split( "\n" )
    current_branch  = all_branches.find{|b| b =~ /^\*/}

    current_branch[ 2..-1 ] unless current_branch.nil?
  end

  def git_head
    `git rev-parse HEAD`.chomp
  end

  def git_origin_master
    `git rev-parse origin/master`.chomp
  end

  def git_config( key )
    `git config #{key}`.chomp
  end

  def git_branch_merge
    git_config "branch.#{git_branch}.merge"
  end

  def git_branch_remote
    git_config "branch.#{git_branch}.remote"
  end

  def git_branches
    `git branch --no-color`.split( "\n" ).map do |bn|
      bn.gsub /^\*?\s*/, ''
    end
  end

  def git_remote_branches
    `git branch -r --no-color`.split( "\n" ).map do |bn|
      bn.gsub! %r{^\s*origin/}, ''
      bn.gsub! %r{ ->.*$}, ''
      bn
    end
  end

  # }}}

  describe "#work_on" do

      share_examples_for "#work_on general cases" do

        it "
          should trim namespaces from args and output a warning
        ".oneline do

          git_branch.should_not                   == "wip/davidjh/topic"
          GitTopic.work_on "wip/#{@user}/topic"
          git_branch.should                       == "wip/davidjh/topic"
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

  describe "#done" do

    describe "in in-progress" do

      before( :each ) { use_repo 'in-progress' }
      after( :each )  { Dir.chdir '..' }

      describe "without an argument" do

        it "should fail if the working tree is dirty" do
          GitTopic.work_on 'zombie-basic'
          File.open( 'foo', 'w' ){|f| f.puts "some content" }
          system "git add -N foo"

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

  describe "#status" do

    describe "with pending review branches" do

      before( :each ) { use_repo 'in-progress' }
      after( :each )  { Dir.chdir '..' }


      it "should not show my review branches, but it should show others'" do
        git_remote_branches.should      include 'review/davidjh/pirates'

        GitTopic.status
        @output.should_not      be_nil

        @output.should_not      =~ /^#\s*pirates\s*$/m
        @output.should          =~ /^#\s*ninja-basic\s*$/m
        @output.should          =~ /^#\s*zombie-basic\s*$/m
      end

      pending "should not show others' rejected branches"

      it "should not show others' rejected topics" do
        git_remote_branches.should      include 'review/user24601/ninja-basic'
        GitTopic.review 'user24601/ninja-basic'
        GitTopic.reject
        git_remote_branches.should_not  include 'review/user24601/ninja-basic'
        git_remote_branches.should      include 'rejected/user24601/ninja-basic'

        @output.clear
        GitTopic.status
        @output.should_not              =~ %r{ninja-basic}
      end

      it "should show my rejected topics" do
        git_remote_branches.should      include 'rejected/davidjh/krakens'
        GitTopic.status
        @output.should_not      be_nil

        @output.should          =~ /^#\s*krakens\s*$/m
      end

    end

    describe "passed the --prepended flag" do
      before( :each ) { use_repo 'in-progress' }
      after( :each )  { Dir.chdir '..' }

      it "should invoke git status before producing its output" do
        GitTopic.status( :prepended => true )
        @output.should_not      be_nil
        @output.should          =~ /# On branch master/
      end
    end
  end

  describe "#review" do

    describe "with no review branches" do
      before( :each ) { use_repo 'fresh' }
      after( :each )  { Dir.chdir '..' }

      it "should report that there is nothing to do" do
        git_remote_branches.each do |b|
          b.should_not    =~ /review/
        end

        GitTopic.review
        @output.should    =~ /nothing to review/
      end
    end

    describe "with some review branches" do
      before( :each ) { use_repo 'in-progress' }
      after( :each )  { Dir.chdir '..' }

      it "
        should create a local tracking branch for the oldest remote review
        branch if none was specified
      " do

        git_remote_branches.should      include 'review/user24601/zombie-basic'
        GitTopic.review
        git_branch.should               == 'review/user24601/zombie-basic'
        git_branch_remote.should        == 'origin'
        git_branch_merge.should         == 'refs/heads/review/user24601/zombie-basic'
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

      it "should error if an illegal topic is specified" do
        lambda{ GitTopic.review( 'fakeuser/faketopic' )}.should raise_error
      end
    end

  end

  describe "#accept" do

    describe "while on a review branch" do
      before( :each ) do
        use_repo 'in-progress'
        GitTopic.review 'user24601/zombie-basic'
      end
      after( :each ) { Dir.chdir '..' }

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
      end
    end

    describe "while on a review branch that does not FF" do
      before( :each ) do
        use_repo 'in-progress'
        system "
          git checkout master > /dev/null 2> /dev/null && 
          git merge origin/wip/prevent-ff > /dev/null 2> /dev/null
        "
        @original_git_Head    = git_head
        GitTopic.review 'user24601/zombie-basic'
      end
      after( :each ) { Dir.chdir '..' }

      it "should refuse to accept the review branch" do
        git_branch.should                 == 'review/user24601/zombie-basic'
        lambda{ GitTopic.accept }.should  raise_error
        git_branch.should                 == 'review/user24601/zombie-basic'
        git_remote_branches.should        include( 'review/user24601/zombie-basic' )

        system "git checkout master > /dev/null 2> /dev/null"
        git_head.should                   == @original_git_Head
      end
    end

    describe "while not on a review branch" do
      before( :each ) { use_repo 'in-progress' }
      after( :each ) { Dir.chdir '..' }

      it "should fail" do
        lambda{ GitTopic.accept }.should    raise_error
      end
    end
  end

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


  describe "#install_aliases" do
    it "should install aliases" do
      GitTopic.install_aliases  :local => true
      git_config( 'alias.work-on' ).should    == 'topic work-on'
      git_config( 'alias.done' ).should       == 'topic done'
      git_config( 'alias.review' ).should     == 'topic review'
      git_config( 'alias.accept' ).should     == 'topic accept'
      git_config( 'alias.reject' ).should     == 'topic reject'

      git_config( 'alias.w' ).should          == 'topic work-on'
      git_config( 'alias.r' ).should          == 'topic review'
      git_config( 'alias.st' ).should         == 'topic status --prepended'
    end

    it "should provide feedback to the user" do
      GitTopic.install_aliases  :local => true
      $?.success?.should          == true
      @output.should_not          be_nil
      @output.should_not          be_empty
    end

  end
end

