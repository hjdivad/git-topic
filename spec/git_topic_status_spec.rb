require 'spec_helper'


describe GitTopic do

  describe "#status" do

    describe "with pending review branches" do

      before( :each ) { use_repo 'in-progress' }
      after( :each )  { Dir.chdir '..' }


      it "should not show my review branches, but it should show others'" do
        git_remote_branches.should      include "review/#{@user}/pirates"

        GitTopic.status
        @output.should_not      be_nil

        @output.should_not      =~ /^#\s*pirates\s*$/m
        @output.should          =~ /^#\s*ninja-basic\s*$/m
        @output.should          =~ /^#\s*zombie-basic\s*$/m
      end

      it "should not show others' rejected topics" do
        git_remote_branches.should      include 'review/user24601/ninja-basic'
        GitTopic.review 'user24601/ninja-basic'
        GitTopic.reject
        git_remote_branches.should_not  include 'review/user24601/ninja-basic'
        git_remote_branches.should      include 'rejected/user24601/ninja-basic'

        @output.clear
        GitTopic.status
        @output.should                  =~ %r{^\s*(#.*)}m
        status_output                   = $1
        status_output.should_not        =~ %r{ninja-basic}
      end

      it "
        should show my rejected topics, and note that they have comments, when
        they do.
      " do
        git_remote_branches.should      include "rejected/#{@user}/krakens"
        GitTopic.status
        @output.should_not      be_nil

        @output.should          =~ /^#\s*krakens\s*\(reviewer comments\)\s*$/m
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

end
