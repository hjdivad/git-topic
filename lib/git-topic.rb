#!/usr/bin/env ruby
# encoding: utf-8

require 'active_support'
require 'active_support/core_ext'

require 'util'


module GitTopic
  class << self

    # Switch to a branch for the given topic.
    def work_on( topic, opts={} )
      raise "Topic must be specified" if topic.nil?

      git [ switch_to_branch( wip_branch( topic ))]
    end

    # Done with the given topic.  If none is specified, then topic is assumed to
    # be the current branch (if it's a topic branch).
    def done( topic=nil, opts={} )
      raise(
        "Branch must be a topic branch"
      ) unless current_branch =~ %r{^wip/}
      raise(
        "Working tree must be clean"
      ) unless working_tree_clean?

      topic = current_topic if topic.nil?

      git [
        "push origin #{wip_branch( topic )}:#{review_branch( topic )}",
        "checkout master",
        "branch -D #{wip_branch( topic )}"
      ]
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
      sb = ''
      rb = remote_branches_organized
      review_ut   = rb[:review]
      rejected_ut = rb[:rejected]

      unless review_ut.empty?
        prep = review_ut.size == 1 ? "is 1" : "are #{review_ut.size}"
        sb << "\nThere #{prep} #{'topic'.pluralize( review_ut.size )} you can review.\n\n"

        sb << review_ut.map do |user, topics|
          sb2 = "  from #{user}:\n"
          sb2 << topics.map{|t| "    #{t}"}.join( "\n" )
          sb2
        end.join( "\n" )
      end

      rejected_topics = rejected_ut[ user ]
      unless rejected_topics.empty?
        verb = rejected_topics.size  == 1 ? 'is' : 'are'
        sb << "\n#{rejected_topics.size} of your topics #{verb} rejected.\n  "
        sb << rejected_topics.join( "\n  " )
      end

      sb << "\n" unless sb.empty?
      print sb
    end

    # Switch to a review branch to check somebody else's code.
    def review( spec=nil, opts={} )
      rb = remote_branches_organized
      review_branches = rb[:review]

      if spec.nil?
        # select the oldest (by HEAD) topic, if any exist
        if review_branches.empty?
          puts "nothing to review."
          return
        end

        user, topic = oldest_review_user_topic
      else
        user, topic = spec.split( '/' )
      end

      if remote_topic_branch = find_remote_review_branch( topic )
        git [
          switch_to_branch(
            review_branch( topic, user ),
            remote_topic_branch )]
      else
        raise "No review topic found matching ‘#{spec}’"
      end
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
        "push origin :#{rem_review_branch}",
        "branch -d #{local_review_branch}"
      ]
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
    end


    private


    def backup_branch( topic )
      "backup/#{user}/#{topic}"
    end

    def wip_branch( topic )
      "wip/#{user}/#{topic}"
    end

    def review_branch( topic, user=user )
      "review/#{user}/#{topic}"
    end

    def remote_rejected_branch( topic, user=user )
      "rejected/#{user}/#{topic}"
    end


    def find_remote_review_branch( topic )
      others_review_branches.find{|b| b.index topic}
    end


    def user_topic_name( branch )
      if branch =~ %r{^origin}
        branch =~ %r{^\S*?/\S*?/(\S*?)/(\S*)}
        [$1, $2]
      else
        branch =~ %r{^\S*?/(\S*?)/(\S*)}
        [$1, $2]
      end
    end


    def user
      @@user ||= (ENV['USER'] || `whoami`)
    end

    def current_topic
      current_branch =~ %r{wip/\S*?/(\S*)}
      $1
    end

    def current_branch
      @@current_branch ||= capture_git( "branch --no-color" ).split( "\n" ).find do |b|
        b =~ %r{^\*}
      end[ 2..-1 ]
    end

    def branches
      @@branches ||= capture_git( "branch --no-color" ).split( "\n" ).map{|b| b[2..-1]}
    end

    def remote_branches
      @@remote_branches ||= capture_git( "branch -r --no-color" ).split( "\n" ).map{|b| b[2..-1]}
    end

    def others_review_branches
      remote_branches.select do
        |b| b =~ %r{/review/}
      end.reject do |b|
        b =~ %r{/#{user}/}
      end
    end

    def remote_branches_organized
      @@remote_branches_organized ||= (
        rb = remote_branches.dup
        # Convert a bunch of remote branch names, like
        #   origin/HEAD -> origin/masterr
        #   origin/master
        #   origin/review/user1/topic1
        #   origin/something-else
        #   origin/rejected/user2/topic2
        #
        # Into a hash with keys 'review' and 'rejected' pointing to hashes of
        # user-topic(s) pairs.
        rb.map!{|s| s.gsub( /->.*/, '')}
        rb.map!{|s| s.strip.split( '/' )}
        namespace_ut = rb.group_by{|remote, namespace, user, topic| namespace if topic}
        namespace_ut.reject!{|k,v| not %w(rejected review).include? k}

        namespace_ut.each do |k,v|
          v.each{|a| a.shift( 2 )}
          v = namespace_ut[k] = v.group_by{|user, topic| user if topic}
          v.each{|kk,vv| vv.each(&:shift); vv.flatten!}
        end

        namespace_ut.symbolize_keys!
        namespace_ut[:review] ||= {}
        namespace_ut[:rejected] ||= {}

        namespace_ut[:review].reject!{|k,v| k == user}
        namespace_ut
      )
    end

    def oldest_review_branch
      return nil if others_review_branches.empty?

      commits_by_age = capture_git([
        "log --date-order --reverse --pretty=format:%d",
        "^origin/master #{others_review_branches.join( ' ' )}",
      ].join( " " )).split( "\n" )

      commits_by_age.find do |ref|
        # no ‘,’, i.e. only one ref matches the commit
        ref.index( ',' ).nil?
      end.strip[ 1..-2 ] # chomp the leading and trailing parenthesis
    end

    def oldest_review_user_topic
      user_topic_name( oldest_review_branch )
    end

    def on_review_branch?
      current_branch =~ %r{^review/}
    end

    def working_tree_clean?
      git [ "diff --quiet", "diff --quiet --cached" ]
      $?.success?
    end

    def working_tree_dirty?
      not working_tree_clean?
    end


    def display_git_output?
      @@display_git_output ||= false
    end


    def switch_to_branch( branch, tracking=nil )
      if branches.include?( branch )
        # TODO 3: setup tracking
        "checkout #{branch}"
      else
        "checkout -b #{branch} #{tracking}"
      end
    end


    def git( cmds=[] )
      cmds = [cmds] if cmds.is_a? String
      redir = "> /dev/null 2> /dev/null" unless display_git_output?
      system cmds.map{|c| "git #{c} #{redir}"}.join( " && " )
    end

    def capture_git( cmds=[] )
      cmds = [cmds] if cmds.is_a? String
      redir = "2> /dev/null" unless display_git_output?
      `#{cmds.map{|c| "git #{c} #{redir}"}.join( " && " )}`
    end
  end
end

