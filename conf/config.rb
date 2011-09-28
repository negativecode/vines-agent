# encoding: UTF-8

# This is the Vines agent configuration file. Restart the agent with
# 'vines-agent restart' after updating this file.

Vines::Agent::Config.configure do
  # Set the logging level to debug, info, warn, error, or fatal. The debug
  # level logs all XML sent and received by the agent.
  log :info

  domain 'wonderland.lit' do
    upstream 'localhost', 5222
    password 'secr3t'
    download 'data'
  end
end
