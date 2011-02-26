$LOAD_PATH.unshift 'lib'
require 'isaac/bot'
require 'rubygems'
require 'test/unit'
require 'contest'
require 'rr'
require 'timeout'
begin
  require 'ruby-debug'
rescue LoadError; end

class MockSocket
  def self.pipe
    socket1, socket2 = new, new
    socket1.in, socket2.out = IO.pipe
    socket2.in, socket1.out = IO.pipe
    [socket1, socket2]
  end

  attr_accessor :in, :out
  def gets()
    Timeout.timeout(1) {@in.gets}
  end
  def puts(m) @out.puts(m) end
  def print(m) @out.print(m) end
  def eof?() @in.eof? end
  def empty?
    begin
      @in.read_nonblock(1)
      false
    rescue Errno::EAGAIN
      true
    end
  end
end


class FakeReactor
  
  def poll(io, &blk)
    (@polls ||= {})[io] = lambda {
      blk.call(io.read_nonblock(1))
    }
  end
 
  def react!
    @polls.each do |_, proc|
      loop do
        begin 
          proc.call 
        rescue Errno::EAGAIN
          break
        end
      end
    end    
  end
  
end


class StubIRCClient
  include Isaac::IRCClient
  
  attr_accessor :socket
  
  def send_data data
    @socket.print data
  end
   
end


class Test::Unit::TestCase
  include RR::Adapters::TestUnit

  def mock_bot(bot=nil, &b)
    @socket, @server = MockSocket.pipe
    bot ||= Isaac::Bot.new(&b)
    @r = FakeReactor.new
    stub(Isaac::IRC).connect(anything, anything) do
      conn = StubIRCClient.new(bot, bot.config)
      conn.socket = @socket
      conn.post_init
      @r.poll(@socket.in) { |data| conn.receive_data data }
      conn
    end
    bot.config.environment = :test
    bot.start
    bot
  end

  def bot_is_connected
    assert_equal "NICK isaac\r\n", @server.gets
    assert_equal "USER isaac 0 * :Isaac\r\n", @server.gets
    1.upto(4) {|i| @server.print ":localhost 00#{i}\r\n" }
  end
  
  def react!
    @r.react!
  end
  
end


