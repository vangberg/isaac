require '../lib/isaac.rb'

config do |c|
  c.nick    = "twittirc2"
  c.server  = "irc.freenode.net"
  c.port    = 6667
end

on :connect do
  join "#Awesome_Channel"
end

on :channel, /.*/ do
  msg channel, "#{nick} said: #{message}"
end
