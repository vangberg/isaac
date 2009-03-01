require 'rubygems'
require 'test/unit'
require 'context'
require 'rr'
require 'lib/isaac'
begin
  require 'ruby-debug'
rescue LoadError; end

module Test::Unit::Assertions
  def assert_empty_buffer(io)
    assert_raise(Errno::EAGAIN) { io.read_nonblock 1 }
  end
end

class Isaac::Bot
  include Test::Unit::Assertions
end

class Test::Unit::TestCase
  def mock_bot(&b)
    bot = Isaac::Bot.new(&b)
    bot.config.environment = :test
    fake_ircd
    bot.start
    bot
  end

  def fake_ircd
    Thread.start do
      sock = TCPServer.new(6667)
      @server = sock.accept
      sock.close
    end
  end

  def bot_is_connected
    assert_equal "NICK isaac\n", @server.gets
    assert_equal "USER isaac 0 * :Isaac\n", @server.gets
    1.upto(4) {|i| @server.puts ":localhost 00#{i}"}
  end
end
