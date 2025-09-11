require "active_support/core_ext/hash/keys"
require "polymux/client"
require "polymux/api/transformers"
require "dry/struct"

module Polymux
  module Api
    # API client for options trading data from Polygon.io.
    #
    # Provides comprehensive access to options market data including contract
    # listings, real-time quotes and trades, market snapshots, daily summaries,
    # and historical data. All methods return structured data objects using
    # dry-struct for type safety and consistency.
    #
    # The Options API supports both individual contract lookups using ticker
    # symbols and bulk operations for analyzing entire option chains. All
    # timestamp data is automatically converted from nanosecond precision
    # to Ruby DateTime objects for easy manipulation.
    #
    # @example Basic contract discovery
    #   client = Polymux::Client.new
    #   options = client.options
    #
    #   # Find all AAPL options contracts
    #   contracts = options.contracts("AAPL")
    #   puts "Found #{contracts.length} AAPL contracts"
    #
    # @example Real-time market data
    #   # Get current market snapshot for specific contract
    #   contract = contracts.first
    #   snapshot = options.snapshot(contract)
    #   puts "Current price: #{snapshot.last_trade.price}"
    #
    #   # Get recent trades and quotes
    #   trades = options.trades(contract, limit: 100)
    #   quotes = options.quotes(contract, limit: 50)
    #
    # @example Options chain analysis
    #   # Get complete options chain for underlying
    #   chain = options.chain("AAPL")
    #   calls = chain.select { |opt| opt.last_trade&.price }
    #   puts "Active call contracts: #{calls.length}"
    #
    # @see Polymux::Api::Options::Contract Contract data structure
    # @see Polymux::Api::Options::Snapshot Market snapshot data
    # @see Polymux::Api::Options::Trade Trade data structure
    # @see Polymux::Api::Options::Quote Quote data structure
    class Options < Polymux::Client::PolymuxRestHandler
      # Retrieve options contracts with optional filtering.
      #
      # Searches for options contracts based on the underlying ticker symbol
      # and additional filtering criteria. Without parameters, returns a
      # paginated list of all available options contracts.
      #
      # @param ticker [String, nil] Underlying ticker symbol to filter by (e.g., "AAPL")
      # @param options [Hash] Additional query parameters for filtering
      # @option options [String] :contract_type Filter by "call" or "put"
      # @option options [String] :expiration_date Filter by expiration (YYYY-MM-DD format)
      # @option options [Float] :strike_price Filter by exact strike price
      # @option options [Boolean] :expired Include expired contracts (default: false)
      # @option options [Integer] :limit Number of results per page (max: 1000)
      # @option options [String] :order Sort order: "asc" or "desc" (default: "asc")
      #
      # @return [Array<Contract>] Array of contract objects matching the criteria
      #
      # @example Get all AAPL contracts
      #   contracts = options.contracts("AAPL")
      #
      # @example Filter for specific contract characteristics
      #   calls = options.contracts("AAPL",
      #     contract_type: "call",
      #     expiration_date: "2024-03-15",
      #     limit: 50
      #   )
      def contracts(ticker = nil, options = {})
        options = options.dup
        options[:underlying_ticker] = ticker if ticker.instance_of?(String)

        # Enable graceful degradation for contracts discovery - 404 means "no contracts found"
        fetch_collection("/v3/reference/options/contracts", options, "results", nil, true) do |contract_json|
          Contract.from_api(contract_json)
        end
      end

      # Alias for contracts method with explicit ticker parameter.
      #
      # @param underlying_ticker [String] The underlying ticker symbol
      # @param options [Hash] Additional filtering options
      # @return [Array<Contract>] Array of matching contracts
      # @see #contracts
      def for_ticker(underlying_ticker, options = {})
        contracts(underlying_ticker, options)
      end

      # Get current market snapshot for a specific options contract.
      #
      # Returns comprehensive current market data including last trade, last quote,
      # daily bar data, Greeks, implied volatility, and underlying asset information.
      # This provides a complete picture of the contract's current market state.
      #
      # @param contract [Contract] The options contract to get snapshot for
      # @param options [Hash] Additional query parameters (currently unused)
      #
      # @return [Snapshot] Current market snapshot data
      # @raise [ArgumentError] if contract is not a Contract object
      # @raise [Polymux::Api::Error] if the API request fails
      #
      # @example
      #   contracts = options.contracts("AAPL")
      #   contract = contracts.first
      #   snapshot = options.snapshot(contract)
      #
      #   puts "Last trade price: #{snapshot.last_trade&.price}"
      #   puts "Bid/Ask spread: #{snapshot.last_quote&.bid_price}/#{snapshot.last_quote&.ask_price}"
      #   puts "Implied volatility: #{snapshot.implied_volatility}"
      def snapshot(contract, options = {})
        validate_contract(contract)

        url = "/v3/snapshot/options/#{contract.underlying_ticker}/#{contract.ticker}"
        fetch_single(url, options, "snapshot for #{contract.ticker}") do |response_body|
          Snapshot.from_api(response_body.fetch("results"))
        end
      end

      # Get market snapshots for an entire options chain.
      #
      # Returns current market data for all options contracts associated with
      # the given underlying ticker symbol. This includes calls and puts across
      # all expiration dates and strike prices, providing a complete view of
      # the underlying's options market.
      #
      # @param underlying_ticker [String] The underlying stock ticker (e.g., "AAPL")
      # @param options [Hash] Additional query parameters for filtering
      # @option options [String] :contract_type Filter by "call" or "put"
      # @option options [String] :expiration Filter by specific expiration date
      # @option options [String] :order Sort order for results
      #
      # @return [Array<Snapshot>] Array of snapshots for all contracts in the chain
      # @raise [ArgumentError] if underlying_ticker is not a string
      # @raise [Polymux::Api::Error] if the API request fails
      #
      # @example Analyze entire AAPL options chain
      #   chain = options.chain("AAPL")
      #   active_options = chain.select { |snap| snap.last_trade }
      #   puts "Active contracts: #{active_options.length}"
      #
      #   # Find highest volume contracts
      #   by_volume = chain.sort_by { |snap| -(snap.daily_bar&.volume || 0) }
      #   puts "Most active: #{by_volume.first.underlying_asset.ticker}"
      def chain(underlying_ticker, options = {})
        validate_ticker(underlying_ticker)

        url = "/v3/snapshot/options/#{underlying_ticker}"
        fetch_collection(url, options) do |chain_json|
          Snapshot.from_api(chain_json)
        end
      end

      # Get historical trades for an options contract.
      #
      # Retrieves trade execution data showing actual transactions that occurred
      # for the specified contract. Each trade includes timestamp, price, size,
      # and other execution details. Useful for analyzing trading activity and
      # price discovery patterns.
      #
      # @param contract [String, Contract] Options ticker symbol or Contract object
      # @param options [Hash] Query parameters for filtering and pagination
      # @option options [String] :timestamp Filter trades after this timestamp (nanos)
      # @option options [String] :"timestamp.gte" Trades on or after timestamp
      # @option options [String] :"timestamp.lte" Trades on or before timestamp
      # @option options [Integer] :limit Number of results to return (max: 50,000)
      # @option options [String] :order Sort order: "asc" or "desc" (default: "asc")
      #
      # @return [Array<Trade>] Array of trade execution records
      # @raise [ArgumentError] if contract is not a String or Contract object
      # @raise [Polymux::Api::Error] if the API request fails
      #
      # @example Get recent trades for a contract
      #   trades = options.trades("O:AAPL240315C00150000", limit: 100)
      #   trades.each do |trade|
      #     puts "#{trade.datetime}: #{trade.size} @ $#{trade.price} = $#{trade.total_value}"
      #   end
      #
      # @example Filter trades by time range
      #   yesterday = (Time.now - 86400).to_i * 1_000_000_000
      #   trades = options.trades(contract, "timestamp.gte" => yesterday.to_s)
      def trades(contract, options = {})
        ticker = resolve_ticker(contract)

        url = "/v3/trades/#{ticker}"
        fetch_collection(url, options) do |trade_json|
          Trade.from_api(ticker, trade_json)
        end
      end

      # Get historical quotes for an options contract.
      #
      # Retrieves bid/ask quote data showing the best available prices offered
      # by market makers and other participants. Each quote includes bid price,
      # ask price, sizes, and timestamps. Essential for understanding market
      # liquidity and spread patterns.
      #
      # @param contract [String, Contract] Options ticker symbol or Contract object
      # @param options [Hash] Query parameters for filtering and pagination
      # @option options [String] :timestamp Filter quotes after this timestamp (nanos)
      # @option options [String] :"timestamp.gte" Quotes on or after timestamp
      # @option options [String] :"timestamp.lte" Quotes on or before timestamp
      # @option options [Integer] :limit Number of results to return (max: 50,000)
      # @option options [String] :order Sort order: "asc" or "desc" (default: "asc")
      #
      # @return [Array<Quote>] Array of bid/ask quote records
      # @raise [ArgumentError] if contract is not a String or Contract object
      # @raise [Polymux::Api::Error] if the API request fails
      #
      # @example Analyze bid/ask spreads
      #   quotes = options.quotes("O:AAPL240315C00150000", limit: 1000)
      #   spreads = quotes.map { |q| q.ask_price - q.bid_price }
      #   avg_spread = spreads.sum / spreads.length
      #   puts "Average spread: $#{avg_spread.round(4)}"
      #
      # @example Monitor quote changes over time
      #   quotes.each_cons(2) do |prev, curr|
      #     if curr.bid_price > prev.bid_price
      #       puts "Bid improved: #{prev.bid_price} -> #{curr.bid_price}"
      #     end
      #   end
      def quotes(contract, options = {})
        ticker = resolve_ticker(contract)

        url = "/v3/quotes/#{ticker}"
        fetch_collection(url, options) do |quote_json|
          Quote.from_api(ticker, quote_json)
        end
      end

      # Get daily open/close summary for an options contract.
      #
      # Retrieves the official daily summary data including opening price,
      # closing price, high, low, and volume for a specific trading date.
      # This provides the canonical daily bar data used for historical
      # analysis and charting.
      #
      # @param contract [String, Contract] Options ticker symbol or Contract object
      # @param date [String] Trading date in YYYY-MM-DD format
      #
      # @return [DailySummary] Daily OHLC and volume data
      # @raise [ArgumentError] if contract type is invalid or date format is wrong
      # @raise [Polymux::Api::Error] if the API request fails or no data exists
      #
      # @example Get yesterday's summary
      #   yesterday = (Date.today - 1).strftime("%Y-%m-%d")
      #   summary = options.daily_summary("O:AAPL240315C00150000", yesterday)
      #
      #   puts "Open: $#{summary.open}"
      #   puts "Close: $#{summary.close}"
      #   puts "Volume: #{summary.volume}"
      #   puts "Daily change: #{summary.change_percent}%"
      #
      # @example Calculate intraday range
      #   range = summary.high - summary.low
      #   puts "Trading range: $#{range.round(4)}"
      def daily_summary(contract, date)
        ticker = resolve_ticker(contract)
        validate_date_format(date)

        url = "/v1/open-close/#{ticker}/#{date}"
        fetch_single(url, {}, "daily summary for #{ticker} on #{date}") do |response_body|
          DailySummary.new(response_body.fetch("results", {}))
        end
      end

      # Get previous trading day aggregate data for an options contract.
      #
      # Retrieves OHLC (Open, High, Low, Close) aggregate data for the most
      # recent completed trading session. Automatically finds the last trading
      # day, accounting for weekends and holidays.
      #
      # @param contract [String, Contract] Options ticker symbol or Contract object
      #
      # @return [PreviousDay] Previous trading day aggregate data
      # @raise [ArgumentError] if contract is not a String or Contract object
      # @raise [Polymux::Api::Error] if the API request fails
      # @raise [Polymux::Api::Options::NoPreviousDataFound] if no previous data exists
      #
      # @example Compare to current price
      #   prev_day = options.previous_day("O:AAPL240315C00150000")
      #   current_snapshot = options.snapshot(contract)
      #
      #   change = current_snapshot.last_trade.price - prev_day.close
      #   change_pct = (change / prev_day.close) * 100
      #
      #   puts "Previous close: $#{prev_day.close}"
      #   puts "Current price: $#{current_snapshot.last_trade.price}"
      #   puts "Change: $#{change.round(4)} (#{change_pct.round(2)}%)"
      #
      # @example Volatility analysis
      #   daily_range = prev_day.high - prev_day.low
      #   range_pct = (daily_range / prev_day.close) * 100
      #   puts "Previous day volatility: #{range_pct.round(2)}%"
      def previous_day(contract)
        ticker = resolve_ticker(contract)

        url = "/v2/aggs/ticker/#{ticker}/prev"
        fetch_single(url, {}, "previous day summary for #{ticker}") do |response_body|
          results = response_body.fetch("results", [])
          raise Polymux::Api::Options::NoPreviousDataFound, "No previous day data found for #{ticker}" if results.empty?

          PreviousDay.from_api(results.first)
        end
      end

      private

      # Template method for fetching collections (arrays) of data.
      # Eliminates duplication in HTTP calls and error handling.
      #
      # @param url [String] The API endpoint URL
      # @param params [Hash] Query parameters
      # @param results_key [String] Key in response body containing the array (default: "results")
      # @param error_context [String] Context for error messages (optional)
      # @param allow_404_graceful_degradation [Boolean] Whether to treat 404 as empty results
      # @yield [item_json] Block to transform each item in the results array
      # @return [Array] Array of transformed objects
      def fetch_collection(url, params = {}, results_key = "results", error_context = nil, allow_404_graceful_degradation = false, &block)
        response = _client.http.get(url, params)

        # Treat 404 as "no results found" only for discovery/search endpoints
        # Discovery endpoints should gracefully degrade rather than explode
        if allow_404_graceful_degradation && response.status == 404
          return []
        end

        raise Polymux::Api::Error, build_error_message(error_context, url) unless response.success?

        return [] unless response.body.instance_of?(Hash)

        response.body.fetch(results_key, []).map(&block)
      end

      # Template method for fetching single objects.
      # Eliminates duplication in HTTP calls and error handling.
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
        raise ArgumentError, "Underlying ticker must be a string" unless ticker.instance_of?(String)
      end

      # Validates that contract is a Contract object using explicit type checking.
      # @param contract [Object] The contract to validate
      # @raise [ArgumentError] if contract is not a Contract object
      def validate_contract(contract)
        raise ArgumentError, "A Contract object must be provided" unless contract.instance_of?(Contract)
      end

      # Validates date format using explicit pattern matching.
      # @param date [Object] The date to validate
      # @raise [ArgumentError] if date format is invalid
      def validate_date_format(date)
        unless date.instance_of?(String) && date.match?(/^\d{4}-\d{2}-\d{2}$/)
          raise ArgumentError, "Date must be a String in YYYY-MM-DD format"
        end
      end

      # Resolves ticker from either a String or Contract object.
      # Eliminates duplicate ticker resolution patterns.
      #
      # @param contract [String, Contract] Ticker string or Contract object
      # @return [String] The ticker symbol
      # @raise [ArgumentError] if contract is neither String nor Contract
      def resolve_ticker(contract)
        unless contract.instance_of?(String) || contract.instance_of?(Contract)
          raise ArgumentError, "Contract must be a ticker or a Contract object"
        end

        contract.instance_of?(Contract) ? contract.ticker : contract
      end

      # Builds consistent error messages.
      # @param context [String, nil] Error context or nil
      # @param url [String] The URL that failed
      # @return [String] Formatted error message
      def build_error_message(context, url)
        return "API request failed for #{url}" unless context
        "Failed to fetch #{context}"
      end
    end
  end
end
