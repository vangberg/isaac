require 'helper'

class TestEvents < Test::Unit::TestCase
  # This is stupid, but it's just there to make it easier to transform to the new
  # Message class. Should be fixed.
  def dispatch(type, env)
    msg = Isaac::Message.new(":john!doe@example.com PRIVMSG #foo :#{env[:message]}")
    @bot.dispatch(type, msg)
  end

  test "events are registered" do
    @bot = mock_bot {
      on(:channel, /Hello/) {msg "foo", "yr formal!"}
      on(:channel, /Hey/) {msg "foo", "bar baz"}
    }
    bot_is_connected

    dispatch(:channel, :message => "Hey")
    assert_equal "PRIVMSG foo :bar baz\r\n", @server.gets
  end

  test "catch-all events" do
    @bot = mock_bot {
      on(:channel) {msg "foo", "bar baz"}
    }
    bot_is_connected

    dispatch(:channel, :message => "lolcat")
    assert_equal "PRIVMSG foo :bar baz\r\n", @server.gets
  end

  test "event can be halted" do
    @bot = mock_bot {
      on(:channel, /Hey/) { halt; msg "foo", "bar baz" }
    }
    bot_is_connected

    dispatch(:channel, :message => "Hey")
    assert @server.empty?
  end

  test "connect-event is dispatched at connection" do
    @bot = mock_bot {
      on(:connect) {msg "foo", "bar baz"}
    }
    bot_is_connected

    assert_equal "PRIVMSG foo :bar baz\r\n", @server.gets
  end

  test "regular expression match is accessible" do
    @bot = mock_bot {
      on(:channel, /foo (bar)/) {msg "foo", match[0]}
    }
    bot_is_connected

    dispatch(:channel, :message => "foo bar")

    assert_equal "PRIVMSG foo :bar\r\n", @server.gets
  end

  test "regular expression matches are handed to block arguments" do
    @bot = mock_bot {
      on :channel, /(foo) (bar)/ do |a,b|
        raw "#{a}"
        raw "#{b}"
      end
    }
    bot_is_connected

    dispatch(:channel, :message => "foo bar")

    assert_equal "foo\r\n", @server.gets
    assert_equal "bar\r\n", @server.gets
  end

  test "only specified number of captures are handed to block args" do
    @bot = mock_bot {
      on :channel, /(foo) (bar)/ do |a|
        raw "#{a}"
      end
    }
    bot_is_connected

    dispatch(:channel, :message => "foo bar")

    assert_equal "foo\r\n", @server.gets
  end
end
