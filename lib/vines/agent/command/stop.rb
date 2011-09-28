# encoding: UTF-8

module Vines
  module Agent
    module Command
      class Stop
        def run(opts)
          raise 'vines-agent [--pid FILE] stop' unless opts[:args].size == 0
          daemon = Vines::Daemon.new(:pid => opts[:pid])
          if daemon.running?
            daemon.stop
            puts 'The vines agent has been shutdown'
          else
            puts 'The vines agent is not running'
          end
        end
      end
    end
  end
end