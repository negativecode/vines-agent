# encoding: UTF-8

module Vines
  module Agent

    # Connects the agent process to the chat server and provides service
    # discovery and command execution abilities. Users are authorized against
    # an access control list before being allowed to run commands.
    class Connection
      include Vines::Log

      NS = 'http://getvines.com/protocol'.freeze
      SYSTEMS = 'http://getvines.com/protocol/systems'.freeze

      def initialize(options)
        domain, password, host, port, download, conf =
          *options.values_at(:domain, :password, :host, :port, :download, :conf)

        certs = File.expand_path('certs', conf)
        @permissions, @services, @sessions, @component = {}, {}, {}, nil
        @ready = false
        @mtx = Mutex.new

        jid = Blather::JID.new(fqdn, domain, 'vines')
        @stream = Blather::Client.setup(jid, password, host, port, certs)

        @stream.register_handler(:stream_error) do |e|
          log.error(e.message)
          true # prevent EM.stop
        end

        @stream.register_handler(:disconnected) do
          log.info("Stream disconnected, reconnecting . . .")
          EM::Timer.new(rand(16) + 5) do
            self.class.new(options).start
          end
          true # prevent EM.stop
        end

        @stream.register_handler(:ready) do
          # [AM] making sure we are to init once
          #      unless @ready is not enough for an obvious reason 
          @mtx.synchronize {
            unless @ready
              log.info("Connected #{@stream.jid} agent to #{host}:#{port}")
              log.warn("Agent must run as root user to allow user switching") unless root?
              @ready = true
              startup
            end
          }
        end

        @stream.register_handler(:subscription, :request?) do |node|
          # ignore, rather than refuse, requests from users lacking
          # permissions, so agents are invisible to them
          @stream.write(node.approve!) if valid_user?(node.from)
        end

        @stream.register_handler(:file_transfer) do |iq|
          transfer_file(iq)
        end

        @stream.register_handler(:disco_info, :get?) do |node|
          disco_info(node)
        end

        @stream.register_handler(:iq, '/iq[@type="set"]/ns:query', :ns => SYSTEMS) do |node|
          update_permissions(node)
        end

        @stream.register_handler(:iq, '/iq[@type="get"]/ns:query', :ns => 'jabber:iq:version') do |node|
          version(node)
        end

        @stream.register_handler(:message, :chat?, :body) do |msg|
          process_message(msg)
        end
      end

      def start
        @stream.run
      end

#     —————————————————————————————————————————————————————————————————————————
      private
