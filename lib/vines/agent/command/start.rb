# encoding: UTF-8

module Vines
  module Agent
    module Command
      class Start
        def run(opts)
          raise 'vines-agent [--pid FILE] start' unless opts[:args].size == 0
          require opts[:config]
          agent = Vines::Agent::Agent.new(Config.instance)
          daemonize(opts) if opts[:daemonize]
          agent.start
        end

        private

        def daemonize(opts)
          daemon = Vines::Daemon.new(:pid => opts[:pid], :stdout => opts[:log],
            :stderr => opts[:log])
          if daemon.running?
            raise "The vines agent is running as process #{daemon.pid}"
          else
            puts "The vines agent has started"
            daemon.start
          end
        end
      end
    end
  end
end