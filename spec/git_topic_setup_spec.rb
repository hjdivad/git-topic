require 'spec_helper'


describe GitTopic do

  describe "#setup" do
    before( :each ) { use_repo 'in-progress' }


    it "should install reviews refspec for origin" do

      %x{ 
        git config --get-all remote.origin.fetch
      }.should_not                            =~ %r{\+refs/notes}

      GitTopic.setup

      %x{ 
        git config --get-all remote.origin.fetch
       }.should                                =~ %r{refs/notes}
    end

    it "should configure notes.rewriteRef" do

     %x{ 
        git config --get-all notes.rewriteRef
      }.should_not                            =~ %r{refs/notes}

      GitTopic.setup

      %x{ 
         git config --get-all notes.rewriteRef
       }.should                                =~ %r{refs/notes}
    end

    it "should configure notes.rewriteRef even if refspecs are already set up" do

      system "git config --add remote.origin.fetch refs/notes/reviews/*:refs/notes/reviews/*"
      GitTopic.setup
      %x{ 
         git config --get-all notes.rewriteRef
       }.should                                =~ %r{refs/notes}
    end

    it "should configure refspecs even if notes.rewriteRef is already set up" do
      system "git config --add notes.rewriteRef refs/notes/reviews/*"
      GitTopic.setup
      %x{ 
        git config --get-all remote.origin.fetch
       }.should                                =~ %r{refs/notes}
    end

    it "should be idempotent" do
      File.exists?( ".git/config" ).should     == true
      GitTopic.setup
      content = File.read( ".git/config" )
      GitTopic.setup

      File.read( ".git/config" ).should         == content
    end
  end

  describe "for any non --help command" do

    describe "when not in a git repository" do
      before( :each ) do
        Dir.chdir '/tmp'
      end

      it "should not whine" do
        git_dir.should                          == ""
          GitTopic.run
          @err.should_not                       =~ /setup/
      end
    end

    describe "
      when in a git repository that is neither setup nor configured to nowhine
    ".oneline do

      before( :each ) { use_repo 'in-progress' }

      it "should ask the user to #setup or configure no-whine" do
        with_argv do
          GitTopic.run
          @err.should                           =~ /setup/
        end
      end
    end

    describe "
      when in a git repository that is set up for fetching, but not rewriting
      notes
    ".oneline do

      before( :each ) { use_repo 'in-progress' }

      it "should ask the user to #setup or configure no-whine" do

        system "git config --add remote.origin.fetch refs/notes/reviews/*:refs/notes/reviews/*"

        with_argv do
          GitTopic.run
          @err.should                       =~ /setup/
        end
      end
    end

    describe "when in a git repository configured for nowhining" do
      before( :each ) { use_repo 'in-progress' }

      it "
        should not whine, even when refs are not set up and notes.rewriteRef is
        not setup
      ".oneline do
        system "git config topic.checkForNotesRef false > /dev/null 2> /dev/null"
        GitTopic.run
        @err.should_not                         =~ /setup/
      end
    end

    describe "when in a git repository that is #setup" do

      before( :each ) { use_repo 'in-progress' }

      it "
        should not whine, regardless of whether it is configured for whining or
        not
      ".oneline do

        GitTopic.setup
        GitTopic.run
        @err.should_not                         =~ /setup/
      end
    end
  end

end
