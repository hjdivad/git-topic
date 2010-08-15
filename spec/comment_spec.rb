require 'spec_helper'

DiffWithNonCommentAddition = %Q{
diff --git a/lib/git_topic.rb b/lib/git_topic.rb
index edb53f1..adceb44 100644
--- a/lib/git_topic.rb
+++ b/lib/git_topic.rb
@@ -9,0 +10 @@ require 'git_topic/naming'
+require 'git_topic/comment'
}.strip

DiffWithDeletion = %Q{
diff --git a/Gemfile b/Gemfile
index ece2952..9d2ccec 100644
--- a/Gemfile
+++ b/Gemfile
@@ -7 +6,0 @@ group :runtime do
-  gem 'trollop'
}.strip

DiffWithOnlyComments = %Q{
diff --git a/Gemfile b/Gemfile
index ece2952..8485775 100644
--- a/Gemfile
+++ b/Gemfile
@@ -5,0 +6,2 @@ group :runtime do
+  # what was the point of this?
+  # surely it would be better with crazy doom stuff and fingles, no?
diff --git a/lib/git_topic.rb b/lib/git_topic.rb
index adceb44..920e512 100644
--- a/lib/git_topic.rb
+++ b/lib/git_topic.rb
@@ -17,0 +18 @@ module GitTopic
+  # This is kind of ugly.  Why can't we pull this into cli?
@@ -55,0 +57 @@ module GitTopic
+    # Oh the night patty murphy died... yadda yadda.
@@ -107,0 +110,3 @@ module GitTopic
+      # That's how they showed their respect for patty murphy!  that's how they
+      # showed their honour and their pride!  They said it was a cryin' shame
+      # and they winked at one another.
@@ -111,0 +117 @@ module GitTopic
+        # and so on and so forth.  The point is, there was a lot of wailing.
@@ -118,0 +125 @@ module GitTopic
+      # They put the bottle with the corpse to keep that whiskey cold!
diff --git a/Rakefile b/Rakefile
index 309d6df..73428b2 100644
--- a/Rakefile
+++ b/Rakefile
@@ -64,0 +65,4 @@ rescue LoadError
+  # Awesome I guess.  But why not something like:
+  #   Crazy good.
+  # Or something vaguely similar.
+  # It would seem better that way.
}.strip


EditorBufferResultFromClean = %Q{
./Gemfile

  Line 6

    David:          what was the point of this? surely it would be better with
                    crazy doom stuff and fingles, no?


./lib/git_topic.rb

  Line 18

    David:          This is kind of ugly.  Why can't we pull this into cli?

  Line 56

    David:          Oh the night patty murphy died... yadda yadda.

  Line 108

    David:          That's how they showed their respect for patty murphy!
                    that's how they showed their honour and their pride!  They
                    said it was a cryin' shame and they winked at one another.

  Line 112

    David:          and so on and so forth.  The point is, there was a lot of
                    wailing.

  Line 119

    David:          They put the bottle with the corpse to keep that whiskey
                    cold!


./Rakefile

  Line 65

    David:          Awesome I guess.  But why not something like:
                      Crazy good.
                    Or something vaguely similar.  It would seem better that way.
}.strip


ExistingComment = %Q{
Spec 123:           I have some general comments, mostly relating to the quality
                    of our zombie-control policies. Basically, they're not
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


./lib/foo/zombie_repellant

  Line 6
    Spec 123:       Does this stuff really work?  I'm not convinced.

  Line 40
    Spec 123:       Please explain this.
}.strip

LegalReply = %Q{
# Spec 123:         I have some general comments, mostly relating to the quality
#                   of our zombie-control policies. Basically, they're not
#                   working.

Sorry about that.  I have fixed the branch to have better zombie-control policies.

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

Excellent suggestion.  It's done.
# 
# ./lib/foo/zombie_repellant
# 
#   Line 6
#     Spec 123:     Does this stuff really work?  I'm not convinced.
      
      You can look at the tests yourself.  It seems to work.
# 
#   Line 40
#     Spec 123:     Please explain this.
}.strip

CommentWithReply = %Q{
Spec 123:           I have some general comments, mostly relating to the quality
                    of our zombie-control policies. Basically, they're not
                    working.
Spec 456:           Sorry about that.  I have fixed the branch to have better 
                    zombie-control policies.

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
    Spec 456:       Excellent suggestion.  It's done.


./lib/foo/zombie_repellant

  Line 6
    Spec 123:       Does this stuff really work?  I'm not convinced.
    Spec 456:       You can look at the tests yourself.  It seems to work.

  Line 40
    Spec 123:       Please explain this.
}.strip

MalformedReplyBadLines = %Q{
# Spec 123:         I have some general comments, mostly relating to the quality
#                   of our zombie-control policies. Basically, they're not
#                   working.
# 
# ./zombies

Uh oh.  a malformed reply.  This is not a legal spot for comments!

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
# 
# ./lib/foo/zombie_repellant
# 
#   Line 6
#     Spec 123:     Does this stuff really work?  I'm not convinced.
# 
#   Line 40
#     Spec 123:     Please explain this.
}.strip

