require File.join(File.dirname(__FILE__), 'helper')

class TestIrc < Test::Unit::TestCase
  test "a new bot connects to IRC" do
    bot = mock_bot {}
    assert_equal "NICK isaac\n", @server.gets
    assert_equal "USER isaac 0 * :#{bot.config.realname}\n", @server.gets
  end

  test "password is sent if specified" do
    bot = mock_bot {
      configure {|c| c.password = "foo"}
    }
    assert_equal "PASSWORD foo\n", @server.gets
  end
end
