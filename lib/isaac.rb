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

  Config = Struct.new(:nick, :server, :port, :username, :realname)

  # These are top level methods you use to construct your bot.
  class Application
    def initialize #:nodoc:
      @events = Hash.new {|k,v| k[v] = []}
    end

    # This is plain stupid. Might be useful for logging or something later on.
    def start #:nodoc:
      puts " ==== Starting Isaac ==== "
      connect
      puts " ====  Ending Isaac  ==== "
    end

    # Configure the bot:
    #   config do |c|
    #     c.server    = "irc.freenode.net"
    #     c.nick      = "AwesomeBot"
    #     c.port      = 6667
    #     c.realname  = "James Dean"
    #     c.username  = "jdean"
    #   end
    def config(&block)
      @config = Config.new('isaac_bot', 'irc.freenode.net', 6667, 'isaac', 'isaac')
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
    #     on :private, /^echo (.*)/ do
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
    def event(type, matcher)
      @events[type].detect {|e| matcher =~ e.match}
    end

    def connect
      puts "Connecting to #{@config.server} at port #{@config.port}"
      @irc = TCPSocket.open(@config.server, @config.port)
      puts "Connection established."
      @queue = Queue.new(@irc)
      @queue << "NICK #{@config.nick}"
      @queue << "USER #{@config.username} foobar foobar :#{@config.realname}"
      @queue << @events[:connect].first.invoke if @events[:connect].first
      while line = @irc.gets
        handle line
      end
    end

    # This is one hell of a nasty method. Something should be done, I suppose.
    def handle(line)
      p line if ARGV[0] == "-v" # TODO this is ugly as well. do something about the args.

      case line
      when /^:(\S+)!\S+ PRIVMSG (\S+) :?(.*)/
        nick        = $1
        channel     = $2
        message     = $3
        type = channel.match(/^#/) ? :channel : :private
        if event = event(type, message)
          @queue << event.invoke(:nick => nick, :channel => channel, :message => message)
        end
      when /^:\S+ ([4-5]\d\d) \S+ (\S+)/
        error = $1
        nick = channel = $2
        if event = event(:error, error)
          @queue << event.invoke(:nick => nick, :channel => channel)
        end
      when /^PING (\S+)/
        #TODO not sure this is correct. Damned RFC.
        @queue << "PONG #{$1}" 
      when /^:\S+ PONG \S+ :excess/
        @queue.lock = false
      end
    end
  end

  class Queue #:nodoc:
    attr_accessor :lock
    def initialize(socket)
      @socket     = socket
      @queue      = []
      @transfered = 0
      @lock       = false
      transmit
    end

    # I luvz Rubyz
    def << (msg)
      @queue << msg
    end

    # To prevent excess flood no more than 1472 bytes will be sent to the
    # server. When that limit is reached, @lock = true and the server will be
    # PINGed. @lock will be true until a PONG is received (Application#handle).
    def transmit
      Thread.start { loop {
        unless @lock || @queue.empty?
          msg = @queue.shift
          if (@transfered + msg.size) > 1472
            # No honestly, :excess. The RFC is not too clear on this subject TODO
            @socket.puts "PING :excess"
            @lock = true
            @transfered = 0
          else
            @socket.puts msg
            @transfered += msg.size
          end
        end
        sleep 0.1
      }}
    end
  end

  class Event #:nodoc:
    attr_accessor :match, :block
    def initialize(match, block)
      @match    = match
      @block    = block
    end

    # Execute event in the context of EventContext.
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
      context.commands
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
      comment = " :#{comment}" if comment
      raw("KICK #{channel} #{nick}#{comment}")
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
