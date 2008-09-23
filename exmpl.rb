require 'isaac'

client = Isaac::Application.new :nick => 'SomeBot',
                   :server => 'irc.freenode.net',
                   :port => 6667

client.start do
  on /^t (.*)/ do
    msg origin, "You said: " + message
  end
  on /quote/ do
    msg "foo", "this is QOTD"
  end
end
