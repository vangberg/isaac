require '../lib/isaac.rb'
include Isaac

describe Queue do
  before do
    @queue = Isaac::Queue.new("fake_irc")
  end
  it 'returns array of messages when string is pushed' do
    r = @queue << "PRIVMSG someone something" << "JOIN #awesome"
    r.should eql(["PRIVMSG someone something", "JOIN #awesome"])
  end
  it 'returns flat array of messages when array is pushed' do
    r = @queue << ["JOIN #awesome", "PRIVMSG brigitte :hello love"]
    r.should eql(["JOIN #awesome", "PRIVMSG brigitte :hello love"])
  end
end
