$LOAD_PATH.unshift '../lib'

require 'isaac'

configure do |c|
  c.nick    = "echo_bot"
  c.server  = "irc.freenode.net"
  c.port    = 6667
  c.verbose = true
end

on :connect do
  join "#awesome_channel"
end

on :channel, // do
  msg channel, message
end
