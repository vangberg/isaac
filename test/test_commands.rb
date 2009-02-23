require File.join(File.dirname(__FILE__), 'helper')

class TestCommands < Test::Unit::TestCase
  test "raw messages can be send" do
    bot = mock_bot {}
    bot_is_connected

    bot.raw "PRIVMSG foo :bar baz"
    assert_equal "PRIVMSG foo :bar baz\n", @server.gets
  end

  test "messages are sent to recipient" do
    bot = mock_bot {}
    bot_is_connected

    bot.msg "foo", "bar baz"
    assert_equal "PRIVMSG foo :bar baz\n", @server.gets
  end

  test "channels are joined" do
    bot = mock_bot {}
    bot_is_connected

    bot.join "#foo", "#bar"
    assert_equal "JOIN #foo\n", @server.gets
    assert_equal "JOIN #bar\n", @server.gets
  end
end
