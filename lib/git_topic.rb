#!/usr/bin/env ruby
# encoding: utf-8

require 'rubygems'
require 'bundler'

# Work around absurd bundler API
ENV['BUNDLE_GEMFILE'] = "#{File.dirname __FILE__}/../Gemfile"
Bundler.setup :runtime
ENV.delete 'BUNDLE_GEMFILE'

require 'active_support'
require 'active_support/core_ext/hash/keys'

require 'git_topic/core_ext'
require 'git_topic/git'
require 'git_topic/naming'
require 'git_topic/comment'
require 'git_topic/logger'


module GitTopic
  include GitTopic::Git
  include GitTopic::Naming
  include GitTopic::Comment

  GlobalOptKeys = [
    :verbose, :help, :verbose_given, :version, :completion_help,
    :completion_help_given, :no_log
  ]


  class << self

    # Switch to a branch for the given topic.
    def work_on topic, opts={}
      opts.assert_valid_keys  :continue, :upstream, *GlobalOptKeys
      raise "Topic must be specified" if topic.nil?

      upstream =
        if opts[:upstream] && opts[:continue]
          raise "upstream and continue options mutually exclusive."
        elsif opts[:upstream]
          opts[:upstream]
        elsif opts[:continue]
          newest_pending_branch
        end


      # setup a remote branch, if necessary
      wb = wip_branch( topic )
      git(
        "push origin HEAD:refs/heads/#{wb}"
      ) unless remote_branches.include? "origin/#{wb}"
      # switch to the new branch
      git [ switch_to_branch( wb, "origin/#{wb}" )]
  

      # Check for rejected or review branch
      [ rejected_branch( topic ), review_branch( topic ) ].each do |b|
        if remote_branches.include? "origin/#{b}"
          git [
            "reset --hard origin/#{b}",
            "push origin :refs/heads/#{b} HEAD:refs/heads/#{wb}",
          ]
        end
      end

      # Reset upstream, if specified
      if upstream
        git "reset --hard #{upstream}"
      end

      report "Switching branches to work on #{topic}."
      if existing_comments?
        report "You have reviewer comments on this topic."
      end
    end


    # Delete +topic+ locally and remotely.  Defaults to current topic if
    # unspecified.
    #
    def abandon topic=nil, opts={}
      local_branch =
        if topic.nil?
          parts = topic_parts current_branch
          if parts && parts[:namespace] == "wip" && parts[:user] == user
            topic = current_topic
            current_branch
          else
            raise "Cannot abandon #{current_branch}."
          end
        else
          wip_branch  topic
        end

      unless rb = remote_branch( topic, :strip_remote => true )
        raise "No such topic #{topic}."
      end

      git [
        ( "checkout master"           if current_branch == local_branch ),
        ( "branch -D #{local_branch}" if branches.include? local_branch ),
        "push origin :#{rb}",
      ].compact

      report "Topic #{topic} abandoned."
    end

    # Done with the given topic.  If none is specified, then topic is assumed to
    # be the current branch (if it's a topic branch).
    def done  topic=nil, opts={}
      if topic.nil?
        raise "
          Current branch is not a topic branch.  Switch to a topic branch or
          supply an argument.
        ".oneline if current_topic.nil?

        topic = current_topic
      else
        raise "
          Specified topic #{topic} does not refer to a topic branch.
        " unless branches.include? wip_branch( topic )
      end
      raise "Working tree must be clean" unless working_tree_clean?


      wb = wip_branch( topic )
      rb = review_branch( topic )
      refspecs = [
        "refs/heads/#{wb}:refs/heads/#{rb}",
        ":refs/heads/#{wb}",
        "refs/notes/reviews/*:refs/notes/reviews/*"
      ].join( " " )
      git [
        "push origin #{refspecs}",
        ("checkout master" if strip_namespace( topic ) == current_topic),
        "branch -D #{wip_branch( topic )}"
      ].compact

      report "Completed topic #{topic}.  It has been pushed for review."
    end


    # Produce status like
    #
    #   # There are 2 topics you can review.
    #   #
    #   # from davidjh:
    #   #   zombies
    #   #   pirates
    #   # from king-julian:
    #   #   fish
    #   #   whales
    #   #
    #   # 2 of your topics were rejected.
    #   #   dragons
    #   #   liches
    def status  opts={}
      opts.assert_valid_keys  :prepended, :prepended_given, *GlobalOptKeys

      sb = ''
      rb = remote_branches_organized
      review_ut   = rb[:review]
      rejected_ut = rb[:rejected]

      unless review_ut.empty?
        topic_count = review_ut.inject( 0 ){ |a, uts| a + uts.size }
        prep = topic_count == 1 ? "is 1" : "are #{topic_count}"
        sb << "# There #{prep} #{'topic'.pluralize( topic_count )} you can review.\n\n"

        sb << review_ut.map do |user, topics|
          sb2 = "  from #{user}:\n"
          sb2 << topics.map do |t|
            age = ref_age( review_branch( t, user, :remote => true ))
            age_str = " (#{age} days)" if age && age > 0
            "    #{t}#{age_str}"
          end.join( "\n" )
          sb2
        end.join( "\n" )
      end

      rejected_topics = (rejected_ut[ user ] || []).dup
      rejected_topics.map! do |topic|
        suffix = " (reviewer comments) "
        "#{topic}#{suffix if existing_comments?( "#{user}/#{topic}" )}"
      end
      unless rejected_topics.empty?
        sb << "\n" unless review_ut.empty?
        verb = rejected_topics.size  == 1 ? 'is' : 'are'
        sb << "\n#{rejected_topics.size} of your topics #{verb} rejected.\n    "
        sb << rejected_topics.join( "\n    " )
      end

      sb.gsub! "\n", "\n# "
      sb << "\n" unless sb.empty?
      print sb

      if opts[ :prepended ]
        print "#\n" unless sb.empty?
        git "status", :show => true
      end
    end


    # Switch to a review branch to check somebody else's code.
    def review  ref=nil, opts={}
      rb = remote_branches_organized
      review_branches = rb[:review]

      if ref.nil?
        # select the oldest (by HEAD) topic, if any exist
        if review_branches.empty?
          puts "nothing to review."
          return
        else
          user, topic = oldest_review_user_topic
        end
      else
        p             = topic_parts( ref )
        user, topic   = p[:user], p[:topic]
      end

      if remote_topic_branch = find_remote_review_branch( topic )
        # Get the actual user/topic, e.g. to get the user if ref only specifies
        # the topic.
        real_user, real_topic = user_topic_name( remote_topic_branch )
        git [
          switch_to_branch(
            review_branch( real_topic, real_user ),
            remote_topic_branch )]
      else
        raise "No review topic found matching ‘#{ref}’"
      end
      report  "Reviewing topic #{user}/#{topic}."

      unless rebased_to_master?
        git "rebase --quiet master"
        report(
          "
            #{user}/#{topic} was not rebased to master, but has successfully
            been automatically rebased.
          ".unindent,
          "
            #{user}/#{topic} was not rebased to master, and I could not
            automatically rebase it.  You will not be able to accept this topic.
            Either
              1) rebase the topic manually or
              2) reject the topic and ask the author to rebase.
          ".unindent )
      end
    end


    # Accept the branch currently being reviewed.
    def accept  topic=nil, opts={}
      raise "Must be on a review branch." unless on_review_branch?
      raise "Working tree must be clean" unless working_tree_clean?
      
      # switch to master
      # merge review branch, assuming FF
      # push master, destroy remote
      # destroy local
      user, topic           = user_topic_name( current_branch )

      local_review_branch   = current_branch
      ff_merge = git [
          "checkout master",
          "merge --ff-only #{local_review_branch}",
      ]

      unless ff_merge
        git "checkout #{local_review_branch}"
        raise "
          review branch is not up to date: merge not a fast-forward.  Either
          rebase or reject this branch.
        ".unindent
      end

      rem_review_branch   = find_remote_review_branch( topic ).gsub( %r{^origin/}, '' )
      git [
        "push origin master :refs/heads/#{rem_review_branch}",
        "branch -d #{local_review_branch}"
      ]

      report  "Accepted topic #{user}/#{topic}."
    end


    def comment opts={}
      diff_legal = 
        git( "diff --diff-filter=ACDRTUXB --quiet" )          && 
        git( "diff --cached --diff-filter=ACDRTUXB --quiet" )
    
      raise "
        Diffs are not comments.  Files have been added, deleted or had their
        modes changed.  See
          git diff --diff-filter=ACDRTUXB
        for a list of changes preventing git-topic comment from saving your
        comments.
      ".unindent unless diff_legal


      diff_empty          = git( "diff --diff-filter=M --quiet" )

      added_comments = 
        case current_namespace
        when "wip"
          if existing_comments?
            raise "
              diff → comments not allowed when replying.  Please make sure your
              working tree is completely clean and then invoke git-topic comment
              again.
            ".oneline unless diff_empty

            notes_from_reply_to_comments
          else
            puts "No comments to reply to.  See git-topic comment --help for usage."
            return
          end
        when "review"
          if existing_comments?
            if opts[ :force_update ]
              notes_from_initial_comments( "edit" )
            else
              raise "
                diff → comments not allowed when replying.  Please make sure your
                working tree is completely clean and then invoke git-topic comment
                again.
              ".oneline unless diff_empty

              notes_from_reply_to_comments
            end
          else
            notes_from_initial_comments
          end
        else
          raise "Inappropriate namespace for comments: [#{namespace}]"
        end

      if added_comments
        report "Your comments have been saved."
      else
        report "You did not write any comments.  Nothing to save."
      end
    end

    def comments  spec=nil, opts={}
      args = [ spec ].compact
      if args.empty? && current_branch.nil?
        if guess = guess_branch
          args << guess_branch

          puts "
            You are not on a branch and no topic branch was specified.  Using
            alternate name for HEAD, #{guess}.
          ".oneline
        else
          puts "
            You are not on a branch and no topic branch was specified.  I could
            not find an appropriate name for HEAD to guess.
          "
          return
        end
      end

      unless existing_comments? *args
        puts "There are no comments on this branch."
        return
      end

      range = "origin/master..#{remote_branch *args}"
      git "log #{range} --show-notes=#{notes_ref *args} --no-standard-notes",
          :show => true
    end


    # Reject the branch currently being reviewed.
    def reject  topic_or_opts=nil, opts={}
      if topic_or_opts.is_a? Hash
        topic = nil
        opts = topic_or_opts
      else
        topic = topic_or_opts
      end

      raise "Must be on a review branch." unless on_review_branch?
      unless working_tree_clean?
        if opts[:save_comments]
          comment
        else
          raise "Working tree must be clean without --save-comments."
        end
      end

      # switch to master
      # push to rejected, destroy remote
      # destroy local
      user, topic = user_topic_name( current_branch )

      rem_review_branch   = find_remote_review_branch( topic ).gsub( %r{^origin/}, '' )
      rem_rej_branch      = remote_rejected_branch( topic, user )

      refspecs = [
        "refs/heads/#{current_branch}:refs/heads/#{rem_rej_branch}",
        ":refs/heads/#{rem_review_branch}",
        "refs/notes/reviews/*:refs/notes/reviews/*"
      ].join( " " )
      git [
        "checkout master",
        "push origin #{refspecs}",
        "branch -D #{current_branch}"
      ]

      report  "Rejected topic #{user}/#{topic}"
    end


    # Setup .git/config.
    #
    # This means setting up:
    #   1. refspecs for origin fetching for review comments.
    #   2. notes.rewriteRef for copying review comments on rebase.
    #
    def setup opts={}
      cmds = []

      cmds <<(
        "config --add remote.origin.fetch +refs/notes/reviews/*:refs/notes/reviews/*"
      ) unless has_setup_refspec?

      cmds <<(
        "config --add notes.rewriteRef refs/notes/reviews/*"
      ) unless has_setup_notes_rewrite?

      git cmds.compact
    end

    def install_aliases opts={}
      opts.assert_valid_keys  :local, :local_given, *GlobalOptKeys

      flags = "--global" unless opts[:local]

      git [
        "config #{flags} alias.work-on  'topic work-on'",
        "config #{flags} alias.done     'topic done'",
        "config #{flags} alias.review   'topic review'",
        "config #{flags} alias.accept   'topic accept'",
        "config #{flags} alias.reject   'topic reject'",
        "config #{flags} alias.comment  'topic comment'",
        "config #{flags} alias.comments 'topic comments'",
      ]

      report  "Aliases installed Successfully.",
              "
                Error installing aliases.  re-run with --verbose flag for
                details.
              ".oneline
    end


    protected

    def report  success_msg, error_msg=nil
      if $pstatus && $pstatus.success?
        puts success_msg
      else
        error_msg ||= "Error running command.  re-run with --verbose for details"
        raise error_msg
      end
    end


    def check_for_setup
      git_dir = `git rev-parse --git-dir 2> /dev/null`.chomp
      return if git_dir.empty?

      suppress_whine = `git config topic.checkForNotesRef`.chomp == "false"
      return if suppress_whine

      unless has_setup_refspec? && has_setup_notes_rewrite?
        STDERR.puts "
          Warning: git repository is not set up for git topic.  Review comments
          will not automatically be pulled on git fetch and will not be copied
          on a rebase.  You have two options for suppressing this message:

          1.  Run git-topic setup to setup fetch refspecs for origin and
              comments copying on rebase.

          2.  Run git config topic.checkForNotesRef false.
              If you do this, you can manually fetch reviewers' comments with
              the following command

                  git fetch origin refs/notes/reviews/*:refs/notes/reviews/*

              Similarly, you can ensure your comments are not lost on rebase by running

                GIT_NOTES_REWRITE_REF=refs/notes/reviews/* git rebase

              instead of `git rebase`
        ".unindent
      end
    end

    def has_setup_refspec?
      fetch_refspecs = capture_git( "config --get-all remote.origin.fetch" ).split( "\n" )
      fetch_refspecs.any? do |refspec|
        refspec == "+refs/notes/reviews/*:refs/notes/reviews/*"
      end
    end

    def has_setup_notes_rewrite?
      notes_rewrites = capture_git( "config --get-all notes.rewriteRef" ).split( "\n" )
      notes_rewrites.any? do |refs|
        refs == "refs/notes/reviews/*"
      end
    end

  end
end

