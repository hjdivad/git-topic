# encoding: utf-8

require 'active_support'
require 'active_support/core_ext'


class String
    def cleanup
        indent = (index /^([ \t]+)/; $1) || ''
        regex = /^#{Regexp::escape( indent )}/
        strip.gsub regex, ''
    end

    def oneline
        strip.gsub( /\n\s+/, '' )
    end

    # Annoyingly, the useful version of pluralize in texthelpers isn't in the
    # string core extensions.
    def pluralize_with_count( count )
      count > 1 ? pluralize_without_count : singularize
    end
    alias_method_chain :pluralize, :count
end


class Object
    # Deep duplicate via remarshaling.  Not always applicable.
    def ddup
        Marshal.load( Marshal.dump( self ))
    end
end