MalformedReplyNewFiles = %Q{
# Spec 123:         I have some general comments, mostly relating to the quality
#                   of our zombie-control policies. Basically, they're not
#                   working.
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
# 
# ./anew/and/illegal/path
Uh oh.  This appears to be an invalid reply!  Madness!
# 
# ./lib/foo/zombie_repellant
# 
#   Line 6
#     Spec 123:     Does this stuff really work?  I'm not convinced.
# 
#   Line 40
#     Spec 123:     Please explain this.
}.strip


describe GitTopic::Comment do
  include GitTopic::Comment::ClassMethods

  describe "#diff_to_file_specific_notes" do

    it "should fail with non-comment additions" do
      lambda do 
        diff_to_file_specific_notes DiffWithNonCommentAddition,
                              :author => "David"
      end.should raise_error
    end

    it "should fail with deletions" do
      lambda do 
        diff_to_file_specific_notes DiffWithDeletion,
                              :author => "David"
      end.should raise_error
    end

    it "should fail if :author is not supplied" do
      lambda do 
        diff_to_file_specific_notes DiffWithOnlyComments
      end.should raise_error
    end

    describe "when there are no existing comments" do

      it "should format the diff correctly for no existing comments" do
        initial_contents = diff_to_file_specific_notes(
          DiffWithOnlyComments,
          :author => "David"
        )
       
        # Not interested in exact formatting: just the contents.
        initial_contents.gsub( /\s+/, "\n").strip.should == 
          EditorBufferResultFromClean.gsub( /\s+/, "\n" ).strip
      end

    end
  end


  describe "#notes_from_reply_to_comments" do

    it "should fail if there are no existing comments" do
      self.should_receive( :existing_comments? ).and_return( false )
      lambda{ notes_from_reply_to_comments }.should   raise_error
    end

    it "
      should complain if the user malforms the file by responding to ‘new’
      files
    ".oneline do

      self.should_receive( :existing_comments? ). and_return( true )
      self.should_receive( :existing_comments ).   and_return( ExistingComment )
      self.should_receive( :git_dir ).            and_return( "." )
      self.should_receive( :notes_ref ).exactly( 0 ).times
      self.stub!( :invoke_git_editor ) do |path|
        File.open( path, 'w' ){ |f| f.puts MalformedReplyNewFiles }
      end
      self.should_receive( :invoke_git_editor )

      lambda{ notes_from_reply_to_comments }.should     raise_error
    end

    it "
      should complain if the user malforms the file by responding to
      file-specific comments before the line sections
    ".oneline do

      self.should_receive( :existing_comments? ). and_return( true )
      self.should_receive( :existing_comments ).   and_return( ExistingComment )
      self.should_receive( :git_dir ).            and_return( "." )
      self.should_receive( :notes_ref ).exactly( 0 ).times
      self.stub!( :invoke_git_editor ) do |path|
        File.open( path, 'w' ){ |f| f.puts MalformedReplyBadLines }
      end
      self.should_receive( :invoke_git_editor )

      lambda{ notes_from_reply_to_comments }.should     raise_error
    end

    it "should add the users' comments as replies to the originals" do
      self.should_receive( :existing_comments? ).     and_return( true )
      self.should_receive( :existing_comments ).       and_return( ExistingComment )
      self.should_receive( :git_dir ).                and_return( "." )
      self.should_receive( :git_author_name_short ).  and_return( "Spec 456" )
      self.should_receive( :notes_ref ).
        and_return( "refs/notes/reviews/#{@user}/topic" )
      self.stub!( :invoke_git_editor ) do |path|
        File.open( path, 'w' ){ |f| f.write LegalReply }
      end
      self.should_receive( :invoke_git_editor )
      self.should_receive( :git ) do
        File.read( "./COMMENT_EDITMSG" ).should           == CommentWithReply
      end

      lambda{ notes_from_reply_to_comments }.should_not   raise_error
    end

  end


  describe "#notes_to_hash" do
    it "should convert notes to a hash" do
      hash = notes_to_hash( ExistingComment )
      hash.should_not         be_nil
      hash.keys.should        == [  :general,
                                    "./zombies",
                                    "./lib/foo/zombie_repellant" ]
      hash[ :general ].should                       == 3
      hash[ "./zombies" ].should                    be_a Hash
      hash[ "./lib/foo/zombie_repellant" ].should   be_a Hash

      zombie_hash     = hash[ "./zombies" ]
      repellant_hash  = hash[ "./lib/foo/zombie_repellant" ]

      zombie_hash.keys.should     == [ 2 ]
      repellant_hash.keys.should  == [ 6, 40 ]

      zombie_hash[ 2 ].should     == 15
      repellant_hash[ 6 ].should  == 21
      repellant_hash[ 40 ].should == 24
    end
  end

  describe "#attrib" do

    it "should return a 16-length string for short author names" do
      attrib( "David" ).should    == "David:          "
    end

    it "should truncate very long author names" do
      attrib( "DavidVonSuperLongNameStuff" ).
        should                    == "DavidVonSuperLo:"
    end

    it "should respect padding for short author names" do
      attrib( "David", 4 ).should == "    David:      "
    end
  end

end

