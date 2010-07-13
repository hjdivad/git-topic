
module GitTopic; end
module GitTopic::Git
  module ClassMethods

    protected

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

    def cmd_redirect_suffix( opts )
      if !opts[:show] && !display_git_output?
        "> /dev/null 2> /dev/null"
      end
    end

    def git( cmds=[], opts={} )
      cmds  = [cmds] if cmds.is_a? String
      redir = cmd_redirect_suffix( opts )
      system cmds.map{|c| "git #{c} #{redir}"}.join( " && " )
    end

    def capture_git( cmds=[] )
      cmds = [cmds] if cmds.is_a? String
      redir = "2> /dev/null" unless display_git_output?
      `#{cmds.map{|c| "git #{c} #{redir}"}.join( " && " )}`
    end

  end

  def self.included( base )
    base.extend ClassMethods
  end
end
