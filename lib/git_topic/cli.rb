#!/usr/bin/env ruby
# encoding: utf-8

require 'yaml'

require 'rubygems'

require 'trollop'
require 'git_topic'


module GitTopic
  SubCommands = %w(
    work-on done abandon status review comment comments accept reject
    install-aliases
  )
  Version = lambda {
    h = YAML::load_file( "#{File.dirname( __FILE__ )}/../../VERSION.yml" )
    if h.is_a? Hash
      [h[:major], h[:minor], h[:patch], h[:build]].compact.join( "." )
    end
  }.call

  class << self
    def run
      global_opts = self.global_opts = Trollop::options do
        banner "
          git-topic #{Version}
          Manage a topic/review workflow.

          see <http://github.com/hjdivad/git-topic>

          Commands are:
            #{SubCommands.join( "
            " )}

            Global Options:
        ".unindent
        version Version

        opt :verbose,   
            "Verbose output, including complete traces on errors."
        opt :completion_help,
            "View instructions for setting up autocompletion."
        opt :no_log,
            "Disable logging."

        stop_on         SubCommands
      end


      if global_opts[:completion_help]
        root = File.expand_path( "#{File.dirname( __FILE__ )}/../.." )
        completion_bash_file  = "#{root}/share/completion.bash"
        puts %Q{
          To make use of bash autocompletion, you must do the following:

            1.  Make sure you source
                  #{completion_bash_file}
                before you source git's completion.

            2.  Optionally, install git-topic with the --no-wrappers option.
                This is to sidestep ruby issue 3465 which makes loading gems
                through the generated wrapper far too slow for autocompletion.
                For more information, see:

                  http://redmine.ruby-lang.org/issues/show/3465
        }.unindent
        exit 0
      end

      info      ''
      info      ARGV.join( " " )
      cmd       = ARGV.shift
      cmd_opts  = Trollop::options do
        case cmd
        when "work-on"
          banner "
            git[-topic] work-on <topic> [<upstream> | --continue]

            Switches to a local work-in-progress (wip) branch for <topic>.  The
            branch (and a matching remote branch) is created if necessary.

            If this is a rejected topic, work will continue from the state of
            the rejected topic branch.  Similarly, if this is a review topic,
            the review will be pulled and work will continue on that topic.

            <topic>'s branch's HEAD will point to <upstream>, if supplied.  If
            --continue is supplied instead, HEAD will point to the most recent
            review (i.e. submitted) of your topic branches.  If you have just
            submitted a topic with git done, git work-on next-topic --continue
            would begin the next topic starting from where you had left off.
           
            If both <upstream> and --continue are omitted, <topic>'s branch's
            HEAD will default to the current HEAD.

            Options:
          ".unindent

          opt   :continue,
                "Use latest review branch as <upstream>",
                :default => false
        when "abandon"
          banner "
            git[-topic] abandon [<topic>]

            Deletes <topic> locally and remotely.  Defaults to current topic if unspecified.
          ".unindent
        when /done(-with)?/
          banner "
            git[-topic] done

            Indicate that this topic branch is ready for review.  Push to a
            remote review branch and switch back to master.

            Options:
          ".unindent
        when "status"
          banner "
            git st
            git-topic status

            Print a status, showing rejected branches to work on and branches
            that can be reviewed.

            Options:
          ".unindent
          opt   :prepended,
                "
                  Prepend status to git status output (for a complete view of
                  status).
                ".oneline,
                :default => false
        when "review"
          banner "
            git[-topic] review [<topic>]

            Review <topic>.  If <topic> is unspecified, review the oldest (by HEAD) topic.

            Options:
          ".unindent
        when "comment"
          banner "
            git[-topic] comment

            Add your comments to the current topic.  If this is the first time
            you are reviwing <topic> you can set initial comments (see
            INITIAL_COMMENTS below).  Otherwise, your GIT_EDITOR will open to
            let you enter your replies to the comments.

            Similarly, if you are working on a rejected branch, git-topic
            comment will open your GIT_EDITOR so you can reply to the reviewer's
            comments.
           
            INITIAL_COMMENTS

            For the initial set of comments, you can edit the files in your
            working tree to include any file specific comments.  Simply ensure
            that all such comments are prefixed with a ‘#’.  git-topic comment
            will convert your changes to a list of file-specific comments.

            In order to use this feature, there are several requirements about
            the output of git diff.

            1.  It must only have file modifications.  i.e., no deletions,
                additions or mode changes.

            2.  Those modifications must only have line additions.  i.e. no line
                deletions.

            3.  Those line additions must all begin with any amount of
                whitespace followed by a ‘#’ character.  i.e. they should be
                comments.

            Options:
          ".unindent

          opt   :force_update,
                "
                  If you are commenting on the initial review and you wish to
                  edit your comments, you can pass this flag to do so.
                ".oneline
        when "comments"
          banner "
            git[-topic] comments [<topic>]

            View the comments for <topic>, which defaults to the current topic.
            If your branch was rejected, you should read these comments so you
            know what to do to appease the reviewer.

            Options:
          ".unindent
        when "accept"
          banner "
            git[-topic] accept

            Accept the current in-review topic, merging it to master and
            cleaning up the remote branch.  This will fail if the branch does
            not merge as a fast-forward in master.  If that happens, the topic
            should either be rejected, or you can manually rebase.

            Options:
          ".unindent
        when "reject"
          banner "
            git[-topic] reject

            Reject the current in-review topic.

            Options:
          ".unindent

          opt   :save_comments,
                "
                  If the current diff includes your comments (see git-topic
                  comment --help), this flag will autosave those comments before
                  rejecting the branch.
                ".oneline
        when "install-aliases"
          banner "
            git-topic install-aliases

            Install aliases to make git topic nicer to work with.  The aliases are as follows:

            w[ork-on]   topic work-on
            done        topic done
            r[eview]    topic review
            accept      topic accept
            reject      topic reject

            st          topic status --prepended

            Options:
          ".unindent

          opt   :local,
                "
                  Install aliases non-globally (i.e. in .git/config instead of
                  $HOME/.gitconfig
                ".oneline,
                :default => false
        end
      end

      check_for_setup unless cmd == "setup"

      opts = global_opts.merge( cmd_opts )
      display_git_output! if opts[:verbose]

      case cmd
      when "work-on"
        topic             = ARGV.shift
        upstream          = ARGV.shift
        opts.merge!({
          :upstream       => upstream
        })
        work_on           topic, opts
      when "abandon"
        topic             = ARGV.shift
        abandon           topic
      when /done(-with)?/
        topic             = ARGV.shift
        done              topic, opts
      when "status"
        status            opts
      when "review"
        spec              = ARGV.shift
        review            spec, opts
      when "comment"
        comment           opts
      when "comments"
        spec              = ARGV.shift
        comments          spec, opts
      when "accept"
        topic             = ARGV.shift
        accept            topic, opts
      when "reject"
        topic             = ARGV.shift
        reject            topic, opts
      when "install-aliases"
        install_aliases   opts
      when "setup"
        setup             opts
      end
    rescue => error
      puts "Error: #{error.message}"
      puts error.backtrace.join( "\n" ) if opts[:verbose]
    end
  end
end


