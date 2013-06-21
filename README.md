# Welcome to Vines Agent

Vines Agent executes shell commands sent by users on remote machines. Users are
authorized against an access control list before being allowed to run commands.
The agent is an XMPP bot that connects to the Vines chat server. It relies on
the component provided by the vines-services gem to send and receive commands.

Users may run commands as any unix account, to which they've been granted access,
on the system. While the agent runs as root, user commands run as less privileged
accounts.

Additional documentation can be found at www.getvines.org.

## Usage

```
$ gem install vines-agent
$ vines-agent init wonderland.lit
$ cd wonderland.lit && vines-agent start
```

## Dependencies

Vines Agent requires Ruby 1.9.3 or better. Instructions for installing the
needed OS packages, as well as Ruby itself, are available at
http://www.getvines.org/ruby.

## Development

```
$ script/bootstrap
$ script/tests
```

## Contact

* David Graham <david@negativecode.com>

## License

Vines Agent is released under the MIT license. Check the LICENSE file for details.
