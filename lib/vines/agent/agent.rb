# encoding: UTF-8

module Vines
  module Agent
    # The main starting point for the Vines Agent process. Starts the
    # EventMachine processing loop and registers the agent with the configured
    # servers.
    class Agent
      include Vines::Log

      def initialize(config)
        @config = config
      end

      def start
        log.info('Vines agent started')
        at_exit { log.fatal('Vines agent stopped') }
        EM.run do
          @config.start
        end
      end
    end
  end
end
