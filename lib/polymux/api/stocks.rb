require "active_support/core_ext/hash/keys"
require "polymux/client"
require "polymux/api/transformers"
require "dry/struct"

module Polymux
  module Api
    # API client for stock market data from Polygon.io.
    #
    # Provides comprehensive access to stock market data including ticker
    # information, real-time quotes and trades, market snapshots, historical
    # aggregates, and daily summaries. All methods return structured data
    # objects using dry-struct for type safety and consistency.
    #
    # The Stocks API supports both individual stock lookups using ticker
    # symbols and bulk operations for analyzing entire market sectors. All
    # timestamp data is automatically converted from nanosecond precision
    # to Ruby DateTime objects for easy manipulation.
    #
    # @example Basic ticker discovery
    #   client = Polymux::Client.new
    #   stocks = client.stocks
    #
    #   # Find all active stocks
    #   tickers = stocks.tickers(active: true)
    #   puts "Found #{tickers.length} active stocks"
    #
    # @example Real-time market data
    #   # Get current market snapshot for specific ticker
    #   snapshot = stocks.snapshot("AAPL")
    #   puts "Current price: $#{snapshot.last_trade.price}"
    #
    #   # Get recent trades and quotes
    #   trades = stocks.trades("AAPL", limit: 100)
    #   quotes = stocks.quotes("AAPL", limit: 50)
    #
    # @example Historical price analysis
    #   # Get daily OHLC data for backtesting
    #   from_date = "2024-01-01"
    #   to_date = "2024-06-30"
    #   aggregates = stocks.aggregates("AAPL", 1, "day", from_date, to_date)
    #
    #   # Calculate performance metrics
    #   first_price = aggregates.first.open
    #   last_price = aggregates.last.close
    #   return_pct = ((last_price - first_price) / first_price) * 100
    #   puts "6-month return: #{return_pct.round(2)}%"
    #
    # @see Polymux::Api::Stocks::Ticker Ticker data structure
    # @see Polymux::Api::Stocks::Snapshot Market snapshot data
    # @see Polymux::Api::Stocks::Trade Trade data structure
    # @see Polymux::Api::Stocks::Quote Quote data structure
    # @see Polymux::Api::Stocks::Aggregate Aggregate (OHLC) data structure
    class Stocks < Polymux::Client::PolymuxRestHandler
      # Retrieve stock tickers with optional filtering.
      #
      # Searches for stock tickers based on various filtering criteria including
      # market capitalization, sector, exchange, and activity status. Without
      # parameters, returns a paginated list of all available stock tickers.
      #
      # @param options [Hash] Query parameters for filtering and pagination
      # @option options [String] :ticker Filter by ticker symbol (exact match)
      # @option options [String] :ticker_gte Filter tickers >= this value (alphabetical)
      # @option options [String] :ticker_lte Filter tickers <= this value (alphabetical)
      # @option options [String] :type Filter by ticker type ("CS" for common stock, "PFD" for preferred, etc.)
      # @option options [String] :market Filter by market ("stocks", "crypto", "fx")
      # @option options [String] :exchange Filter by exchange (e.g., "NASDAQ", "NYSE")
      # @option options [String] :cusip Filter by CUSIP identifier
      # @option options [String] :cik Filter by CIK identifier
      # @option options [Boolean] :active Filter by active status (default: true)
      # @option options [String] :order Sort order: "asc" or "desc" (default: "asc")
      # @option options [Integer] :limit Number of results per page (max: 1000, default: 100)
      # @option options [String] :sort Sort field: "ticker" (default)
      #
      # @return [Array<Ticker>] Array of ticker objects matching the criteria
      #
      # @example Get all active stocks
      #   tickers = stocks.tickers(active: true, limit: 1000)
      #
      # @example Filter by market cap and sector
      #   large_cap_tech = stocks.tickers(
      #     market: "stocks",
      #     active: true,
      #     limit: 100
      #   )
      #
      # @example Search by ticker prefix
      #   apple_tickers = stocks.tickers(
      #     ticker_gte: "AAPL",
      #     ticker_lte: "AAPLZ"
      #   )
      def tickers(options = {})
        params = {active: true, limit: 100}.merge(options)

        # Enable graceful degradation for ticker discovery - 404 means "no tickers found"
        fetch_collection("/v3/reference/tickers", params, "results", nil, true) do |ticker_json|
          Ticker.from_api(ticker_json)
        end
      end

      # Get detailed information for a specific ticker.
      #
      # Returns comprehensive information about a single stock ticker including
      # company details, market data, financial metrics, and trading information.
      # This provides a complete overview of the security.
      #
      # @param ticker [String] Stock ticker symbol (e.g., "AAPL")
      # @param date [String, nil] Date for historical ticker details (YYYY-MM-DD format)
      #
      # @return [TickerDetails] Detailed ticker information
      # @raise [ArgumentError] if ticker is not a string
      # @raise [Polymux::Api::Error] if the API request fails
      #
      # @example Get current ticker details
      #   details = stocks.ticker_details("AAPL")
      #   puts "Company: #{details.name}"
      #   puts "Market cap: $#{details.market_cap}"
      #   puts "Sector: #{details.sector}"
      #   puts "Industry: #{details.industry}"
      #
      # @example Get historical ticker information
      #   historical = stocks.ticker_details("AAPL", "2024-01-01")
      def ticker_details(ticker, date = nil)
        validate_ticker(ticker)

        url = "/v3/reference/tickers/#{ticker.upcase}"
        params = date ? {date: date} : {}

        fetch_single(url, params, "ticker details for #{ticker}") do |response_body|
          TickerDetails.from_api(response_body.fetch("results"))
        end
      end

      # Get current market snapshot for a specific stock.
      #
      # Returns comprehensive current market data including last trade, last quote,
      # daily bar data, previous close, and market status. This provides a complete
      # picture of the stock's current market state.
      #
      # @param ticker [String] Stock ticker symbol (e.g., "AAPL")
      #
      # @return [Snapshot] Current market snapshot data
      # @raise [ArgumentError] if ticker is not a string
      # @raise [Polymux::Api::Error] if the API request fails
      #
      # @example Get current market data
      #   snapshot = stocks.snapshot("AAPL")
      #
      #   puts "Last trade: #{snapshot.last_trade&.price} @ #{snapshot.last_trade&.timestamp}"
      #   puts "Bid/Ask: #{snapshot.last_quote&.bid_price}/#{snapshot.last_quote&.ask_price}"
      #   puts "Daily change: #{snapshot.daily_bar&.change_percent}%"
      #   puts "Volume: #{snapshot.daily_bar&.volume}"
      def snapshot(ticker)
        validate_ticker(ticker)

        url = "/v2/snapshot/locale/us/markets/stocks/tickers/#{ticker.upcase}"

        fetch_single(url, {}, "snapshot for #{ticker}") do |response_body|
          Snapshot.from_api(response_body.fetch("ticker"))
        end
      end

      # Get market snapshots for all stocks or filtered results.
      #
      # Returns current market data for multiple stocks, allowing for market-wide
      # analysis and screening. Can be filtered by various criteria to focus on
      # specific market segments.
      #
      # @param options [Hash] Query parameters for filtering
      # @option options [String] :tickers Comma-separated list of tickers to include
      # @option options [Boolean] :include_otc Include over-the-counter stocks (default: false)
      #
      # @return [Array<Snapshot>] Array of snapshots for multiple stocks
      # @raise [Polymux::Api::Error] if the API request fails
      #
      # @example Get snapshots for specific stocks
      #   snapshots = stocks.all_snapshots(tickers: "AAPL,MSFT,GOOGL")
      #
      # @example Market-wide analysis
      #   all_snapshots = stocks.all_snapshots
      #   gainers = all_snapshots.select { |s| s.daily_bar&.change_percent&.positive? }
      #   puts "Number of gainers: #{gainers.length}"
      def all_snapshots(options = {})
        fetch_collection("/v2/snapshot/locale/us/markets/stocks/tickers", options, "tickers", "market snapshots") do |ticker_json|
          Snapshot.from_api(ticker_json)
        end
      end

      # Get historical trades for a stock.
      #
      # Retrieves trade execution data showing actual transactions that occurred
      # for the specified stock. Each trade includes timestamp, price, size, and
      # exchange information. Useful for analyzing trading activity and price
      # discovery patterns.
      #
      # @param ticker [String] Stock ticker symbol (e.g., "AAPL")
      # @param options [Hash] Query parameters for filtering and pagination
      # @option options [String] :timestamp Filter trades after this timestamp (nanos)
      # @option options [String] :"timestamp.gte" Trades on or after timestamp
      # @option options [String] :"timestamp.lte" Trades on or before timestamp
      # @option options [Integer] :limit Number of results to return (max: 50,000)
      # @option options [String] :order Sort order: "asc" or "desc" (default: "asc")
      #
      # @return [Array<Trade>] Array of trade execution records
      # @raise [ArgumentError] if ticker is not a string
      # @raise [Polymux::Api::Error] if the API request fails
      #
      # @example Get recent trades
      #   trades = stocks.trades("AAPL", limit: 1000)
      #   trades.each do |trade|
      #     puts "#{trade.timestamp}: #{trade.size} @ $#{trade.price}"
      #   end
      #
      # @example Filter trades by time range
      #   yesterday = (Time.now - 86400).to_i * 1_000_000_000
      #   trades = stocks.trades("AAPL", "timestamp.gte" => yesterday.to_s)
      def trades(ticker, options = {})
        validate_ticker(ticker)

        url = "/v3/trades/#{ticker.upcase}"

        fetch_collection(url, options) do |trade_json|
          Trade.from_api(ticker, trade_json)
        end
      end

      # Get historical quotes for a stock.
      #
      # Retrieves bid/ask quote data showing the best available prices offered
      # by market makers and other participants. Each quote includes bid price,
      # ask price, sizes, and timestamps. Essential for understanding market
      # liquidity and spread patterns.
      #
      # @param ticker [String] Stock ticker symbol (e.g., "AAPL")
      # @param options [Hash] Query parameters for filtering and pagination
      # @option options [String] :timestamp Filter quotes after this timestamp (nanos)
      # @option options [String] :"timestamp.gte" Quotes on or after timestamp
      # @option options [String] :"timestamp.lte" Quotes on or before timestamp
      # @option options [Integer] :limit Number of results to return (max: 50,000)
      # @option options [String] :order Sort order: "asc" or "desc" (default: "asc")
      #
      # @return [Array<Quote>] Array of bid/ask quote records
      # @raise [ArgumentError] if ticker is not a string
      # @raise [Polymux::Api::Error] if the API request fails
      #
      # @example Analyze bid/ask spreads
      #   quotes = stocks.quotes("AAPL", limit: 1000)
      #   spreads = quotes.map { |q| q.ask_price - q.bid_price }
      #   avg_spread = spreads.sum / spreads.length
      #   puts "Average spread: $#{avg_spread.round(4)}"
      def quotes(ticker, options = {})
        validate_ticker(ticker)

        url = "/v3/quotes/#{ticker.upcase}"

        fetch_collection(url, options) do |quote_json|
          Quote.from_api(ticker, quote_json)
        end
      end

      # Get aggregate (OHLC) bars for a stock.
      #
      # Retrieves Open, High, Low, Close data aggregated over specified time
      # intervals. This is the foundation for price charts, technical analysis,
      # and backtesting strategies. Supports multiple timeframes from minutes
      # to years.
      #
      # @param ticker [String] Stock ticker symbol (e.g., "AAPL")
      # @param multiplier [Integer] Size of the time window (e.g., 1, 5, 15)
      # @param timespan [String] Time unit: "minute", "hour", "day", "week", "month", "quarter", "year"
      # @param from_date [String] Start date in YYYY-MM-DD format
      # @param to_date [String] End date in YYYY-MM-DD format
      # @param options [Hash] Additional query parameters
      # @option options [Boolean] :adjusted Whether to include adjusted prices (default: true)
      # @option options [String] :sort Sort order: "asc" or "desc" (default: "asc")
      # @option options [Integer] :limit Number of results to return (max: 50,000)
      #
      # @return [Array<Aggregate>] Array of OHLC aggregate data
      # @raise [ArgumentError] if required parameters are missing or invalid
      # @raise [Polymux::Api::Error] if the API request fails
      #
      # @example Get daily bars for backtesting
      #   aggregates = stocks.aggregates("AAPL", 1, "day", "2024-01-01", "2024-06-30")
      #   aggregates.each do |bar|
      #     puts "#{bar.timestamp}: O=#{bar.open} H=#{bar.high} L=#{bar.low} C=#{bar.close} V=#{bar.volume}"
      #   end
      #
      # @example Get intraday 5-minute bars
      #   today = Date.today.strftime("%Y-%m-%d")
      #   intraday = stocks.aggregates("AAPL", 5, "minute", today, today)
      #
      # @example Calculate volatility from daily data
      #   daily_bars = stocks.aggregates("AAPL", 1, "day", "2024-01-01", "2024-12-31")
      #   daily_returns = daily_bars.each_cons(2).map { |prev, curr| (curr.close - prev.close) / prev.close }
      #   volatility = Math.sqrt(daily_returns.map { |r| r ** 2 }.sum / daily_returns.length)
      def aggregates(ticker, multiplier, timespan, from_date, to_date, options = {})
        validate_ticker(ticker)
        validate_aggregates_parameters(multiplier, timespan, from_date, to_date)

        params = {adjusted: true, sort: "asc"}.merge(options)
        url = "/v2/aggs/ticker/#{ticker.upcase}/range/#{multiplier}/#{timespan}/#{from_date}/#{to_date}"

        fetch_collection(url, params) do |agg_json|
          Aggregate.from_api(ticker, agg_json)
        end
      end

      # Get previous trading day aggregate data for a stock.
      #
      # Retrieves OHLC (Open, High, Low, Close) aggregate data for the most
      # recent completed trading session. Automatically finds the last trading
      # day, accounting for weekends and holidays.
      #
      # @param ticker [String] Stock ticker symbol (e.g., "AAPL")
      # @param options [Hash] Additional query parameters
      # @option options [Boolean] :adjusted Whether to include adjusted prices (default: true)
      #
      # @return [Aggregate] Previous trading day aggregate data
      # @raise [ArgumentError] if ticker is not a string
      # @raise [Polymux::Api::Error] if the API request fails
      #
      # @example Compare to current price
      #   prev_day = stocks.previous_day("AAPL")
      #   current_snapshot = stocks.snapshot("AAPL")
      #
      #   change = current_snapshot.last_trade.price - prev_day.close
      #   change_pct = (change / prev_day.close) * 100
      #
      #   puts "Previous close: $#{prev_day.close}"
      #   puts "Current price: $#{current_snapshot.last_trade.price}"
      #   puts "Change: $#{change.round(2)} (#{change_pct.round(2)}%)"
      def previous_day(ticker, options = {})
        validate_ticker(ticker)

        params = {adjusted: true}.merge(options)
        url = "/v2/aggs/ticker/#{ticker.upcase}/prev"

        fetch_single(url, params, "previous day data for #{ticker}") do |response_body|
          results = response_body.fetch("results", [])
          raise Polymux::Api::Error, "No previous day data found for #{ticker}" if results.empty?

          Aggregate.from_api(ticker, results.first)
        end
      end

      # Get daily open/close summary for a stock.
      #
      # Retrieves the official daily summary data including opening price,
      # closing price, and after-hours data for a specific trading date.
      # This provides the canonical daily summary used for historical analysis.
      #
      # @param ticker [String] Stock ticker symbol (e.g., "AAPL")
      # @param date [String] Trading date in YYYY-MM-DD format
      # @param options [Hash] Additional query parameters
      # @option options [Boolean] :adjusted Whether to include adjusted prices (default: true)
      #
      # @return [DailySummary] Daily open/close summary data
      # @raise [ArgumentError] if ticker or date format is invalid
      # @raise [Polymux::Api::Error] if the API request fails
      #
      # @example Get daily summary
      #   summary = stocks.daily_summary("AAPL", "2024-08-15")
      #   puts "Open: $#{summary.open}"
      #   puts "Close: $#{summary.close}"
      #   puts "After hours close: $#{summary.after_hours_close}"
      def daily_summary(ticker, date, options = {})
        validate_ticker(ticker)
        validate_date_format(date)

        params = {adjusted: true}.merge(options)
        url = "/v1/open-close/#{ticker.upcase}/#{date}"

        fetch_single(url, params, "daily summary for #{ticker} on #{date}") do |response_body|
          DailySummary.from_api(response_body)
        end
      end

      private

      # Template method for fetching collections (arrays) of data.
      #
      # @param url [String] The API endpoint URL
      # @param params [Hash] Query parameters
      # @param results_key [String] Key in response body containing the array (default: "results")
      # @param error_message [String] Context for error messages (optional)
      # @param allow_404_graceful_degradation [Boolean] Whether to treat 404 as empty results
      # @yield [item_json] Block to transform each item in the results array
      # @return [Array] Array of transformed objects
      def fetch_collection(url, params = {}, results_key = "results", error_message = nil, allow_404_graceful_degradation = false, &block)
        response = _client.http.get(url, params)

        # Treat 404 as "no results found" only for discovery/search endpoints
        # Discovery endpoints should gracefully degrade rather than explode
        if allow_404_graceful_degradation && response.status == 404
          return []
        end

        raise Polymux::Api::Error, build_error_message(error_message, url) unless response.success?

        return [] unless response.body.instance_of?(Hash)

        response.body.fetch(results_key, []).map(&block)
      end

      # Template method for fetching single objects.
      #
      # @param url [String] The API endpoint URL
      # @param params [Hash] Query parameters
      # @param error_context [String] Context for error messages
      # @yield [response_body] Block to transform the response body
      # @return [Object] Transformed object
      def fetch_single(url, params = {}, error_context = nil, &block)
        response = _client.http.get(url, params)
        raise Polymux::Api::Error, build_error_message(error_context, url) unless response.success?

        block.call(response.body)
      end

      # Validates that ticker is a string using explicit type checking.
      # @param ticker [Object] The ticker to validate
      # @raise [ArgumentError] if ticker is not a string
      def validate_ticker(ticker)
        raise ArgumentError, "Ticker must be a string" unless ticker.instance_of?(String)
      end

      # Validates parameters for aggregates method.
      # @param multiplier [Object] The multiplier to validate
      # @param timespan [Object] The timespan to validate
      # @param from_date [Object] The from date to validate
      # @param to_date [Object] The to date to validate
      # @raise [ArgumentError] if any parameter is invalid
      def validate_aggregates_parameters(multiplier, timespan, from_date, to_date)
        raise ArgumentError, "Multiplier must be a positive integer" unless multiplier.instance_of?(Integer) && multiplier > 0
        raise ArgumentError, "Timespan must be a valid time unit" unless %w[minute hour day week month quarter year].include?(timespan)
        validate_date_format(from_date, "From date")
        validate_date_format(to_date, "To date")
      end

      # Validates date format using explicit pattern matching.
      # @param date [Object] The date to validate
      # @param field_name [String] Name of the field for error messages (default: "Date")
      # @raise [ArgumentError] if date format is invalid
      def validate_date_format(date, field_name = "Date")
        raise ArgumentError, "#{field_name} must be in YYYY-MM-DD format" unless date.match?(/^\d{4}-\d{2}-\d{2}$/)
      end

      # Builds consistent error messages.
      # @param context [String, nil] Error context or nil
      # @param url [String] The URL that failed
      # @return [String] Formatted error message
      def build_error_message(context, url)
        return "API request failed for #{url}" unless context
        "Failed to fetch #{context}"
      end

      # Load stock data classes from separate files.
      autoload :Ticker, "polymux/api/stocks/ticker"
      autoload :TickerDetails, "polymux/api/stocks/ticker_details"
      autoload :Snapshot, "polymux/api/stocks/snapshot"
      autoload :Trade, "polymux/api/stocks/trade"
      autoload :Quote, "polymux/api/stocks/quote"
      autoload :Aggregate, "polymux/api/stocks/aggregate"
      autoload :DailySummary, "polymux/api/stocks/daily_summary"
    end
  end
end
