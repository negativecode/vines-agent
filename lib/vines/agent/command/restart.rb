# encoding: UTF-8

module Vines
  module Agent
    module Command
      class Restart
        def run(opts)
          Stop.new.run(opts)
          Start.new.run(opts)
        end
      end
    end
  end
end