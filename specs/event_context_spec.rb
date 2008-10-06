require '../lib/isaac.rb'
include Isaac

describe EventContext do
  before do
    @context = EventContext.new
  end
  it 'raw' do
    @context.raw("SOME COMMAND")
    @context.commands.should eql(["SOME COMMAND"])
  end
  it 'join' do
    @context.join("#awesome")
    @context.commands.should eql(["JOIN #awesome"])
  end
  it 'part' do
    @context.part("#awesome")
    @context.commands.should eql(["PART #awesome"])
  end
  it 'kick without comment' do
    @context.kick("#awesome", "arnie")
    @context.commands.should eql(["KICK #awesome arnie"])
  end
  it 'kick with comment' do
    @context.kick("#awesome", "arnie", "hello cutiepie")
    @context.commands.should eql(["KICK #awesome arnie :hello cutiepie"])
  end
  it 'topic' do
    @context.topic("#awesome", "this chan is awesome!")
    @context.commands.should eql(["TOPIC #awesome :this chan is awesome!"])
  end
end
