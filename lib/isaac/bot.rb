require 'socket'

module Isaac
  VERSION = '0.2.1'

  Config = Struct.new(:server, :port, :ssl, :password, :nick, :realname, :version, :environment, :verbose, :encoding, :bind)

  class Bot
    attr_accessor :config, :irc, :nick, :channel, :message, :user, :host, :match,
      :error

    def initialize(&b)
      @events = {}
      @config = Config.new("localhost", 6667, false, nil, "isaac", "Isaac", 'isaac', :production, false, "utf-8", nil)

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

    def message
      @message ||= ""
    end

    def dispatch(event, msg=nil)
      if msg
        @nick, @user, @host, @channel, @error, @message = 
          msg.nick, msg.user, msg.host, msg.channel, msg.error, msg.message
      end

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

      # -1  splat arg, send everything
      #  0  no args, send nothing
      #  1  defined number of args, send only those
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
      tcp_socket = TCPSocket.open(@config.server, @config.port, @config.bind ? @config.bind : nil)

      if tcp_socket.respond_to?(:set_encoding)
        tcp_socket.set_encoding(@config.encoding)
      end

      if @config.ssl
        begin
          require 'openssl'
        rescue ::LoadError
          raise(RuntimeError,"unable to require 'openssl'",caller)
        end

        ssl_context = OpenSSL::SSL::SSLContext.new
        ssl_context.verify_mode = OpenSSL::SSL::VERIFY_NONE

        unless @config.environment == :test
          puts "Using SSL with #{@config.server}:#{@config.port}"
        end

        @socket = OpenSSL::SSL::SSLSocket.new(tcp_socket, ssl_context)
        @socket.sync = true
        @socket.connect
      else
        @socket = tcp_socket
      end

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
        if msg.params.last == "\001VERSION\001"
          message "NOTICE #{msg.nick} :\001VERSION #{@bot.config.version}\001"
        end

        type = msg.channel? ? :channel : :private
        @bot.dispatch(type, msg)
      elsif msg.error?
        @bot.dispatch(:error, msg)
      elsif msg.command == "PING"
        @queue.unlock
        message "PONG :#{msg.params.first}"
      elsif msg.command == "PONG"
        @queue.unlock
      else
        event = msg.command.downcase.to_sym
        @bot.dispatch(event, msg)
      end
    end

    def registered?
      (("001".."004").to_a - @registration).empty?
    end

    def message(msg)
      @queue << msg
    end
  end

  class Message
    attr_accessor :raw, :prefix, :command, :params

    def initialize(msg=nil)
      @raw = msg
      parse if msg
    end

    def numeric_reply?
      !!numeric_reply
    end

    def numeric_reply
      @numeric_reply ||= @command.match(/^\d\d\d$/)
    end

    def parse
      match = @raw.match(/(^:(\S+) )?(\S+)(.*)/)
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

    def error?
      !!error
    end

    def error
      return @error if @error
      @error = command.to_i if numeric_reply? && command[/[45]\d\d/]
    end

    def channel?
      !!channel
    end

    def channel
      return @channel if @channel
      if regular_command? and params.first.start_with?("#")
        @channel = params.first
      end
    end

    def message
      return @message if @message
      if error?
        @message = error.to_s
      elsif regular_command?
        @message = params.last
      end
    end

    private
    # This is a late night hack. Fix.
    def regular_command?
      %w(PRIVMSG JOIN PART QUIT).include? command
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
