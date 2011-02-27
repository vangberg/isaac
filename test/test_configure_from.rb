require 'helper'
require 'tempfile'

class TestConfigureFrom < Test::Unit::TestCase
  include Isaac

  def setup
    @file = Tempfile.open('config') do |f|
      f.write(
<<__EOF__
        config.server = "irc.foo.com"
        config.nick = "foo"
        config.realname = "Bar"
__EOF__
      )
      f
    end
  end
  
  def teardown
    @file.unlink
  end
  
  test "config is loaded from specified file" do
    bot = Bot.new
    
    bot.configure_from(@file.path)
    assert_equal "irc.foo.com", bot.config.server
    assert_equal "foo", bot.config.nick
    assert_equal "Bar", bot.config.realname
  end

  test "default config is not changed" do
    bot = Bot.new
    
    bot.configure_from(@file.path)
    assert_equal 6667, bot.config.port
  end

end