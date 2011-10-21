# encoding: UTF-8

module Vines
  module Agent

    # Provides a shell session to execute commands as a particular user. All
    # commands are forked and executed in a child process to isolate them from
    # the agent process. Keeping the same session open between commands allows
    # stateful commands like 'cd' to work properly.
    class Shell
      include Vines::Log

      attr_writer :permissions

      # Create a new shell session to asynchronously execute commands for this
      # JID. The JID is validated in the permissions Hash before executing
      # commands.
      def initialize(jid, permissions)
        @jid, @permissions = jid, permissions
        @user, @commands = allowed_users.first, EM::Queue.new
        spawn(@user)
        process_command_queue
      end

      # Queue the shell command to run as soon as the currently executing tasks
      # complete. Yields the shell output to the callback block.
      def run(command, &callback)
        if reset?(command)
          callback.call(run_built_in(command))
        else
          @commands.push({command: command.strip, callback: callback})
        end
      end

      private

      # Schedule a queue pop on the EM thread to handle the next command.
      # This guarantees in-order shell command processing while not blocking
      # the EM loop, waiting for long running tasks to complete.
      def process_command_queue
        @commands.pop do |command|
          op = proc do
            if built_in?(command[:command])
              run_built_in(command[:command])
            else
              run_in_slave(command[:command])
            end
          end
          cb = proc do |output|
            command[:callback].call(output)
            process_command_queue
          end
          EM.defer(op, cb)
        end
      end

      def run_in_slave(command)
        log.info("Running #{command} as #{@user}")
        out, err = @shell.execute(command)
        output = [].tap do |arr|
          arr << out if out && !out.empty?
          arr << err if err && !err.empty?
        end.join("\n")
        output.empty? ? '-> command completed' : output
      rescue
        spawn(@user)
        '-> restarted shell'
      end

      # Fork a child process in which to run a shell as this user. Return
      # the slave and its remote shell proxy. The agent process must be run
      # as root for the user switch to work.
      def spawn(user)
        log.info("Starting shell as #{user}")
        @slave.shutdown(quiet: true) if @slave
        Thread.new do # so em thread won't die on @slave.shutdown
          slave = Slave.new(psname: "vines-session-#{user}") do
            uid = Process.euid

            # switch user so shell is run by non-root
            passwd = Etc.getpwnam(user)
            Process.egid = Process.gid = passwd.gid
            Process.euid = Process.uid = passwd.uid

            # fork shell as non-root user
            ENV.clear
            ENV['HOME'] = passwd.dir
            ENV['USER'] = user
            Dir.chdir(ENV['HOME'])

            shell = Session::Bash::Login.new

            # switch back so domain socket is owned by root
            Process.euid = Process.uid = uid
            shell
          end
          File.chmod(0700, slave.socket)
          @slave, @shell = [slave, slave.object]
        end.join
      end

      # The agent supports special, built-in "vines" commands beginning with
      # 'v' that the agent executes itself, without invoking a shell.  For example,
      # +v user root+ will change the user account that future shell commands
      # execute as.
      def built_in?(command)
        command.strip.start_with?('v ')
      end

      # Run a built-in vines command without using a shell. Return output to
      # be sent back to the user.
      def run_built_in(command)
        _, command, *args = command.strip.split(/\s+/)
        case command
          when 'user'    then user_command(args)
          when 'reset'   then reset_command(args)
          when 'version' then version_command(args)
          when 'help'    then help_command(args)
          else '-> usage: v user|reset|version|help'
        end
      end

      def help_command(args)
        [
          "Usage:",
          "  v user [name]  Display the current user or switch users.",
          "  v reset        Stops the shell session and starts a new one.",
          "  v version      Display the agent's version.",
          "  v help         Provide help on vines commands."
         ].join("\n")
      end

      def version_command(args)
        return "-> usage: v version" unless args.empty?
        Vines::Agent::VERSION
      end

      # Run the +v user+ built-in vines command to list or change the current
      # unix account executing shell commands.
      def user_command(args)
        return "-> current: #{@user}\n   allowed: #{allowed_users.join(', ')}" if args.empty?
        return "-> usage: v user [name]" if args.size > 1
        return "-> user switch not allowed" unless allowed?(args.first)
        @user = args.first
        spawn(@user)
        "-> switched user to #{@user}"
      end

      def reset?(command)
        v, command, *args = command.strip.split(/\s+/)
        v == 'v' && command == 'reset'
      end

      def reset_command(args)
        return "-> usage: v reset" unless args.empty?
        @commands = EM::Queue.new
        spawn(@user)
        process_command_queue
        "-> reset shell"
      end

      # Return true if the current JID is allowed to run commands as the given
      # user name on this system.
      def allowed?(user)
        jids = @permissions[user] || []
        valid = jids.include?(@jid) && exists?(user)
        log.warn("#{@jid} denied access to #{user}") unless valid
        valid
      end

      def exists?(user)
        Etc::getpwnam(user) rescue false
      end

      # Return the list of unix user accounts this user is allowed to access.
      def allowed_users
        @permissions.select do |unix, jids|
          jids.include?(@jid) && exists?(unix)
        end.keys.sort
      end
    end
  end
end
