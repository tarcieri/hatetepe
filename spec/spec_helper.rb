begin
  require "awesome_print"
rescue LoadError
end

require "em-synchrony"

RSpec.configure do |c|
  c.around do |example|
    EM.synchrony do
      EM.heartbeat_interval = 0.01
      example.call
      EM.next_tick { EM.stop }
    end
  end
end
