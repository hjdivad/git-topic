require 'spec_helper'


describe GitTopic do

  describe "#comments" do

    describe "on a branch with no comments" do

      before( :each ) do
        use_repo            'in-progress'
        GitTopic.work_on    'pirates-advanced'
      end
      after( :each )  { Dir.chdir '..' }

      it "should report that there are no comments" do
        lambda{ GitTopic.comments }.should_not      raise_error
        @output.should_not                          be_nil
        @output.should                              =~ /no comments/i
      end
    end


    describe "on a branch with comments" do

      before( :each ) do
        use_repo            'in-progress'
        GitTopic.work_on    'krakens'
      end

      after( :each )  { Dir.chdir '..' }

      it "should invoke git log to display the comments" do
        GitTopic.should_receive( :git ) do |cmd|
          cmd.should =~ /log/
          cmd.should =~ %r{origin/master\.\.}
          cmd.should =~ /--no-standard-notes/
          cmd.should =~ %r{--show-notes=refs/notes/reviews/#{@user}/krakens}
        end

        lambda{ GitTopic.comments }.should_not      raise_error
      end
    end

  end

end
