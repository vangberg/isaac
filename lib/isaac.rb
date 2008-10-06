require 'socket'
module Isaac
  def self.app
    @app ||= Application.new
  end

  Config = Struct.new(:nick, :server, :port)

  class Application
    def initialize
      @events = Hash.new {|k,v| k[v] = []}
      @transfered = 0
    end

    def start
      connect
    end

    def config(&block)
      @config = Config.new
      block.call(@config)
    end

    def helpers(&block)
      EventContext.class_eval(&block)
    end

    def on(type, match=nil, &block)
      @events[type] << Event.new(match, block)
    end

    # TODO Fix this crappy name.
    def dslify(params={}, &block)
      event = Event.new(:dsl, block)
      event.invoke(params).commands.each {|cmd| iputs cmd}
    end

    private
    # Write to IRC. Counts amount of transfered data, pings if necessary, to 
    # avoid excess flood. Yet another crappy name.
    def iputs(msg)
      if (@transfered + msg.size) > 1472
        @irc.puts "PING :twittirc"
        @transfered = 0
      end
      @irc.puts msg
      @transfered += msg.size
    end

    def connect
      @irc = TCPSocket.open(@config.server, @config.port)
      register
      @events[:connect].first.invoke.commands.each {|cmd| iputs cmd}
      while line = @irc.gets
        handle line
      end
    end

    def register
      iputs "NICK #{@config.nick}"
      iputs "USER foobar twitthost twittserv :My Name"
    end

    def handle(line)
      # TODO this is ugly as well. do something about the args.
      p line if ARGV[0] == "-v"
      case line
      when /^:(\S+)!\S+ PRIVMSG (\S+) :?(.*)/
        nick        = $1
        channel     = $2
        message     = $3
        type = channel.match(/^#/) ? :channel : :private
        if event = @events[type].detect {|e| message =~ e.match}
          event.invoke(:nick => nick, :channel => channel, :message => message)
          event.commands.each {|cmd| iputs cmd}
        end
      when /^:\S+ ([4-5]\d\d) \S+ (\S+)/
        error = $1
        nick = channel = $2
        if event = @events[:error].detect {|e| error == e.match.to_s }
          event.invoke(:nick => nick, :channel => channel)
          event.commands.each {|cmd| iputs cmd}
        end
      when /^PING (\S+)/
        #TODO not sure this is correect
        iputs "PONG #{$1}" 
      end
    end
  end

  class Event
    attr_accessor :match, :block, :commands
    def initialize(match, block)
      @match    = match
      @block    = block
      @commands = []
    end

    def invoke(params={})
      context = EventContext.new
      params[:match] = params[:message].match(@match) if @match && params[:message]
      context.instance_eval do
        @nick         = params[:nick]
        @channel      = params[:channel]
        @message      = params[:message]
        @match        = params[:match]
      end
      context.instance_eval(&@block)
      @commands = context.commands
      self
    end
  end

  class EventContext
    attr_accessor :nick, :channel, :message, :match, :commands
    def initialize
      @commands = []
    end

    def raw(command)
      @commands << command
    end

    def msg(recipient, text)
      raw("PRIVMSG #{recipient} :#{text}")
    end

    def join(*channels)
      channels.each {|channel| raw("JOIN #{channel}")}
    end
  end
end

# Assign dialplan methods to current Isaac instance
%w(config helpers on).each do |method|
  eval(<<-EOF)
    def #{method}(*args, &block)
      Isaac.app.#{method}(*args, &block)
    end
  EOF
end

at_exit do
  raise $! if $!
  Isaac.app.start
end
