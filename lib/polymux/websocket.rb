module Polymux
  class Websocket
    REALTIME_URL = "wss://socket.polygon.io"
    DELAYED_URL = "wss://delayed.polygon.io"

    def initialize(config, mode: :realtime)
      @_config = config
      @_connection = nil
      @_mode = mode
    end

    attr_reader :_mode

    def realtime?
      @_mode == :realtime
    end

    def delayed?
      @_mode == :delayed
    end

    def base_url
      _mode == :realtime ? REALTIME_URL : DELAYED_URL
    end

    def options
      @_url = "#{base_url}/options"
      self
    end

    def stocks
      @_url = "#{base_url}/stocks"
      self
    end

    def start
      EM.run do
        @_connection = Faye::WebSocket::Client.new(@_url)

        @_connection.on :open do |event|
          puts "WebSocket connection opened to #{@_url}"
          @_connection.send(
            {
              "action": "auth",
              "params": @_config.api_key
            }
          )
        end

        @_connection.on :message do |event|
          handle_message(event.data)
        end

        @_connection.on :close do |event|
          @_connection = nil
        end
      end
    end
  end
end