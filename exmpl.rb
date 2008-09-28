require 'isaac'

config do |c|
  c.nick    = "SomeBot"
  c.server  = "irc.freenode.net"
  c.port    = 6667
end

on :connect do
  join "#twittirc"
end

on :private, /^t (.*)/ do
  msg nick, "You said: " + match[1]
end

on :channel, /quote/ do
  msg channel, "#{nick}: NO WAY"
end

on :channel, /quote/ do
  msg channel, "#{nick}: this is QOTD"
end
