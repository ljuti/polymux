require "faraday"

module Polymux
  # Main client interface for accessing the Polygon.io API.
  #
  # The Client class serves as the primary entry point for all API operations,
  # managing HTTP connections via Faraday and providing access to different
  # API modules for various asset classes and market data types.
  #
  # Each API module (options, exchanges, markets) is lazily instantiated and
  # shares the same HTTP connection and configuration for consistency and
  # efficiency.
  #
  # @example Basic initialization with default config
  #   client = Polymux::Client.new
  #
  # @example Custom configuration
  #   config = Polymux::Config.new(
  #     api_key: "your_polygon_api_key",
  #     base_url: "https://api.polygon.io"
  #   )
  #   client = Polymux::Client.new(config)
  #
  # @example Accessing different API modules
  #   client = Polymux::Client.new
  #
  #   # Options trading data
  #   options_contracts = client.options.contracts("AAPL")
  #
  #   # Market status and holidays
  #   market_status = client.markets.status
  #
  #   # Exchange information
  #   exchanges = client.exchanges.list
  #
  # @see Polymux::Config Configuration management
  # @see Polymux::Api::Options Options trading data
  # @see Polymux::Api::Markets Market status and holidays
  # @see Polymux::Api::Exchanges Exchange information
  class Client
    # Initialize a new Polymux client.
    #
    # @param config [Polymux::Config] Configuration object containing API credentials
    #   and settings. Defaults to a new Config instance that will load settings
    #   from environment variables or config files.
    def initialize(config = Config.new)
      @_config = config
    end

    # Access the WebSocket API for real-time data streaming.
    #
    # @return [Polymux::Websocket] WebSocket client configured with the same
    #   credentials as this REST client
    #
    # @example
    #   client = Polymux::Client.new
    #   ws = client.websocket
    #   ws.options.start  # Connect to options WebSocket feed
    def websocket
      Polymux::Websocket.new(@_config)
    end

    # Access the Exchanges API for exchange information.
    #
    # @return [Polymux::Api::Exchanges] Exchange API handler
    #
    # @example
    #   exchanges = client.exchanges.list
    #   options_exchanges = exchanges.select(&:options?)
    def exchanges
      Api::Exchanges.new(self)
    end

    # Access the Markets API for market status and holiday information.
    #
    # @return [Polymux::Api::Markets] Markets API handler
    #
    # @example
    #   status = client.markets.status
    #   puts "Market is #{status.open? ? 'open' : 'closed'}"
    #
    #   holidays = client.markets.holidays
    def markets
      Api::Markets.new(self)
    end

    # Access the Options API for options trading data.
    #
    # @return [Polymux::Api::Options] Options API handler
    #
    # @example
    #   contracts = client.options.contracts("AAPL")
    #   snapshot = client.options.snapshot(contracts.first)
    #   trades = client.options.trades("O:AAPL240315C00150000")
    def options
      Api::Options.new(self)
    end

    # Get the configured HTTP client for making API requests.
    #
    # The HTTP client is configured with JSON request/response handling,
    # appropriate authentication headers, and the base URL from configuration.
    # This method is primarily used internally by API handler classes.
    #
    # @return [Faraday::Connection] Configured HTTP client
    # @api private
    def http
      @_http ||= Faraday.new(url: @_config.base_url) do |faraday|
        faraday.request :json
        faraday.response :json, content_type: /\bjson$/
        faraday.adapter Faraday.default_adapter
        faraday.headers["Authorization"] = "Bearer #{@_config.api_key}"
      end
    end

    # Base class for all REST API handlers.
    #
    # This class provides common functionality for API handler classes,
    # giving them access to the client's HTTP connection and configuration.
    # All API modules (Options, Markets, Exchanges) inherit from this class.
    #
    # @api private
    class PolymuxRestHandler
      # Initialize a REST API handler.
      #
      # @param client [Polymux::Client] The client instance that created this handler
      def initialize(client)
        @_client = client
      end

      private

      # Access to the parent client instance.
      #
      # @return [Polymux::Client] The client that owns this handler
      attr_reader :_client
    end
  end
end
