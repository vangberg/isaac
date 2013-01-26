require 'lib/isaac'

configure do |c|
  c.nick    = "SomeBot"
  c.server  = "irc.freenode.net"
  c.port    = 6667
  c.realname = 'Isaac Hayes'
  c.verbose  = true
  c.version  = 'SchemaBot v0.1.2' 
end

helpers do
  def check
    msg channel, "this channel, #{channel}, is awesome!"
  end
end

on :connect do
  join "#twittirc", "#awesome_channel"
  msg 'asdfhaskfdhaskdfhaskdfasdf', 'foo'
end

on :private, /^t (.*)/ do
  msg nick, "You said: " + match[1]
end

on :channel, /quote/ do
  msg channel, "#{nick} requested a quote: 'Smoking, a subtle form of suicide.' - Vonnegut"
end

on :channel, /status/ do
  check
end

on :error, 401 do
  puts "Ok, #{nick} doesn't exist."
end
