require 'lib/isaac.rb'

class K
  def smoke(brand)
    Isaac.execute { msg "harryjr", "you should smoke #{brand} cigarettes" }
  end
end

config do |c|
  c.server  = "irc.freenode.net"
  c.nick    = "DSLBOT"
  c.port    = 6667
end

on :connect do
  k = K.new
  k.smoke("Lucky Strike")
end
