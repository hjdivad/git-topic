
module GitTopic
  class << self; attr_accessor :global_opts end
  self.global_opts = {}
end

module GitTopic::Git
  module ClassMethods

    protected

    def git_dir
      @@git_dir ||= (
        git_dir = capture_git( "rev-parse --git-dir" ).chomp;
        raise "Unexpected gitdir: [#{git_dir}]" unless git_dir.index '.git'
        git_dir
      )
    end

    def git_editor
      @@git_editor ||= capture_git( "var GIT_EDITOR" ).chomp
    end

    def git_author_name_short
      @@git_author_name_short ||= (
        full_name = capture_git( "config user.name" )
        raise "
          Unable to determine author name from git config user.name
        " unless $pstatus.success?

        parts     = full_name.split( " " )
        fname     = parts.shift
        fname     = "#{fname[0..0].upcase}#{fname[1..-1]}"
        suffix    = parts.map{ |p| p[0..0].upcase }.join( "" )

        "#{fname} #{suffix}".strip
      )
    end

    def working_tree_clean?
      git [ "diff --quiet", "diff --quiet --cached" ]
    end

    def working_tree_dirty?
      not working_tree_clean?
    end

    def rebased_to_master?  from=nil
      capture_git( "rev-list -n 1 #{from}..master" ).strip.empty?
    end

    def existing_comments?  branch=current_branch
      ref         = notes_ref( branch )
      # The list of all notes objects, and the commits they annotate, for the
      # given ref
      notes_list  = capture_git( "notes --ref #{ref} list" ).split  "\n"
      # simply checking ! notes_list.empty? tells us that there were some
      # comments on this ref at some point.  However, they may be comments on
      # commits from a previous topic with the same name, so we check to ensure
      # at least one of them is not an ancestor of origin/master (i.e. a commit
      # that has already been accepted).
      ! notes_list.find do |pair|
        commit = pair.split( ' ' ).last
        ! capture_git( "rev-list -n 1 origin/master..#{commit}" ).chomp.empty?
      end.nil?
    end

    def existing_comments spec=nil
      ref = notes_ref( *[ spec ].compact )
      capture_git( "notes --ref #{ref} show" ).chomp
    end

    def current_branch
      @@current_branch ||= capture_git( "branch --no-color" ).split( "\n" ).find do |b|
        b =~ %r{^\*}
      end[ 2..-1 ]
      @@current_branch = nil if @@current_branch == '(no branch)'

      @@current_branch
    end

    def guess_branch
      capture_git( "name-rev --name-only HEAD" )
    end

    def ref_age ref=current_branch
      date_str = capture_git  "log #{ref}^..#{ref} --pretty=%aD"
      return nil if date_str.empty?

      ( Date.today - Date.parse( date_str )).to_i
    end


    def display_git_output?
      @@display_git_output ||= false
    end

    def display_git_output!
      @@display_git_output = true
    end


    def switch_to_branch  branch, tracking=nil
      if branches.include?( branch )
        "checkout #{branch}"
      else
        "checkout -b #{branch} #{tracking}"
      end
    end

    def invoke_git_editor file
      system "#{git_editor} #{file}"
    end

    def cmd_redirect_suffix opts
      if !opts[:show] && !display_git_output?
        "> /dev/null 2> /dev/null"
      end
    end

    def git *args
      output, err, pstatus = _git  *args
      pstatus && pstatus.success?
    end

    def capture_git *args
      output, err, pstatus = _git  *args
      output
    end


    protected

    def _git  cmds=[], opts={}
      opts.assert_valid_keys    :must_succeed, :show

      cmds = [ cmds ] if cmds.is_a? String
      return if cmds.empty?

      cmd = "#{cmds.map{|c| "git #{c}"}.join( " && " )}"


      puts  cmd if GitTopic::global_opts[:verbose]
      debug cmd

      cmd_error   = ''
      cmd_output  = ''
      $pstatus = pstatus = IO.dpopen( cmd ) do
        on_output{ |o| cmd_output << o }
        on_error{ |e| cmd_error << e }
      end

      if display_git_output? || opts[:show]
        puts cmd_output
        puts cmd_error
      end

      debug cmd_output  unless cmd_output.empty?
      unless cmd_error.empty?
        if pstatus.success?
          debug cmd_error
        else
          warn  cmd_error
        end
      end

      if opts[:must_succeed] && ! pstatus.success?
        raise "
          Required git command failed:\n  #{cmd}.\n  re-run with --verbose to
          see git output.
        ".unindent
      end

      [ cmd_output, cmd_error, pstatus ]
    end

  end

  def self.included base
    base.extend ClassMethods
  end
end
