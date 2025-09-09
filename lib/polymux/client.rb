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

    # Access the Stocks API for stock market data.
    #
    # @return [Polymux::Api::Stocks] Stocks API handler
    #
    # @example
    #   tickers = client.stocks.tickers(active: true)
    #   snapshot = client.stocks.snapshot("AAPL")
    #   aggregates = client.stocks.aggregates("AAPL", 1, "day", "2024-01-01", "2024-06-30")
    def stocks
      Api::Stocks.new(self)
    end

    # Access technical indicators for quantitative analysis.
    #
    # Provides access to professional-grade technical indicators that eliminate
    # the need for external calculation libraries. Polygon.io's indicators are
    # significantly faster than fetching raw data and calculating locally.
    #
    # @return [Api::TechnicalIndicators] Technical indicators API handler
    #
    # @example Moving averages for trend analysis
    #   indicators = client.technical_indicators
    #
    #   sma_20 = indicators.sma("AAPL", window: 20, timespan: "day")
    #   ema_12 = indicators.ema("AAPL", window: 12, timespan: "day")
    #
    #   if sma_20.trending_up? && ema_12.current_value > sma_20.current_value
    #     puts "Strong uptrend with momentum"
    #   end
    #
    # @example Momentum oscillators for timing
    #   indicators = client.technical_indicators
    #
    #   rsi = indicators.rsi("AAPL", window: 14, timespan: "day")
    #   macd = indicators.macd("AAPL",
    #     short_window: 12, long_window: 26, signal_window: 9, timespan: "day"
    #   )
    #
    #   if rsi.oversold? && macd.bullish_crossover?
    #     puts "Potential buy signal - oversold with momentum confirmation"
    #   end
    def technical_indicators
      Api::TechnicalIndicators.new(self)
    end

    # Access Flat Files for bulk historical data downloads.
    #
    # Provides efficient access to bulk historical market data through S3-compatible
    # endpoint, enabling download of entire trading days instead of making hundreds
    # of thousands of individual REST API requests. Ideal for backtesting, machine
    # learning, and large-scale quantitative analysis.
    #
    # Flat Files eliminate rate limiting concerns and provide massive performance
    # improvements for bulk data operations. Each file contains a complete day of
    # market activity for the specified asset class and data type.
    #
    # @return [Api::FlatFiles] Flat Files API handler
    #
    # @example Basic file discovery and download
    #   flat_files = client.flat_files
    #
    #   # List available stock trade files for backtesting
    #   files = flat_files.list_files("stocks", "trades", "2024-01-15")
    #   puts "Found #{files.length} files totaling #{files.sum(&:size_mb).round(2)} MB"
    #
    #   # Download specific file for analysis
    #   file_info = files.first
    #   result = flat_files.download_file(file_info.key, "/data/#{file_info.suggested_filename}")
    #   puts "Downloaded #{result[:size]} bytes in #{result[:duration].round(2)} seconds"
    #
    # @example Bulk download for quantitative research
    #   flat_files = client.flat_files
    #
    #   # Download a month of stock trades for backtesting
    #   criteria = {
    #     asset_class: "stocks",
    #     data_type: "trades",
    #     date_range: Date.new(2024, 1, 1)..Date.new(2024, 1, 31)
    #   }
    #
    #   result = flat_files.bulk_download(criteria, "/data/backtesting") do |progress|
    #     puts "Progress: #{progress[:completed]}/#{progress[:total]} files"
    #   end
    #
    #   puts result.summary
    #   if result.success?
    #     puts "Ready for backtesting with #{result.total_size_mb.round(2)} MB"
    #     puts "Average speed: #{result.average_speed_mbps.round(2)} MB/s"
    #   end
    #
    # @example Cross-asset correlation analysis
    #   flat_files = client.flat_files
    #   date = Date.new(2024, 1, 15)
    #
    #   # Download synchronized data across asset classes
    #   stocks_files = flat_files.list_files("stocks", "trades", date)
    #   options_files = flat_files.list_files("options", "trades", date) 
    #   crypto_files = flat_files.list_files("crypto", "trades", date)
    #
    #   # Bulk download all asset classes for correlation analysis
    #   all_files = [stocks_files, options_files, crypto_files].flatten
    #   puts "Downloading #{all_files.length} files for cross-asset analysis"
    #
    # @example File metadata inspection before download
    #   metadata = flat_files.get_file_metadata("stocks/trades/2024/01/15/trades.csv.gz")
    #   puts metadata.detailed_report
    #
    #   if metadata.high_quality? && metadata.record_count > 1_000_000
    #     puts "High-quality dataset with #{metadata.record_count} records - proceeding with download"
    #     flat_files.download_file(metadata.key, "/data/#{metadata.suggested_filename}")
    #   else
    #     puts "Dataset quality insufficient for analysis"
    #   end
    def flat_files
      Api::FlatFiles::Client.new(self)
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

# Require API modules after Client class is fully defined
require_relative "api/technical_indicators"
require_relative "api/flat_files"
