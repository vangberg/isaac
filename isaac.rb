require 'socket'
module Isaac
  module IRC
    PRIVMSG = /^:(\S+)!\S+ PRIVMSG (\S+) :?(.*)/
  end

  class Application
    include IRC
    def initialize(options={})
      @options = options
      @on_connect = nil
      @events = []
    end

    def start(&block)
      instance_eval(&block)
      connect
    end

    private
    # Refactor to seperate module?
    def on(match, &block)
      @events << Event.new(:msg, match, &block)
    end

    def on_connect(&block)
      @on_connect = Event.new(:connect, &block)
    end

    def connect
      @irc = TCPSocket.open(@options[:server], @options[:port])
      register
      @on_connect.invoke
      @on_connect.commands.each {|command| @irc.puts command}

      while line = @irc.gets
        p line
        case line
        when PRIVMSG
          origin      = $1
          destination = $2
          message     = $3
          if event = @events.detect {|e| message.match(e.match) }
            # Invoke event with match data
            event.invoke(:origin => origin, :destination => destination, :message => message)
            event.commands.each {|command| @irc.puts command}
          end
        end
      end
    end

    def register
      @irc.puts "NICK #{@options[:nick]}"
      @irc.puts "USER foobar twitthost twittserv :My Name"
    end
  end

  class Event
    attr_accessor :match, :block, :type, :commands
    def initialize(type, match=nil, &block)
      @type     = type
      @match    = match
      @block    = block
      @commands = []
    end

    def invoke(params={})
      case type
      when :msg
        @origin      = params[:origin]
        @destination = params[:destination]
        @message     = params[:message]
      end

      instance_eval &@block
    end

    private
    attr_accessor :origin, :destination, :message
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
