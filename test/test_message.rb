require 'helper'

class TestMessage < Test::Unit::TestCase
  include Isaac

  test "host prefix" do
    msg = Message.new(":jeff!spicoli@beach.com QUIT")
    assert_equal "jeff!spicoli@beach.com", msg.prefix
    assert_equal "jeff", msg.nick
    assert_equal "spicoli", msg.user
    assert_equal "beach.com", msg.host
    assert_nil msg.server
  end

  test "server prefix" do
    msg = Message.new(":some.server.com PING")
    assert_equal "some.server.com", msg.prefix
    assert_equal "some.server.com", msg.server
    assert_nil msg.nick
    assert_nil msg.user
    assert_nil msg.host
  end

  test "without prefix" do
    msg = Message.new("PING foo.bar")
    assert_nil msg.prefix
    assert_nil msg.nick
    assert_nil msg.host
  end

  test "command" do
    msg = Message.new("PING foo.bar")
    assert_equal "PING", msg.command
  end

  test "numeric reply" do
    msg = Message.new("409")
    assert msg.numeric_reply?
    assert_equal "409", msg.command
  end

  test "single param" do
    msg = Message.new("PING foo.bar")
    assert_equal 1, msg.params.size
    assert_equal "foo.bar", msg.params[0]
  end

  test "multiple params" do
    msg = Message.new("FOO bar baz")
    assert_equal 2, msg.params.size
    assert_equal ["bar", "baz"], msg.params
  end

  test "single param with whitespace" do
    msg = Message.new("FOO :bar baz")
    assert_equal 1, msg.params.size
    assert_equal "bar baz", msg.params[0]
  end

  test "single param with whitespace and colon" do
    msg = Message.new("FOO :bar :baz")
    assert_equal 1, msg.params.size
    assert_equal "bar :baz", msg.params[0]
  end
  
  test "multiple params with whitespace" do
    msg = Message.new("FOO bar :lol cat")
    assert_equal 2, msg.params.size
    assert_equal "bar", msg.params[0]
    assert_equal "lol cat", msg.params[1]
  end

  test "multiple params with whitespace and colon" do
    msg = Message.new("FOO bar :lol :cat")
    assert_equal 2, msg.params.size
    assert_equal "bar", msg.params[0]
    assert_equal "lol :cat", msg.params[1]
  end

  test "error" do
    msg = Message.new("200")
    assert_equal false, msg.error?
    assert_nil msg.error

    msg = Message.new("400")
    assert_equal true, msg.error?
    assert_equal 400, msg.error
  end

  test "if error, #message has the error code string" do
    msg = Message.new("400")
    assert_equal "400", msg.message
  end

  test "channel has channel name" do
    msg = Message.new(":foo!bar@baz.com PRIVMSG #awesome :lol cat")
    assert_equal true, msg.channel?
    assert_equal "#awesome", msg.channel
  end

  test "channel has nothing when receiver is a nick" do
    msg = Message.new(":foo!bar@baz.com PRIVMSG john :wazzup boy?")
    assert_equal false, msg.channel?
    assert_equal nil, msg.channel
  end

  test "privmsg has #message" do
    msg = Message.new(":foo!bar@baz.com PRIVMSG #awesome :lol cat")
    assert_equal "lol cat", msg.message
  end

  test "non-privmsg doesn't have #message" do
    msg = Message.new("PING :foo bar")
    assert_nil msg.message
  end
end