#     —————————————————————————————————————————————————————————————————————————

      # After the bot connects to the chat server, discover the component, send
      # our ohai system description data, and initialize permissions.
      def startup
        cb = lambda do |component, iter|
          if component
            log.info("Found unknown component at #{component}, checking…")
            info = Blather::Stanza::DiscoInfo.new
            info.to = component.jid.domain
            @stream.write_with_handler(info) do |reply|
              unless reply.error? 
                EM::Iterator.new(reply.features).each { |f, it|
                  if f.var == NS
                    log.info("Found vines component at #{component}!")
                    # FIXME What if we have more than one component found?
                    #       We do likely want to have a stack here instead 
                    #          of object for the “@component”         
                    @component = component.jid
                    send_system_info
                    request_permissions
                  end
                  it.next
                } 
              end
            end
          else
            log.info("Vines component not found, rediscovering . . .")
            EM::Timer.new(10) { discover_component(&cb) }
          end
          iter.next
        end
        discover_component(&cb)
      end

      def version(node)
        return unless from_service?(node) || valid_user?(node.from)
        iq = Blather::Stanza::Iq::Query.new(:result)
        iq.id, iq.to = node.id, node.from
        iq.query.add_child("<name>Vines Agent</name>")
        iq.query.add_child("<version>#{VERSION}</version>")
        @stream.write(iq)
      end

      def disco_info(node)
        return unless from_service?(node) || valid_user?(node.from)
        disco = Blather::Stanza::DiscoInfo.new(:result)
        disco.id = node.id
        disco.to = node.from
        disco.identities = {
          name: 'Vines Agent',
          type: 'bot',
          category: 'client'
        }
        disco.features = %w[
          http://jabber.org/protocol/bytestreams
          http://jabber.org/protocol/disco#info
          http://jabber.org/protocol/si
          http://jabber.org/protocol/si/profile/file-transfer
          http://jabber.org/protocol/xhtml-im
          jabber:iq:version
        ]
        @stream.write(disco)
      end

      def transfer_file(iq)
        return unless from_service?(iq) || valid_user?(iq.from)
        name, size = iq.si.file['name'], iq.si.file['size'].to_i
        log.info("Receiving file: #{name}")
        transfer = Blather::FileTransfer.new(@stream, iq)
        file = absolute_path(download, name) rescue nil
        if file
          transfer.accept(Blather::FileTransfer::SimpleFileReceiver, file, size)
        else
          transfer.decline
        end
      end

      def absolute_path(dir, name)
        File.expand_path(name, dir).tap do |absolute|
          raise 'path traversal' unless File.dirname(absolute) == dir
        end
      end

      # Collect and send ohai system data for this machine back to the
      # component.
      def send_system_info
        system = Ohai::System.new.tap do |sys|
          sys.all_plugins
        end
        iq = Blather::Stanza::Iq::Query.new(:set).tap do |node|
          node.to = @component
          node.query.content = system.to_json
          node.query.namespace = SYSTEMS
        end
        @stream.write(iq)
      end

      # Return the fully qualified domain name for this machine. This is used
      # to determine the agent's JID.
      def fqdn
        system = Ohai::System.new
        system.require_plugin('os')
        system.require_plugin('hostname')
        system.fqdn.downcase
      end

      # Use service discovery to find the JID of our Vines component. We ask the
      # server for its list of components, then ask each component for it's info.
      # The component broadcasting the http://getvines.com/protocol feature is our
      # Vines service.
      def discover_component(&cb)
        disco = Blather::Stanza::DiscoItems.new
        disco.to = @stream.jid.domain
        @stream.write_with_handler(disco) do |result|
          unless result.error? 
            EM::Iterator.new(result.items).each &cb
          end
        end
      end

      # Download the list of unix user accounts and the JID's that are allowed
      # to use them. This is used to determine if a change user command like
      # +v user root+ is allowed.
      def request_permissions
        iq = Blather::Stanza::Iq::Query.new(:get).tap do |node|
          node.to = @component
          node.query['name'] = @stream.jid.node
          node.query.namespace = SYSTEMS
        end
        @stream.write_with_handler(iq) do |reply|
          update_permissions(reply) unless reply.error?
        end
      end

      def update_permissions(node)
        return unless node.from == @component
        obj = JSON.parse(node.content) rescue {}
        @permissions = obj['permissions'] || {}
        @services = (obj['services'] || {}).map {|s| s['jid'] }
        @sessions.values.each {|shell| shell.permissions = @permissions }
      end

      # Execute the incoming XMPP message as a shell command if the sender is
      # allowed to execute commands on this agent as the requested user name.
      def process_message(message)
        bare, full = message.from.stripped.to_s, message.from.to_s
        forward_to = nil

        if from_service?(message)
          jid = message.xpath('/message/ns:jid', 'ns' => NS).first
          jid = Blather::JID.new(jid.content) rescue nil
          return unless jid
          bare, full = jid.stripped.to_s, jid.to_s
          forward_to = full
        end

        return unless valid_user?(bare)
        session = @sessions[full] ||= Shell.new(bare, @permissions)
        session.run(message.body.strip) do |output|
          @stream.write(reply(message, output, forward_to))
        end
      end

      # Reply to the sender's message with the command's output. The component
      # uses the thread attribute to pair command messages with their output
      # replies.
      def reply(message, body, forward_to)
        Blather::Stanza::Message.new(message.from, body).tap do |node|
          node << node.document.create_element('jid', forward_to, xmlns: NS) if forward_to
          node.thread = message.thread if message.thread
          node.xhtml = '<span style="font-family:Menlo,Courier,monospace;"></span>'
          span = node.xhtml_node.elements.first
          body.each_line do |line|
            span.add_child(Nokogiri::XML::Text.new(line.chomp, span.document))
            span.add_child(span.document.create_element('br'))
          end
        end
      end

      # Return true if the JID is allowed to run commands as a unix user
      # account on the system. Return false if the agent doesn't have a
      # permissions entry for this JID.
      def valid_user?(jid)
        jid = jid.stripped.to_s if jid.respond_to?(:stripped)
        valid = !!@permissions.find {|unix, jids| jids.include?(jid) }
        log.warn("Denied access to #{jid}") unless valid
        valid
      end

      # Return true if the stanza was sent to the agent by a service JID to
      # which the agent belongs. The agent will only reply to stanzas sent from
      # users it trusts or from services of which it's a member. Stanzas
      # received from untrusted JID's are ignored.
      def from_service?(node)
        @services.include?(node.from.stripped.to_s.downcase)
      end

      # Return true if the agent process is owned by root. Switching users with
      # +v user+ is only possible when running as root.
      def root?
        Process.uid == 0
      end
    end
  end
end
