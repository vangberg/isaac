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
  def self.execute(params={}, &block)
    app.execute(params, &block)
  end

  Config = Struct.new(:nick, :server, :port, :username, :realname, :version, :verbose, :password)

  # These are top level methods you use to construct your bot.
  class Application
    def initialize #:nodoc:
      @events = Hash.new {|k,v| k[v] = []}
      @registration = []
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
    #     c.version   = "James Dean Bot v2.34"
    #     c.verbose   = true
    #   end
    def config(&block)
      @config = Config.new('isaac_bot', 'irc.freenode.net', 6667, 'isaac', 'isaac', 'isaac-bot', false)
      block.call(@config)
      @config
    end

    # Methods defined inside the helpers-block will be available to on()-events at execution time.
    def helpers(&block)
      EventContext.class_eval(&block)
    end

    # on()-events responds to certain actions. Depending on +type+ certain local variables are available:
    # +nick+, +channel+, +message+ and in particular +match+, which contains a MatchData object returned 
    # by the given regular expression.
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
      @events[type] << e = Event.new(match, block)
      return e
    end

    def execute(params={}, &block) #:nodoc:
      event = Event.new(:dsl, block)
      @queue << event.invoke(params)
    end

    def event(type, matcher)
      @events[type].detect do |e| 
        type == :error ? matcher == e.match : matcher =~ e.match
      end
    end

    def connect
      begin
        puts "Connecting to #{@config.server} at port #{@config.port}"
        @irc = TCPSocket.open(@config.server, @config.port)
        puts "Connection established."
	
	@irc.puts "PASS #{@config.password}" if @config.password
        @irc.puts "NICK #{@config.nick}"
        @irc.puts "USER #{@config.username} foobar foobar :#{@config.realname}"

        @queue = Queue.new(@irc)
        @queue << @events[:connect].first.invoke if @events[:connect].first

        while line = @irc.gets
          handle line
        end
      rescue Interrupt => e
        puts "Disconnected! An error occurred: #{e.inspect}"
      rescue Timeout::Error => e
        puts "Timeout: #{e}. Reconnecting."
        connect
      end
    end

    def registered?
      arr = [1,2,3,4] - @registration 
      arr.empty?
    end

    # This is one hell of a nasty method. Something should be done, I suppose.
    def handle(line)
      puts "> #{line}" if @config.verbose

      case line
      when /^:(\S+)!\S+ PRIVMSG \S+ :?\001VERSION\001/
        @queue << "NOTICE #{$1} :\001VERSION #{@config.version}\001"
      when /^:(\S+)!(\S+) PRIVMSG (\S+) :?(.*)/
        nick, userhost, channel, message = $1, $2, $3, $4
        type = channel.match(/^#/) ? :channel : :private
        if event = event(type, message)
          @queue << event.invoke(:nick => nick, :userhost => userhost, :channel => channel, :message => message)
        end
      when /^:\S+ 00([1-4])/
        @registration << $1.to_i
        @queue.lock = false if registered?
      when /^:\S+ ([4-5]\d\d) \S+ (\S+)/
        error = $1
        nick = channel = $2
        if event = event(:error, error.to_i)
          @queue << event.invoke(:nick => nick, :channel => channel)
        end
      when /^PING (\S+)/
        #TODO not sure this is correct. Damned RFC.
	if registered?
	  @queue << "PONG #{$1}"
        else
          @irc.puts "PONG #{$1}"
        end
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
      @lock       = true
      transmit
    end

    # I luvz Rubyz
    def << (msg)
      # .flatten! returns nill if no modifications were made, thus we do this. 
      @queue = (@queue << msg).flatten
    end

    # To prevent excess flood no more than 1472 bytes will be sent to the
    # server. When that limit is reached, @lock = true and the server will be
    # PINGed. @lock will be true until a PONG is received (Application#handle).
    def transmit
      Thread.start { loop {
        unless @lock || @queue.empty?
          msg = @queue.first
          if (@transfered + msg.size) > 1472
            # No honestly, :excess. The RFC is not too clear on this subject TODO
            @socket.puts "PING :excess"
            @lock = true
            @transfered = 0
          else
            @socket.puts msg
            @transfered += msg.size
            @queue.shift
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
      match = params[:message].match(@match) if @match && params[:message]
      params.merge!(:match => match)

      context = EventContext.new(params)
      context.instance_eval(&@block)
      context.commands
    end
  end

  class EventContext
    attr_accessor :nick, :userhost, :channel, :message, :match, :commands
    def initialize(args = {})
      args.each {|k,v| instance_variable_set("@#{k}",v)}
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

    # Send a notice to nick/channel
    def notice(recipient, text)
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
    
    # Invite nicks to channel
    #    invite "#awesome_channel", "arnie"
    #    invite "#awesome_channel", "arnie", "brigitte"
    def invite(channel, *nicks)
      nicks.each {|nick| raw("INVITE #{nick} #{channel}")}
    end
    
    # Change nickname
    def nick(nickname)
      raw("NICK #{nickname}")
    end
  end
end

# Assign methods to current Isaac instance
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
