require '../lib/isaac.rb'
include Isaac

describe Event do
  it 'executes block' do
    event = Event.new(nil, lambda { msg 'arnie', 'hello you' })
    event.invoke.should eql(["PRIVMSG arnie :hello you"])
  end
  it 'executes block, passes params' do
    event = Event.new(/^say (.*)/, lambda do
      msg channel, "#{nick} said: #{match[1]}"
      msg nick, message
    end)

    event.invoke(:nick => 'arnie', :channel => '#awesome', :message => 'say this suckah').
    should eql(["PRIVMSG #awesome :arnie said: this suckah", "PRIVMSG arnie :say this suckah"])
  end
end
