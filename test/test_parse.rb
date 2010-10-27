require 'helper'

class TestParse < Test::Unit::TestCase
  test "ping-pong" do
    bot = mock_bot {}
    bot_is_connected

    @server.print "PING :foo.bar\r\n"
    assert_equal "PONG :foo.bar\r\n", @server.gets
  end

  test "join messages dispatches join event" do
    bot = mock_bot {
      on(:join) {msg channel, "bar baz"}
    }
    bot_is_connected

    @server.print ":johnny!john@doe.com JOIN #foo\r\n"
    assert_equal "PRIVMSG #foo :bar baz\r\n", @server.gets
  end

  test "part messages dispatches part events" do
    bot = mock_bot {
      on(:part) {msg channel, "#{nick} left: #{message}"}
    }
    bot_is_connected

    @server.print ":johnny!john@doe.com PART #foo :Leaving\r\n"
    assert_equal "PRIVMSG #foo :johnny left: Leaving\r\n", @server.gets
  end

  test "quit messages dispatches quit events" do
    bot = mock_bot {
      on(:quit) {msg "#foo", "#{nick} quit: #{message}"}
    }
    bot_is_connected

    @server.print ":johnny!john@doe.com QUIT :Leaving\r\n"
    assert_equal "PRIVMSG #foo :johnny quit: Leaving\r\n", @server.gets
  end

  test "private messages dispatches private event" do
    bot = mock_bot {
      on(:private, //) {msg "foo", "bar baz"}
    }
    bot_is_connected

    @server.print ":johnny!john@doe.com PRIVMSG isaac :hello, you!\r\n"
    assert_equal "PRIVMSG foo :bar baz\r\n", @server.gets
  end

  test "channel messages dispatches channel event" do
    bot = mock_bot {
      on(:channel, //) {msg "foo", "bar baz"}
    }
    bot_is_connected

    @server.print ":johnny!john@doe.com PRIVMSG #awesome :hello, folks!\r\n"
    assert_equal "PRIVMSG foo :bar baz\r\n", @server.gets
  end

  test "prefix is optional" do
    bot = mock_bot {
      on(:channel, //) {msg "foo", "bar baz"}
    }
    bot_is_connected

    @server.print "PRIVMSG #awesome :hello, folks!\r\n"
    assert_equal "PRIVMSG foo :bar baz\r\n", @server.gets
  end

  test "private event has environment" do
    bot = mock_bot {
      on :private, // do
        raw nick
        raw user
        raw host
        raw message
      end
    }
    bot_is_connected

    @server.puts ":johnny!john@doe.com PRIVMSG isaac :hello, you!"
    assert_equal "johnny\r\n", @server.gets
    assert_equal "john\r\n", @server.gets
    assert_equal "doe.com\r\n", @server.gets
    assert_equal "hello, you!\r\n", @server.gets
  end

  test "channel event has environment" do
    bot = mock_bot {
      on :channel, // do
        raw nick
        raw user
        raw host
        raw message
        raw channel
      end
    }
    bot_is_connected

    @server.puts ":johnny!john@doe.com PRIVMSG #awesome :hello, folks!"
    assert_equal "johnny\r\n", @server.gets
    assert_equal "john\r\n", @server.gets
    assert_equal "doe.com\r\n", @server.gets
    assert_equal "hello, folks!\r\n", @server.gets
    assert_equal "#awesome\r\n", @server.gets
  end

  test "errors are caught and dispatched" do
    bot = mock_bot {
      on(:error, 401) {
        raw error
      }
    }
    bot_is_connected

    @server.print ":server 401 isaac jeff :No such nick/channel\r\n"
    assert_equal "401\r\n", @server.gets
  end
  
  test "prefix is optional for errors" do
    bot = mock_bot {
      on(:error, 401) {
        raw error
      }
    }
    bot_is_connected

    @server.print "401 isaac jeff :No such nick/channel\r\n"
    assert_equal "401\r\n", @server.gets
  end

  test "ctcp version request are answered" do
    bot = mock_bot {
      configure {|c| c.version = "Ridgemont 0.1"}
    }
    bot_is_connected

    @server.print ":jeff!spicoli@name.com PRIVMSG isaac :\001VERSION\001\r\n"
    assert_equal "NOTICE jeff :\001VERSION Ridgemont 0.1\001\r\n", @server.gets
  end

  test "trailing newlines are removed" do
    bot = mock_bot {
      on(:channel, /(.*)/) {msg "foo", "#{match[0]} he said"}
    }
    bot_is_connected

    @server.print ":johnny!john@doe.com PRIVMSG #awesome :hello, folks!\r\n"
    assert_equal "PRIVMSG foo :hello, folks! he said\r\n", @server.gets
  end
end
