require '../lib/isaac.rb'
include Isaac

describe Application do
  before do
    @app = Isaac.app
  end

  it 'configures' do
    config do |c|
      c.nick = "awesome"
      c.server = "irc.freenode.net"
      c.port = 6667
      c.username = "awesome"
      c.realname = "Awesome Bot"
    end.should eql(Isaac::Config.new("awesome", "irc.freenode.net", 6667, "awesome", "Awesome Bot"))
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

  it 'creates events' do
    event = on(:channel, /matchy/) { msg channel, 'oh, matching!' }
    @app.event(:channel, 'this should be matchy!!').should eql(event)
  end
end
