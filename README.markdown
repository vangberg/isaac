Isaac - The smallish DSL for writing IRC bots.
=======================================================================

Examples & Usage
-----------------------------------------------------------------------

The following bot repeats everything that is being said in the channel
#Awesome_Channel, demonstrating the very basics of creating a bot.
Notice that the on-handlers have access to the local variables 'nick',
'channel' and 'message'.

    config do |c|
      c.nick    = "The_Echo_Bot"
      c.server  = "irc.freenode.net"
      c.port    = 6667
    end

    on :connect do
      join "#Awesome_Channel"
    end

    on :channel, /.*/ do
      msg channel, "#{nick} said: #{message}"
    end

