require 'socket'
module Isaac
  # Returns the current instance of Isaac::Application
  def self.app
    @app ||= Application.new
  end

  # Use EventContext methods such as msg(), join() etc. outside on()-events. See +examples/execute.rb+.
  #   Isaac.execute do
  #     msg 'harryjr', 'you're awesome'
  #   end
  def self.execute(&block)
    # add params?
    app.execute(&block)
  end

  Config = Struct.new(:nick, :server, :port)

  # These are top level methods you use to construct your bot.
  class Application
    def initialize #:nodoc:
      @events = Hash.new {|k,v| k[v] = []}
      @transfered = 0
      @lock = false
    end

    def start #:nodoc:
      connect
    end

    # Configure the bot:
    #   config do |c|
    #     c.server  = "irc.freenode.net"
    #     c.nick    = "AwesomeBot"
    #     c.port    = 6667
    #   end
    def config(&block)
      @config = Config.new
      block.call(@config)
      @config
    end

    # Methods defined inside the helpers-block will be available to on()-events at execution time.
    def helpers(&block)
      EventContext.class_eval(&block)
    end

    # on()-events responds to certain actions. Depending on +type+ certain local variables are available: +nick+, +channel+, +message+ and in particular +match+, which contains a MatchData object returned by the given regular expression.
    #
    # * Do something after connection has been established, e.g. join channels.
    #     on :connect do
    #       join "#awesome_channel", "#lee_marvin_fans"
    #     end
    # * Respond to private messages matching a given regular expression.
    #     on :privage, /^echo (.*)/ do
    #       msg nick, "You said '#{match[1]}!"
    #     end
    # * Respond to messages matching a given regular expression send to a channel.
    #     on :channel, /quote/ do
    #       msg channel, "#{nick} requested a quote: 'Smoking, a subtle form a suicide.' - Vonnegut"
    #     end
    # * Respond to error codes, according to the RFC.
    #     on :error, 401 do
    #       # Execute this if you try to send a message to a non-existing nick/channel.
    #     end
    def on(type, match=nil, &block)
      @events[type] << Event.new(match, block)
    end

    def execute(params={}, &block) #:nodoc:
      event = Event.new(:dsl, block)
      event.invoke(params).commands.each {|cmd| @queue << cmd}
    end

    private
    def connect
      @irc = TCPSocket.open(@config.server, @config.port)
      @queue = Queue.new(@irc)
      register
      @events[:connect].first.invoke.commands.each {|cmd| @queue << cmd} if @events[:connect].first
      while line = @irc.gets
        handle line
      end
    end

    def register
      @queue << "NICK #{@config.nick}"
      @queue << "USER foobar twitthost twittserv :My Name"
    end

    def handle(line)
      p line if ARGV[0] == "-v" # TODO this is ugly as well. do something about the args.

      # Could this be DRY'ed?
      case line
      when /^:(\S+)!\S+ PRIVMSG (\S+) :?(.*)/
        nick        = $1
        channel     = $2
        message     = $3
        type = channel.match(/^#/) ? :channel : :private
        if event = @events[type].detect {|e| message =~ e.match}
          event.invoke(:nick => nick, :channel => channel, :message => message)
          event.commands.each {|cmd| @queue << cmd}
        end
      when /^:\S+ ([4-5]\d\d) \S+ (\S+)/
        error = $1
        nick = channel = $2
        if event = @events[:error].detect {|e| error == e.match.to_s }
          event.invoke(:nick => nick, :channel => channel)
          event.commands.each {|cmd| @queue << cmd}
        end
      when /^PING (\S+)/
        #TODO not sure this is correect
        @queue << "PONG #{$1}" 
      when /^:\S+ PONG \S+ :excess/
        @queue.lock = false
      end
    end
  end

  class Queue
    attr_accessor :lock
    def initialize(socket)
      @socket     = socket
      @queue      = []
      @transfered = 0
      @lock       = false
      transmit
    end

    def << (msg)
      @queue << msg
    end

    def transmit
      Thread.start do
        loop do
          unless @lock || @queue.empty?
            p ">>>>> #{@transfered}"
            msg = @queue.shift
            if (@transfered + msg.size) > 1472
              @socket.puts "PING :excess"
              @lock = true
              @transfered = 0
            else
              @socket.puts msg
              @transfered += msg.size
            end
          end
          sleep 0.1
        end
      end
    end
  end

  class Event #:nodoc:
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

    # Send a raw IRC message.
    def raw(command)
      @commands << command
    end

    # Send a message to nick/channel.
    def msg(recipient, text)
      raw("PRIVMSG #{recipient} :#{text}")
    end

    # Join channel(s):
    #   join "#awesome_channel"
    #   join "#rollercoaster", "#j-lo"
    def join(*channels)
      channels.each {|channel| raw("JOIN #{channel}")}
    end

    # Part channel(s):
    #   part "#awesome_channel"
    #   part "#rollercoaster", "#j-lo"
    def part(*channels)
      channels.each {|channel| raw("PART #{channel}")}
    end

    # Kick nick from channel, with optional comment.
    def kick(channel, nick, comment=nil)
      if comment
        raw("KICK #{channel} #{nick} :#{comment}")
      else
        raw("KICK #{channel} #{nick}")
      end
    end

    # Change topic of channel.
    def topic(channel, topic)
      raw("TOPIC #{channel} :#{topic}")
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

# Clever, thanks Sinatra.
at_exit do
  raise $! if $!
  Isaac.app.start
end
