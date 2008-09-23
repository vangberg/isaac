require 'socket'
module Isaac
  module IRC
    PRIVMSG = /^:(\S+)!\S+ PRIVMSG (\S+) :?(.*)/
  end

  class Application
    include IRC
    def initialize(options={})
      @routes = {}
      @route_keys = []  # Index of keys, to preserve order.
      @options = options
    end

    def start(&block)
      instance_eval(&block)
      connect
    end

    private
    # Refactor to seperate module?
    def on(match, &block)
      @routes[match] = block
      @route_keys << match
    end

    def on_connect(&block)
    end

    def connect
      @irc = TCPSocket.open(@options[:server], @options[:port])
      register

      while line = @irc.gets
        p line
        case line
        when PRIVMSG
          e = EventContext.new(line, @routes, @route_keys)
          e.commands.each {|cmd| @irc.puts(cmd)}
        end
      end
    end

    def register
      @irc.puts "NICK #{@options[:nick]}"
      @irc.puts "USER foobar twitthost twittserv :My Name"
    end
  end

  class EventContext
    include IRC
    attr_reader :origin, :destination, :message, :commands

    def initialize(input, routes, route_keys)
      @commands = []

      if match = input.match(PRIVMSG)
        @origin       = match[1]
        @destination  = match[2]
        @message      = match[3]

        key = route_keys.select {|x| x =~ message}.first
        instance_eval(&routes[key]) if routes[key].kind_of?(Proc)
      end
    end

    private
    def raw(command)
      @commands << command
    end

    def msg(recipient, text)
      raw("PRIVMSG #{recipient} :#{text}")
    end

    def join(channel)
      raw("JOIN #{channel}")
    end
  end
end
