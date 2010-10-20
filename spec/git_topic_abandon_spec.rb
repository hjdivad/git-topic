# encoding: utf-8
require 'spec_helper'

describe GitTopic do

  describe "#abandon" do
    before( :each ){ use_repo 'in-progress' }


    shared_examples_for    :abandon_when_passed_an_argument do
      it "should error if the arg does not name a topic" do
        λ do
          GitTopic.abandon  'non-existant-topic'
        end.should    raise_error
      end

      it "should remove the specified wip topic, locally and remotely" do
        branch  = "wip/#{@user}/zombie-basic"

        previous_local_branches   = git_branches
        previous_remote_branches  = git_remote_branches
        previous_local_branches.should                    include branch
        previous_remote_branches.should                   include branch

        λ{ GitTopic.abandon "wip/#{@user}/zombie-basic" }.should_not  raise_error

        git_branches.should         == ( previous_local_branches - [ branch ])
        git_remote_branches.should  == ( previous_remote_branches - [ branch ])
      end

      it "should remove the specified review topic" do
        branch  = "review/#{@user}/pirates"

        previous_remote_branches  = git_remote_branches
        previous_remote_branches.should                   include branch

        λ{ GitTopic.abandon 'pirates' }.should_not       raise_error

        git_remote_branches.should  == ( previous_remote_branches - [ branch ])
      end
    end


    describe "when on a wip topic branch" do
      before  :each do
        λ{ GitTopic.work_on  'a-new-topic' }.should_not    raise_error
      end

      it_should_behave_like :abandon_when_passed_an_argument

      it "should remove the local topic" do
        branch  = "wip/#{@user}/a-new-topic"

        previous_local_branches   = git_branches
        previous_remote_branches  = git_remote_branches
        previous_local_branches.should                    include branch
        previous_remote_branches.should                   include branch

        λ{ GitTopic.abandon }.should_not  raise_error

        git_branches.should         == ( previous_local_branches - [ branch ])
        git_remote_branches.should  == ( previous_remote_branches - [ branch ])
      end
    end

    describe "when on a review topic branch" do
      before  :each do
        λ{ GitTopic.review }.should_not    raise_error
        git_head.should                     == '0ce06c616769768f09f5e629cfcc68eabe3dee81'
      end

      it_should_behave_like :abandon_when_passed_an_argument

      it "should error" do
        λ{ GitTopic.abandon }.should   raise_error
      end
    end

    describe "when on a rejected topic branch" do
      before  :each do
        λ{ GitTopic.work_on  'krakens' }.should_not  raise_error
        git_head.should                               == '44ffd9c9c8b52b201659e3ad318cdad6ec836b46'
      end
      it_should_behave_like :abandon_when_passed_an_argument

      it "should remove the topic, locally and remotely" do
        branch  = "wip/#{@user}/krakens"

        previous_local_branches   = git_branches
        previous_remote_branches  = git_remote_branches
        previous_local_branches.should                    include branch
        previous_remote_branches.should                   include branch

        λ{ GitTopic.abandon }.should_not  raise_error

        git_branches.should         == ( previous_local_branches - [ branch ])
        git_remote_branches.should  == ( previous_remote_branches - [ branch ])
      end
    end

    describe "when on some other branch" do
      before  :each do
        system "git checkout -q master > /dev/null 2> /dev/null"
      end
      it_should_behave_like :abandon_when_passed_an_argument

      it "should error" do
        λ{ GitTopic.abandon }.should   raise_error
      end
    end
  end
end
