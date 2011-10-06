# encoding: UTF-8

module Vines
  module Agent

    # A Config object is passed to the xmpp connections to give them access
    # to configuration information like server host names, passwords, etc.
    # This class provides the DSL methods used in the conf/config.rb file.
    class Config
      LOG_LEVELS = %w[debug info warn error fatal].freeze

      @@instance = nil
      def self.configure(&block)
        @@instance = self.new(&block)
      end

      def self.instance
        @@instance
      end

      def initialize(&block)
        @domain = nil
        instance_eval(&block)
        raise "must define a domain" unless @domain
      end

      def log(level)
        const = Logger.const_get(level.to_s.upcase) rescue nil
        unless LOG_LEVELS.include?(level.to_s) && const
          raise "log level must be one of: #{LOG_LEVELS.join(', ')}"
        end
        log = Class.new.extend(Vines::Log).log
        log.progname = 'vines-agent'
        log.level = const
      end

      def domain(name=nil, &block)
        if name
          raise 'multiple domains not allowed' if @domain
          @domain = Domain.new(name, &block)
        else
          @domain
        end
      end

      def start
        @domain.start
      end

      class Domain
        def initialize(name, &block)
          @name, @password, @upstream = name, nil, []
          instance_eval(&block) if block
          validate_domain(@name)
          raise "password required" unless @password && !@password.strip.empty?
          raise "duplicate upstream connections not allowed" if @upstream.uniq!
          unless @download
            @download = File.expand_path('data')
            FileUtils.mkdir_p(@download)
          end
        end

        def password(password=nil)
          if password
            @password = password
          else
            @password
          end
        end

        def download(dir)
          @download = File.expand_path(dir)
          begin
            FileUtils.mkdir_p(@download)
          rescue
            raise "can't create #{@download}"
          end
        end

        def upstream(host, port)
          raise 'host and port required for upstream connections' unless host && port
          @upstream << {host: host, port: port}
        end

        def start
          base = {
            password: @password,
            domain:   @name,
            download: @download
          }
          options = @upstream.map do |info|
            base.clone.tap do |opts|
              opts[:host] = info[:host]
              opts[:port] = info[:port]
            end
          end
          # no upstream so use DNS SRV discovery for host and port
          options << base if options.empty?
          options.each do |args|
            Vines::Agent::Connection.new(args).start
          end
        end

        private

        # Prevent domains in config files that won't form valid JID's.
        def validate_domain(name)
          jid = Blather::JID.new(name)
          raise "incorrect domain: #{name}" if jid.node || jid.resource
        end
      end
    end
  end
end