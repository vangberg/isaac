require 'issac/issac.rb'

%w(configure helpers on).each do |method|
  eval(<<-EOF)
    def #{method}(*args, &block)
      Isaac.bot.#{method}(*args, &block)
    end
  EOF
end

at_exit do
  unless defined?(Test::Unit)
    raise $! if $!
    Isaac.bot.start
  end
end
