require 'socket'

module Isaac
  VERSION = '0.2.1'

  Config = Struct.new(:server, :port, :password, :nick, :realname, :version, :environment, :verbose)

  def self.bot
    @bot ||= Bot.new
  end

  class Bot
    attr_accessor :config, :irc, :nick, :channel, :message, :userhost, :match,
      :error

    def initialize(&b)
      @events = {}
      @config = Config.new("localhost", 6667, nil, "isaac", "Isaac", 'isaac', :production, false)

      instance_eval(&b) if block_given?
    end

    def configure(&b)
      b.call(@config)
    end

    def on(event, match=//, &block)
      match = match.to_s if match.is_a? Integer
      (@events[event] ||= []) << [Regexp.new(match), block]
    end

    def helpers(&b)
      instance_eval(&b)
    end

    def halt
      throw :halt
    end

    def raw(command)
      @irc.message(command)
    end

    def msg(recipient, text)
      raw("PRIVMSG #{recipient} :#{text}")
    end

    def join(*channels)
      channels.each {|channel| raw("JOIN #{channel}")}
    end

    def part(*channels)
      channels.each {|channel| raw("PART #{channel}")}
    end

    def topic(channel, text)
      raw("TOPIC #{channel} :#{text}")
    end

    def quit(message=nil)
      command = message ? "QUIT :#{message}" : "QUIT"
      raw command
    end

    def start
      puts "Connecting to #{@config.server}:#{@config.port}" unless @config.environment == :test
      @irc = IRC.new(self, @config)
      @irc.connect
    end

    def dispatch(event, env={})
      self.nick, self.userhost, self.channel, self.error =
        env[:nick], env[:userhost], env[:channel], env[:error]
      self.message = env[:message] || ""

      if handler = find(event, message)
        regexp, block = *handler
        self.match = message.match(regexp).captures
        invoke block
      end
    end

  private
    def find(type, message)
      if events = @events[type]
        events.detect {|regexp,_| message.match(regexp)}
      end
    end

    def invoke(block)
      mc = class << self; self; end
      mc.send :define_method, :__isaac_event_handler, &block

      bargs = case block.arity <=> 0
        when -1; match
        when 0; []
        when 1; match[0..block.arity-1]
      end

      catch(:halt) { __isaac_event_handler(*bargs) }
    end
  end

  class IRC
    def initialize(bot, config)
      @bot, @config = bot, config
      @transfered = 0
      @registration = []
    end

    def connect
      @socket = TCPSocket.open(@config.server, @config.port)
      @queue = Queue.new(@socket, @bot.config.server)
      message "PASS #{@config.password}" if @config.password
      message "NICK #{@config.nick}"
      message "USER #{@config.nick} 0 * :#{@config.realname}"
      @queue.lock

      while line = @socket.gets
        parse line
      end
    end

    def parse(input)
      puts "<< #{input}" if @bot.config.verbose
      case input.chomp
      when /(^:\S+ )?00([1-4])/
        @registration << $2.to_i
        if registered?
          @queue.unlock
          @bot.dispatch(:connect)
        end
      when /(^:(\S+)!\S+ )?PRIVMSG \S+ :?\001VERSION\001/
        message "NOTICE #{$2} :\001VERSION #{@bot.config.version}\001"
      when /^PING (\S+)/
        @queue.unlock
        message "PONG #{$1}"
      when /(^:(\S+)!(\S+) )?PRIVMSG (\S+) :?(.*)/
        env = { :nick => $2, :userhost => $3, :channel => $4, :message => $5 }
        type = env[:channel].match(/^#/) ? :channel : :private
        @bot.dispatch(type, env)
      when /(^:\S+ )?([4-5]\d\d) \S+ (\S+)/
        env = {:error => $2.to_i, :message => $2, :nick => $3, :channel => $3}
        @bot.dispatch(:error, env)
      when /(^:\S+ )?PONG/
        @queue.unlock
      end
    end

    def registered?
      ([1,2,3,4] - @registration).empty?
    end

    def message(msg)
      @queue << msg
    end
  end

  class Queue
    def initialize(socket, server)
      # We need  server  for pinging us out of an excess flood
      @socket, @server = socket, server
      @queue, @lock, @transfered = [], false, 0
    end

    def lock
      @lock = true
    end

    def unlock
      @lock, @transfered = false, 0
      invoke
    end

    def <<(message)
      @queue << message
      invoke
    end

  private
    def message_to_send?
      !@lock && !@queue.empty?
    end

    def transfered_after_next_send
      @transfered + @queue.first.size + 2 # the 2 is for \r\n
    end

    def exceed_limit?
      transfered_after_next_send > 1472
    end

    def lock_and_ping
      lock
      @socket.print "PING :#{@server}\r\n"
    end

    def next_message
      @queue.shift.to_s.chomp + "\r\n"
    end

    def invoke
      while message_to_send?
        if exceed_limit?
          lock_and_ping; break
        else
          @transfered = transfered_after_next_send
          @socket.print next_message
          # puts ">> #{msg}" if @bot.config.verbose
        end
      end
    end
  end
end

%w(configure helpers on).each do |method|
  eval(<<-EOF)
    def #{method}(*args, &block)
      Isaac.bot.#{method}(*args, &block)
    end
  EOF
end

at_exit do
  unless defined?(Test::Unit)
    raise $! if $!
    Isaac.bot.start
  end
end
