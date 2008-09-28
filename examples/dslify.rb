require 'lib/isaac.rb'

class K
  def initialize
    Isaac.app.dslify do
      msg "harryjr", "foobarnar"
    end
  end
end

config do |c|
  c.server  = "irc.freenode.net"
  c.nick    = "DSLBOT"
  c.port    = 6667
end

on :connect do
  k = K.new
end
