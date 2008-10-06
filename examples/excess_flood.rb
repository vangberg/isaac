require 'lib/isaac.rb'

config do |c|
  c.nick    = "The_Echo_Bot"
  c.server  = "irc.freenode.net"
  c.port    = 6667
end

on :connect do
  join "#awesome_channel"
end

on :channel, /flood/ do
  join "#Awesome_Channel"
  20.times { |i| msg '#awesome_channel', "#{i}:: Let me take you down to the city for a while, just a little while, oh yes. This should really exceed, plz thx u" }
end
