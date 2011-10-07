# encoding: UTF-8

module Vines
  module Agent
    module Command
      class Init
        def run(opts)
          raise 'vines-agent init <domain>' unless opts[:args].size == 1
          domain = opts[:args].first.downcase
          dir = File.expand_path(domain)
          raise "Directory already initialized: #{domain}" if File.exists?(dir)
          Dir.mkdir(dir)

          FileUtils.cp_r(File.expand_path("../../../../../conf", __FILE__), dir)

          data, log, pid = %w[data log pid].map do |sub|
            File.join(dir, sub).tap {|subdir| Dir.mkdir(subdir) }
          end

          update_config(domain, File.expand_path('conf/config.rb', dir))
          fix_perms(dir)

          puts "Initialized agent directory: #{domain}"
          puts "Run 'cd #{domain} && vines-agent start' to begin"
        end

        private

        # The config.rb file contains the agent's password so restrict access
        # to just the agent user.
        def fix_perms(dir)
          File.chmod(0600, File.expand_path('conf/config.rb', dir))
        end

        def update_config(domain, config)
          text = File.read(config)
          File.open(config, 'w') do |f|
            replaced = text
              .gsub('wonderland.lit', domain.downcase)
              .gsub('secr3t', Kit.auth_token)
            f.write(replaced)
          end
        end
      end
    end
  end
end
