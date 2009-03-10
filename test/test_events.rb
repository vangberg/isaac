require File.join(File.dirname(__FILE__), 'helper')

class TestEvents < Test::Unit::TestCase
  test "events are registered" do
    bot = mock_bot {
      on(:channel, /Hello/) {msg "foo", "yr formal!"}
      on(:channel, /Hey/) {msg "foo", "bar baz"}
    }
    bot_is_connected

    bot.dispatch(:channel, :message => "Hey")
    assert_equal "PRIVMSG foo :bar baz\n", @server.gets
  end

  test "catch-all events" do
    bot = mock_bot {
      on(:channel) {msg "foo", "bar baz"}
    }
    bot_is_connected

    bot.dispatch(:channel, :message => "lolcat")
    assert_equal "PRIVMSG foo :bar baz\n", @server.gets
  end

  test "event can be halted" do
    bot = mock_bot {
      on(:channel, /Hey/) { halt; msg "foo", "bar baz" }
    }
    bot_is_connected

    bot.dispatch(:channel, :message => "Hey")
    assert @server.empty?
  end

  test "connect-event is dispatched at connection" do
    bot = mock_bot {
      on(:connect) {msg "foo", "bar baz"}
    }
    bot_is_connected

    assert_equal "PRIVMSG foo :bar baz\n", @server.gets
  end

  test "regular expression match is accessible" do
    bot = mock_bot {
      on(:channel, /foo (bar)/) {msg "foo", match[0]}
    }
    bot_is_connected

    bot.dispatch(:channel, :message => "foo bar")

    assert_equal "PRIVMSG foo :bar\n", @server.gets
  end

  #test "regular expression matches is handed to block arguments" do
    #bot = mock_bot {
      #on :channel, /(foo) (bar)/ do |foo,bar|
        #assert_equal "foo", foo
        #assert_equal "bar", bar
      #end
    #}
    #bot_is_connected

    #bot.dispatch(:channel, :message => "foo bar")
  #end
end
