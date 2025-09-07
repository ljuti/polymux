module Polymux
  # WebSocket client for real-time and delayed market data streaming.
  #
  # Provides access to Polygon.io's WebSocket API for receiving real-time
  # market data feeds including trades, quotes, and market status updates.
  # Supports both real-time and delayed data modes with separate endpoints.
  #
  # The WebSocket client uses EventMachine and Faye::WebSocket for handling
  # asynchronous connections and message processing. It automatically handles
  # authentication and connection management.
  #
  # @example Basic real-time options data
  #   client = Polymux::Client.new
  #   ws = client.websocket
  #   ws.options.start  # Connect to real-time options feed
  #
  # @example Delayed data mode
  #   ws = Polymux::Websocket.new(config, mode: :delayed)
  #   ws.stocks.start  # Connect to delayed stocks feed
  #
  # @note Requires EventMachine and Faye::WebSocket gems for WebSocket functionality
  # @see https://polygon.io/docs/websockets WebSocket API documentation
  class Websocket
    # Real-time WebSocket endpoint URL
    REALTIME_URL = "wss://socket.polygon.io"

    # Delayed data WebSocket endpoint URL (15-minute delay)
    DELAYED_URL = "wss://delayed.polygon.io"

    # Initialize a new WebSocket client.
    #
    # @param config [Polymux::Config] Configuration object containing API credentials
    # @param mode [Symbol] Data mode, either :realtime or :delayed
    #   - :realtime provides live market data (requires paid subscription)
    #   - :delayed provides 15-minute delayed data (available with free tier)
    def initialize(config, mode: :realtime)
      @_config = config
      @_connection = nil
      @_mode = mode
    end

    attr_reader :_mode

    # Check if WebSocket is configured for real-time data.
    #
    # @return [Boolean] true if mode is :realtime
    def realtime?
      @_mode == :realtime
    end

    # Check if WebSocket is configured for delayed data.
    #
    # @return [Boolean] true if mode is :delayed
    def delayed?
      @_mode == :delayed
    end

    # Get the base WebSocket URL based on current mode.
    #
    # @return [String] WebSocket URL (real-time or delayed)
    # @api private
    def base_url
      (_mode == :realtime) ? REALTIME_URL : DELAYED_URL
    end

    # Configure WebSocket for options data streaming.
    #
    # Sets the connection URL to the options-specific WebSocket endpoint
    # for receiving options trades, quotes, and aggregate data.
    #
    # @return [self] Returns self for method chaining
    # @example
    #   ws.options.start  # Connect to options feed
    def options
      @_url = "#{base_url}/options"
      self
    end

    # Configure WebSocket for stocks data streaming.
    #
    # Sets the connection URL to the stocks-specific WebSocket endpoint
    # for receiving stock trades, quotes, and aggregate data.
    #
    # @return [self] Returns self for method chaining
    # @example
    #   ws.stocks.start  # Connect to stocks feed
    def stocks
      @_url = "#{base_url}/stocks"
      self
    end

    # Start the WebSocket connection and begin receiving data.
    #
    # This method starts an EventMachine event loop and establishes the
    # WebSocket connection. It handles authentication automatically using
    # the configured API key and sets up event handlers for connection
    # lifecycle management.
    #
    # @note This method blocks execution while the WebSocket connection is active
    # @example
    #   ws = client.websocket
    #   ws.options.start  # Blocks and streams data
    #
    # @todo Add message handling callback support
    # @todo Add connection error handling
    def start
      EM.run do
        @_connection = Faye::WebSocket::Client.new(@_url)

        @_connection.on :open do |event|
          puts "WebSocket connection opened to #{@_url}"
          @_connection.send(
            {
              action: "auth",
              params: @_config.api_key
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

    private

    # Handle incoming WebSocket messages.
    #
    # This method processes raw WebSocket messages received from the
    # Polygon.io streaming API. Currently a placeholder that needs
    # implementation for specific message type handling.
    #
    # @param data [String] Raw message data from WebSocket
    # @api private
    def handle_message(data)
      # TODO: Implement message parsing and handling
      # Different message types: trades, quotes, aggregates, status
    end
  end
end
