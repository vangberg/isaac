require 'socket'
module Isaac
  class Application
    def initialize(options={})
      # Use array to preserve order of routes
      @routes = {}
      @route_keys = []
      @options = options
    end

    def start(&block)
      instance_eval(&block)
      connect
    end

    private
    def on(match, &block)
      @routes[match] = block
      @route_keys << match
    end

    def connect
      e = EventContext.new(":harryjr!n=harryjr@67-207-147-205.slicehost.net PRIVMSG #twittirc :fooquotefoo", @routes, @route_keys)
      p e.commands.inspect
      e = EventContext.new(":harryjr!n=harryjr@67-207-147-205.slicehost.net PRIVMSG #twittirc :t hej med dig", @routes, @route_keys)
      p e.commands.inspect
    end
  end

  class EventContext
    attr_reader :origin, :destination, :message, :commands

    def initialize(input, routes, route_keys)
      @commands = []

      if match = input.match(/^:(\S+)!\S+ PRIVMSG (\S+) :(.*)/)
        @origin       = match[1]
        @destination  = match[2]
        @message      = match[3]

        key = route_keys.select {|x| x =~ message}.first
        instance_eval(&routes[key])
      end
    end

    private
    def raw(command)
      @commands << command
    end
    def msg(recipient, text)
      raw("PRIVMSG #{recipient} :#{text}")
    end
  end
end
