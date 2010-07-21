#!/usr/bin/env ruby
# encoding: utf-8

require 'active_support'
require 'active_support/core_ext/hash/keys'

require 'core_ext'
require 'git_topic/git'
require 'git_topic/naming'


module GitTopic
  include GitTopic::Git
  include GitTopic::Naming

  GlobalOptKeys = [ :verbose, :help, :verbose_given, :version ]


  class << self

    # Switch to a branch for the given topic.
    def work_on( topic, opts={} )
      raise "Topic must be specified" if topic.nil?

      # setup a remote branch, if necessary
      wb = wip_branch( topic )
      git(
        "push origin HEAD:#{wb}"
      ) unless remote_branches.include? "origin/#{wb}"
      # switch to the new branch
      git [ switch_to_branch( wb, "origin/#{wb}" )]
     
      # Check for rejected branch
      rej_branch = rejected_branch( topic )
      if remote_branches.include? "origin/#{rej_branch}"
        git [
          "reset --hard origin/#{rej_branch}",
          "push origin :#{rej_branch} HEAD:#{wb}",
        ]
      end

      report "Switching branches to work on #{topic}."
    end

    # Done with the given topic.  If none is specified, then topic is assumed to
    # be the current branch (if it's a topic branch).
    def done( topic=nil, opts={} )
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
      git [
        "push origin #{wb}:#{rb} :#{wb}",
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
    def status( opts={} )
      opts.assert_valid_keys  :prepended, :prepended_given, *GlobalOptKeys

      sb = ''
      rb = remote_branches_organized
      review_ut   = rb[:review]
      rejected_ut = rb[:rejected]

      unless review_ut.empty?
        prep = review_ut.size == 1 ? "is 1" : "are #{review_ut.size}"
        sb << "# There #{prep} #{'topic'.pluralize( review_ut.size )} you can review.\n\n"

        sb << review_ut.map do |user, topics|
          sb2 = "  from #{user}:\n"
          sb2 << topics.map{|t| "    #{t}"}.join( "\n" )
          sb2
        end.join( "\n" )
      end

      rejected_topics = rejected_ut[ user ] || []
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
    def review( ref=nil, opts={} )
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
    end

    # Accept the branch currently being reviewed.
    def accept( topic=nil, opts={} )
      raise "Must be on a review branch." unless on_review_branch?
      
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
        ".cleanup
      end

      rem_review_branch   = find_remote_review_branch( topic ).gsub( %r{^origin/}, '' )
      git [
        "push origin master :#{rem_review_branch}",
        "branch -d #{local_review_branch}"
      ]

      report  "Accepted topic #{user}/#{topic}."
    end

    # Reject the branch currently being reviewed.
    def reject( topic=nil, opts={} )
      raise "Must be on a review branch." unless on_review_branch?

      # switch to master
      # push to rejected, destroy remote
      # destroy local
      user, topic = user_topic_name( current_branch )

      rem_review_branch   = find_remote_review_branch( topic ).gsub( %r{^origin/}, '' )
      rem_rej_branch      = remote_rejected_branch( topic, user )
      git [
        "checkout master",
        "push origin #{current_branch}:#{rem_rej_branch} :#{rem_review_branch}",
        "branch -D #{current_branch}"
      ]

      report  "Rejected topic #{user}/#{topic}"
    end

    def install_aliases( opts={} )
      opts.assert_valid_keys  :local, :local_given, *GlobalOptKeys

      flags = "--global" unless opts[:local]

      git [
        "config #{flags} alias.work-on  'topic work-on'",
        "config #{flags} alias.done     'topic done'",
        "config #{flags} alias.review   'topic review'",
        "config #{flags} alias.accept   'topic accept'",
        "config #{flags} alias.reject   'topic reject'",

        "config #{flags} alias.w        'topic work-on'",
        "config #{flags} alias.r        'topic review'",
        "config #{flags} alias.st       'topic status --prepended'",
      ]

      report  "Aliases installed Successfully.",
              "
                Error installing aliases.  re-run with --verbose flag for
                details.
              ".oneline
    end

    protected

    def report( success_msg, error_msg=nil )
      if $?.success?
        puts success_msg
      else
        error_msg ||= "Error running command.  re-run with --verbose for details"
        raise error_msg
      end
    end

  end
end

