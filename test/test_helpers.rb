require 'helper'

class TestHelpers < Test::Unit::TestCase
  test "helpers are registered" do
    bot = mock_bot {
      helpers { def foo; msg "foo", "bar baz"; end }
      on(:private, //) {foo}
    }
    bot_is_connected

    bot.irc.parse ":johnny!john@doe.com PRIVMSG isaac :hello, you!"
    assert_equal "PRIVMSG foo :bar baz\r\n", @server.gets
  end
end
