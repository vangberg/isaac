require '../lib/isaac.rb'
include Isaac

describe Application do
  it 'configures' do
    config do |c|
      c.nick = "awesome"
      c.server = "irc.freenode.net"
      c.port = 6667
    end.should eql(Isaac::Config.new("awesome", "irc.freenode.net", 6667))
  end

  it 'defines helpers' do
    helpers do
      def rain_check(meeting)
        msg "miss_teen", "can i take a rain check on the #{meeting}?"
      end
    end
    context = EventContext.new
    context.rain_check("date")
    context.commands.should eql(["PRIVMSG miss_teen :can i take a rain check on the date?"])
  end
end
