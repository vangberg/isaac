require 'isaac'

config do |c|
  c.nick    = "SomeBot"
  c.server  = "irc.freenode.net"
  c.port    = 6667
end

helpers do
  def check
    msg channel, "this channel, #{channel}, is retarded"
  end
end

on :connect do
  join "#twittirc"
end

on :private, /^t (.*)/ do
  msg nick, "You said: " + match[1]
end

on :channel, /quote/ do
  msg channel, "#{nick}: this is QOTD"
end

on :channel, /status/ do
  check
end
