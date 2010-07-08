# encoding: utf-8
require 'git-topic'


# Disable caching on GitTopic for specs since we're calling the methods directly
# rather than assuming atmoic invocations.
module GitTopic
  class << self
    %w( current_branch remote_branches remote_branches_organized branches
        ).each do |m|

      define_method( "#{m}_with_nocache" ) do
        rv = send( "#{m}_without_nocache" )
        self.class_variable_set( "@@#{m}", nil )
        rv
      end
      alias_method_chain m.to_sym, :nocache
    end
  end
end


# Track original $stdout, $stderr write methods so we can “unmock” them for
# debugging

class << $stdout
  alias_method :real_write, :write
end
class << $stderr
  alias_method :real_write, :write
end


class Object
  def debug
    # For debugging, restore stubbed write
    class << $stdout
      alias_method :write, :real_write
    end
    class << $stderr
      alias_method :write, :real_write
    end

    require 'ruby-debug'
    debugger
  end
end
