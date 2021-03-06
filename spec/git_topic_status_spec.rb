# encoding: utf-8
require 'spec_helper'


describe GitTopic do

  describe "#status" do

    describe "with pending review branches" do

      before( :each ) { use_repo 'in-progress' }


      it "should not show my review branches, but it should show others'" do
        git_remote_branches.should      include "review/#{@user}/pirates"

        GitTopic.status
        @output.should_not      be_nil

        @output.should_not      =~ /^#\s*pirates\s*$/m
        @output.should          =~ /2 topics/m
        @output.should          =~ /^#\s*ninja-basic\s*/m
        @output.should          =~ /^#\s*zombie-basic\s*/m
      end

      it "should show the age of others' unreviewed branches" do

        jul_12 = Date.parse( "12 July 2010" )
        Date.should_receive(:today).at_least(:once).and_return  jul_12
        GitTopic.status

        @output.should          =~ /5 days/
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

      it "should invoke git status before producing its output" do
        GitTopic.status( :prepended => true )
        @output.should_not      be_nil
        @output.should          =~ /# On branch master/
      end
    end
  end

end
