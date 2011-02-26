require 'helper'

class TestCommands < Test::Unit::TestCase
  test "raw messages can be send" do
    bot = mock_bot {}
    bot_is_connected

    bot.raw "PRIVMSG foo :bar baz"; react!
    assert_equal "PRIVMSG foo :bar baz\r\n", @server.gets
  end

  test "messages are sent to recipient" do
    bot = mock_bot {}
    bot_is_connected

    bot.msg "foo", "bar baz"; react!
    assert_equal "PRIVMSG foo :bar baz\r\n", @server.gets
  end

  test "actions are sent to recipient" do
    bot = mock_bot {}
    bot_is_connected

    bot.action "foo", "bar"; react!
    assert_equal "PRIVMSG foo :\001ACTION bar\001\r\n", @server.gets
  end

  test "channels are joined" do
    bot = mock_bot {}
    bot_is_connected

    bot.join "#foo", "#bar"; react!
    assert_equal "JOIN #foo\r\n", @server.gets
    assert_equal "JOIN #bar\r\n", @server.gets
  end

  test "channels are parted" do
    bot = mock_bot {}
    bot_is_connected

    bot.part "#foo", "#bar"; react!
    assert_equal "PART #foo\r\n", @server.gets
    assert_equal "PART #bar\r\n", @server.gets
  end

  test "topic is set" do
    bot = mock_bot {}
    bot_is_connected

    bot.topic "#foo", "bar baz"; react!
    assert_equal "TOPIC #foo :bar baz\r\n", @server.gets
  end

  test "modes can be set" do
    bot = mock_bot {}
    bot_is_connected

    bot.mode "#foo", "+o"; react!
    assert_equal "MODE #foo +o\r\n", @server.gets
  end

  test "can kick users" do
    bot = mock_bot {}
    bot_is_connected

    bot.kick "foo", "bar", "bein' a baz"; react!
    assert_equal "KICK foo bar :bein' a baz\r\n", @server.gets
  end

  test "quits" do
    bot = mock_bot {}
    bot_is_connected

    bot.quit; react!
    assert_equal "QUIT\r\n", @server.gets
  end

  test "quits with message" do
    bot = mock_bot {}
    bot_is_connected

    bot.quit "I'm outta here!"; react!
    assert_equal "QUIT :I'm outta here!\r\n", @server.gets
  end
end
