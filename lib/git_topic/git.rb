
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
          whatever
        " unless $?.success?

        parts     = full_name.split( " " )
        fname     = parts.shift
        fname     = "#{fname[0..0].upcase}#{fname[1..-1]}"
        suffix    = parts.map{ |p| p[0..0].upcase }.join( "" )

        "#{fname} #{suffix}".strip
      )
    end

    def working_tree_clean?
      git [ "diff --quiet", "diff --quiet --cached" ]
      $?.success?
    end

    def working_tree_dirty?
      not working_tree_clean?
    end

    def existing_comments?( branch=current_branch )
      ref = notes_ref( branch )
      not capture_git( "notes --ref #{ref} list" ).chomp.empty?
    end

    def existing_comments
      capture_git( "notes --ref #{notes_ref} show" ).chomp
    end


    def display_git_output?
      @@display_git_output ||= false
    end

    def display_git_output!
      @@display_git_output = true
    end


    def switch_to_branch( branch, tracking=nil )
      if branches.include?( branch )
        "checkout #{branch}"
      else
        "checkout -b #{branch} #{tracking}"
      end
    end

    def invoke_git_editor( file )
      system "#{git_editor} #{file}"
    end

    def cmd_redirect_suffix( opts )
      if !opts[:show] && !display_git_output?
        "> /dev/null 2> /dev/null"
      end
    end

    def git( cmds=[], opts={} )
      opts.assert_valid_keys    :must_succeed

      cmds  = [cmds] if cmds.is_a? String
      redir = cmd_redirect_suffix( opts )
      cmd = cmds.map{|c| "git #{c} #{redir}"}.join( " && " )

      puts cmd if GitTopic::global_opts[:verbose]
      result = system( cmd )

      if opts[:must_succeed] && !$?.success?
        raise "
          Required git command failed:\n  #{cmd}.\n  re-run with --verbose to
          see git output.
        ".cleanup
      end

      result
    end

    def capture_git( cmds=[], opts={} )
      opts.assert_valid_keys    :must_succeed

      cmds = [cmds] if cmds.is_a? String
      redir = "2> /dev/null" unless display_git_output?
      cmd = "#{cmds.map{|c| "git #{c} #{redir}"}.join( " && " )}"

      puts cmd if GitTopic::global_opts[:verbose]
      result = `#{cmd}`

      if opts[:must_succeed] && !$?.success?
        raise "
          Required git command failed:\n  #{cmd}.\n  re-run with --verbose to
          see git output.
        ".cleanup
      end

      result
    end

  end

  def self.included( base )
    base.extend ClassMethods
  end
end
