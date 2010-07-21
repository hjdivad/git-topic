
module GitTopic; end

module GitTopic::Naming
  module ClassMethods

    protected

    def backup_branch( topic )
      "backup/#{user}/#{strip_namespace topic}"
    end

    def wip_branch( topic )
      "wip/#{user}/#{strip_namespace topic}"
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


    def find_remote_review_branch( topic )
      others_review_branches.find{|b| b.index topic}
    end

    def strip_namespace( ref )
      if ref =~ %r{(?:wip|rejected|review)/\S*/(.*)}
        $1
      else
        ref
      end
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

    def topic_parts( ref )
      p = {}
      parts = ref.split( '/' )
      case parts.size
      when 2
        p[:user], p[:topic] = parts
      when 1
        p[:topic] = parts.first
      else
        raise "Unexpected topic: #{ref}"
      end
      p
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
