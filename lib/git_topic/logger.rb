require 'fileutils'

module GitTopic
  class << self; attr_accessor :global_opts end
  self.global_opts = {}

  class << self
    %w( debug info warn error fatal unknown ).each do |m|
      define_method m do |*args, &block|
        GitTopic::Logger.send( m, *args, &block )
      end
    end
  end
end


module GitTopic::Logger
  class << self
    def add method, undecorated_message, *args, &block
      return if GitTopic.global_opts[:no_log]

      message = 
        unless undecorated_message.blank?
          sprintf '%-5s %s %s',
                  method.upcase,
                  DateTime.now.strftime( '[%d %b %Y  %H:%M:%S]' ),
                  undecorated_message
        else
          ''
        end

      logger.send method, message, *args, &block
    end

    %w( debug info warn error fatal unknown ).each do |m|
      define_method m do |*args, &block|
        GitTopic::Logger.add( m, *args, &block )
      end
    end


    protected

    def logger
      @logger ||= (
        log_dir = "#{ENV['HOME']}/.git_topic"
        FileUtils.mkdir( log_dir ) unless File.exists? log_dir

        ActiveSupport::BufferedLogger.new "#{ENV['HOME']}/.git_topic/log"
      )
    end
  end
end
