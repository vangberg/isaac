require 'rubygems'
require 'ruby-debug'
require 'test/unit'
require 'context'
require 'rr'
require 'lib/isaac'

class Isaac::Bot
  include Test::Unit::Assertions
end

class Test::Unit::TestCase
  include RR::Adapters::TestUnit

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
  end

  def assert_empty_buffer(io)
    assert_raise(Errno::EAGAIN) { io.read_nonblock 1 }
  end
end
