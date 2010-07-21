#!/usr/bin/env ruby
# encoding: utf-8

require 'yaml'

require 'rubygems'

require 'trollop'
require 'git_topic'


module GitTopic
  SubCommands = %w(work-on done status review accept reject install-aliases)
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
        ".cleanup
        version Version

        opt :verbose,   "Verbose output, including complete traces on errors."
        stop_on         SubCommands
      end

      cmd       = ARGV.shift
      cmd_opts  = Trollop::options do
        case cmd
        when "work-on"
          banner "
            git work-on <topic>
            git-topic work-on <topic>

            Switches to a local work-in-progress (wip) branch for <topic>.  The
            branch (and a matching remote branch) is created if necessary.

            If this is a rejected topic, work will continue from the state of
            the rejected topic branch.

            Options:
          ".cleanup
        when /done(-with)?/
          banner "
            git done
            git-topic done

            Indicate that this topic branch is ready for review.  Push to a
            remote review branch and switch back to master.

            Options:
          ".cleanup
        when "status"
          banner "
            git st
            git-topic status

            Print a status, showing rejected branches to work on and branches
            that can be reviewed.

            Options:
          ".cleanup
          opt   :prepended,
                "
                  Prepend status to git status output (for a complete view of
                  status).
                ".oneline,
                :default => false
        when "review"
          banner "
            git review [<topic>]
            git-topic reivew [<topic>]

            Review <topic>.  If <topic> is unspecified, review the oldest (by HEAD) topic.

            Options:
          ".cleanup
        when "accept"
          banner "
            git accept
            git-topic accept

            Accept the current in-review topic, merging it to master and
            cleaning up the remote branch.  This will fail if the branch does
            not merge as a fast-forward in master.  If that happens, the topic
            should either be rejected, or you can manually rebase.

            Options:
          ".cleanup
        when "reject"
          banner "
            git reject
            git-topic reject

            Reject the current in-review topic.

            Options:
          ".cleanup
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
          ".cleanup

          opt   :local,
                "
                  Install aliases non-globally (i.e. in .git/config instead of
                  $HOME/.gitconfig
                ".oneline,
                :default => false
        end
      end

      opts = global_opts.merge( cmd_opts )
      display_git_output! if opts[:verbose]

      case cmd
      when "work-on"
        topic             = ARGV.shift
        work_on           topic, opts
      when /done(-with)?/
        topic             = ARGV.shift
        done              topic, opts
      when "status"
        status            opts
      when "review"
        spec              = ARGV.shift
        review            spec, opts
      when "accept"
        topic             = ARGV.shift
        accept            topic, opts
      when "reject"
        topic             = ARGV.shift
        reject            topic, opts
      when "install-aliases"
        install_aliases   opts
      end
    rescue => error
      puts "Error: #{error.message}"
      puts error.backtrace.join( "\n" ) if opts[:verbose]
    end
  end
end

