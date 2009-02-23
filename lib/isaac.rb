require 'socket'

module Isaac
  Config = Struct.new(:server, :port, :password, :nick, :realname, :environment, :verbose)

  def self.bot
    @bot ||= Bot.new
  end

  class Bot
    attr_accessor :config, :irc, :nick, :channel, :message, :userhost, :match,
      :error

    def initialize(&b)
      @events = {}
      @config = Config.new("localhost", 6667, nil, "isaac", "Isaac", :production, false)

      instance_eval(&b) if block_given?
    end

    def start
      @irc = IRC.new(self, @config)
      @irc.connect
    end

    def on(event, match=//, &b)
      match = match.to_s if match.is_a? Integer
      (@events[event] ||= []) << [Regexp.new(match), b]
    end

    def helpers(&b)
      instance_eval &b
    end

    def configure(&b)
      b.call(@config)
    end

    def dispatch(event, env={})
      self.nick, self.userhost, self.channel, self.error =
        env[:nick], env[:userhost], env[:channel], env[:error]
      self.message = env[:message] || ""

      regexp, block = @events[event] && @events[event].detect do |regexp, block|
        message.match(regexp)
      end

      self.match = message.match(regexp)
      match_arr = match.to_a
      match_arr.shift

      catch(:halt) { block.call(*match_arr) }
    end

    def halt
      throw :halt
    end

    def raw(m)
      @irc.message(m)
    end

    def msg(recipient, m)
      raw("PRIVMSG #{recipient} :#{m}")
    end

    def join(*channels)
      channels.each {|channel| raw("JOIN #{channel}")}
    end
  end

  class IRC
    def initialize(bot, config)
      @bot, @config = bot, config
      @transfered = 0
      @queue = []
    end

    def connect
      @socket = TCPSocket.open(@config.server, @config.port)
      message "PASSWORD #{@config.password}" if @config.password
      message "NICK #{@config.nick}"
      message "USER #{@config.nick} 0 * :#{@config.realname}"

      # This should probably be somewhere else..
      if @config.environment == :test
        Thread.start {
          while line = @socket.gets
            parse line
          end
        }
      else
        while line = @socket.gets
          parse line
        end
      end
    end

    def parse(input)
      puts "<< #{input}" if @bot.config.verbose
      case input
      when /^PING (\S+)/
        @transfered = 0
        message "PONG #{$1}"
        continue_queue
      when /^:(\S+)!(\S+) PRIVMSG (\S+) :?(.*)/
        env = { :nick => $1, :userhost => $2, :channel => $3, :message => $4 }
        type = env[:channel].match(/^#/) ? :channel : :private
        @bot.dispatch(type, env)
      when /^:\S+ ([4-5]\d\d) \S+ (\S+)/
        env = {:error => $1.to_i, :message => $1, :nick => $2, :channel => $2}
        @bot.dispatch(:error, env)
      when /^:\S+ PONG/
        @transfered = 0
        continue_queue
      end
    end

    def message(msg)
      @queue << msg
      continue_queue
    end

    def continue_queue
      # <= 1472 allows for \n
      while msg = @queue.shift
        if (@transfered + msg.size) < 1472
          @socket.puts msg
          puts ">> #{msg}" if @bot.config.verbose
          @transfered += msg.size + 1
        else
          @queue.unshift(msg)
          @socket.puts "PING :#{@bot.config.server}"
          break
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
