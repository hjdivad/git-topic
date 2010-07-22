require 'spec_helper'


describe GitTopic do
  
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

