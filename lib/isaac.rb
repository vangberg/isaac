require 'isaac/bot'

$bot = Isaac::Bot.new

%w(configure helpers on).each do |method|
  eval(<<-EOF)
    def #{method}(*args, &block)
      $bot.#{method}(*args, &block)
    end
  EOF
end

at_exit do
  unless defined?(Test::Unit)
    raise $! if $!
    $bot.start
  end
end
