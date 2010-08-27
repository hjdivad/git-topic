
module GitTopic; end

module GitTopic::Naming
  module ClassMethods

    protected

    def backup_branch( topic )
      "backup/#{user}/#{strip_namespace topic}"
    end

    def wip_branch( ref )
      parts     = topic_parts( ref )
      wip_user  = parts[:user] || user
      topic     = parts[:topic]
      "wip/#{wip_user}/#{topic}"
    end

    def rejected_branch( topic )
      "rejected/#{user}/#{strip_namespace topic}"
    end

    def review_branch( topic, user=user )
      "review/#{user}/#{strip_namespace topic}"
    end

    def remote_rejected_branch( topic, user=user )
      "rejected/#{user}/#{strip_namespace topic}"
    end

    def remote_branch( spec=current_branch )
      parts = topic_parts( spec )

      remote_branches.find do |remote_branch|
        bp = topic_parts( remote_branch )

        parts.all? do |part, value|
          bp[part] == value
        end
      end
    end


    def find_remote_review_branch( topic )
      others_review_branches.find{|b| b.index topic}
    end

    def strip_namespace( ref )
      if ref =~ %r{(?:wip|rejected|review)/(?:(?:\S*)/)?(.*)}
        $1
      else
        ref
      end
    end


    def notes_ref( branch=current_branch )
      user, topic = user_topic_name( branch, :lookup => true )
      "refs/notes/reviews/#{user}/#{topic}"
    end


    def user_topic_name( ref, opts={} )
      p = topic_parts( ref, opts )
      [ p[:user], p[:topic ] ]
    end

    def topic_parts( ref, opts={} )
      p = {}
      parts = ref.split( '/' )

      parts.shift if parts.first == 'remotes'
      parts.shift if parts.first == "origin"

      case parts.size
      when 3
        p[:namespace], p[:user], p[:topic] = parts
      when 2
        first_part = (parts.first =~ /(wip|review|rejected)/) ? :namespace : :user
        p[ first_part ], p[:topic] = parts
      when 1
        p[:topic] = parts.first
      else
        raise "Unexpected topic: #{ref}"
      end

      if opts[:lookup] && p[:user].nil?
        remote_branches_organized.find do |namespace, v|
          v.find do |user, vv|
            if vv.find{ |topic| topic == p[:topic] }
              p[:user]        = user
              p[:namespace]   = namespace
              true
            end
          end
        end
      end

      p
    end


    def user
      @@user ||= (ENV['USER'] || `whoami`)
    end

    def current_namespace
      current_branch =~ %r{(wip|review|rejected)/(\S*)}
      $1
    end

    def current_topic
      current_branch =~ %r{wip/\S*?/(\S*)}
      $1
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
        namespace_ut[:review]   ||= {}
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
        !ref.strip.empty? && ref.index( ',' ).nil?
      end.strip[ 1..-2 ] # chomp the leading and trailing parenthesis
    end

    def oldest_review_user_topic
      user_topic_name( oldest_review_branch )
    end

    def on_review_branch?
      current_branch =~ %r{^review/}
    end

  end

  def self.included( base )
    base.extend ClassMethods
  end
end
