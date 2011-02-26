require 'helper'

class TestQueue < Test::Unit::TestCase
  def flood_bot
    bot = mock_bot {
      on(:connect) {
        # 1472.0 / 16 = 92.0, minus one to accomodate for newline
        16.times { raw "." * 90 }
        raw "this should not flood!"
      }
    }
    bot_is_connected
    # We don't want to account for the initial NIKC/USER messages
    bot.irc.instance_variable_set :@transfered, 0
    bot
  end


  test "ping after sending 1472 consequent bytes" do
    bot = flood_bot; react!

    bot.dispatch(:connect); react!
    16.times { @server.gets }
    assert_equal "PING :#{bot.config.server}\r\n", @server.gets
    assert @server.empty?
  end

  test "reset transfer amount at pong reply" do
    bot = flood_bot; react!

    bot.dispatch :connect; react!
    16.times { @server.gets }
    @server.gets # PING message

    @server.puts ":localhost PONG :localhost"; react!
    assert_equal "this should not flood!\r\n", @server.gets
  end

  test "reset transfer amount at server ping" do
    bot = flood_bot; react!

    bot.dispatch :connect; react!
    16.times { @server.gets }
    @server.gets # PING message triggered by transfer lock
    @server.puts "PING :localhost"; react!

    assert_equal "this should not flood!\r\n", @server.gets
  end
end
