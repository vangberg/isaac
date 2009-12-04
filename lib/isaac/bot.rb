require 'socket'

module Isaac
  VERSION = '0.2.1'

  Config = Struct.new(:server, :port, :password, :nick, :realname, :version, :environment, :verbose)

  class Bot
    attr_accessor :config, :irc, :nick, :channel, :message, :user, :host, :match,
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

    def action(recipient, text)
      raw("PRIVMSG #{recipient} :\001ACTION #{text}\001")
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

    def mode(channel, option)
      raw("MODE #{channel} #{option}")
    end

    def kick(channel, user, reason=nil)
      raw("KICK #{channel} #{user} :#{reason}")
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
      self.nick, self.user, self.host, self.channel, self.error =
        env[:nick], env[:user], env[:host], env[:channel], env[:error]
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
      msg = Message.new(input)

      if ("001".."004").include? msg.command
        @registration << msg.command
        if registered?
          @queue.unlock
          @bot.dispatch(:connect)
        end
      elsif msg.command == "PRIVMSG"
        dispatch_privmsg(msg)
      elsif msg.numeric_reply? && msg.command =~ /^[45]/
        dispatch_error(msg)
      elsif msg.command == "PING"
        @queue.unlock
        message "PONG :#{msg.params.first}"
      elsif msg.command == "PONG"
        @queue.unlock
      end
    end

    def registered?
      (("001".."004").to_a - @registration).empty?
    end

    def dispatch_privmsg(msg)
      if msg.params.last == "\001VERSION\001"
        message "NOTICE #{msg.nick} :\001VERSION #{@bot.config.version}\001"
      end

      env = {
        :nick => msg.nick, 
        :user => msg.user,
        :host => msg.host,
        :channel => msg.params.first,
        :message => msg.params.last
      }
      type = env[:channel].match(/^#/) ? :channel : :private
      @bot.dispatch(type, env)
    end

    def dispatch_error(msg)
      env = {
        :error => msg.command.to_i,
        :message => msg.command,
        :nick => msg.params.first,
        :channel => msg.params.first
      }
      @bot.dispatch(:error, env)
    end

    def message(msg)
      @queue << msg
    end
  end

  class Message
    attr_accessor :raw,
      :prefix, :server, :nick, :user, :host,
      :command, :error,
      :params

    def initialize(msg=nil)
      @raw = msg
      parse if msg
    end

    def numeric_reply?
      @numeric_reply ||= !!@command.match(/^\d\d\d$/)
    end

    def parse
      match = @raw.match(/(^:(\S+) )?(\S+)(.*)?/)
      _, @prefix, @command, raw_params = match.captures

      raw_params.strip!
      if match = raw_params.match(/:(.*)/)
        @params = match.pre_match.split(" ")
        @params << match[1]
      else
        @params = raw_params.split(" ")
      end
    end

    def nick
      return unless @prefix
      @nick ||= @prefix[/^(\S+)!/, 1]
    end

    def user
      return unless @prefix
      @user ||= @prefix[/^\S+!(\S+)@/, 1]
    end

    def host
      return unless @prefix
      @host ||= @prefix[/@(\S+)$/, 1]
    end

    def server
      return unless @prefix
      return if @prefix.match(/[@!]/)
      @server ||= @prefix[/^(\S+)/, 1]
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

