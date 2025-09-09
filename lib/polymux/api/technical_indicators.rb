# frozen_string_literal: true

require "dry/struct"
require_relative "../types"
require_relative "transformers"

module Polymux
  module Api
    # Provides access to Polygon.io technical indicators API endpoints.
    #
    # Technical indicators eliminate the need for external calculation libraries
    # by providing institutional-grade calculations directly from Polygon.io.
    # This is significantly faster than fetching raw aggregate data and
    # calculating indicators locally, as it avoids the 5x data overhead.
    #
    # The Technical Indicators API provides four essential indicators that form
    # the foundation of quantitative analysis and algorithmic trading strategies:
    #
    # - **SMA (Simple Moving Average)**: Trend identification and support/resistance levels
    # - **EMA (Exponential Moving Average)**: Responsive trend analysis and signal generation
    # - **RSI (Relative Strength Index)**: Momentum analysis and overbought/oversold conditions
    # - **MACD (Moving Average Convergence Divergence)**: Trend confirmation and crossover signals
    #
    # Each indicator returns a rich data structure with comprehensive analysis methods
    # that enable sophisticated trading strategies without requiring external libraries
    # or manual calculations.
    #
    # ## Core Capabilities
    #
    # ### Trend Analysis
    # Moving averages (SMA/EMA) provide trend direction, strength, and crossover signals
    # that form the backbone of trend-following strategies.
    #
    # ### Momentum Analysis
    # RSI identifies momentum extremes and divergences that signal potential reversals
    # or continuation patterns in price movements.
    #
    # ### Signal Generation
    # MACD combines trend and momentum analysis to generate high-confidence buy/sell
    # signals through crossovers and histogram analysis.
    #
    # ### Multi-Timeframe Analysis
    # All indicators support multiple timeframes (minute, hour, day, week, month)
    # enabling comprehensive analysis across different time horizons.
    #
    # @example Basic technical analysis workflow
    #   indicators = client.technical_indicators
    #
    #   # Simple Moving Average for trend identification
    #   sma_20 = indicators.sma("AAPL", window: 20, timespan: "day")
    #   sma_50 = indicators.sma("AAPL", window: 50, timespan: "day")
    #
    #   # Exponential Moving Average for responsive signals
    #   ema_12 = indicators.ema("AAPL", window: 12, timespan: "day")
    #
    #   # RSI for momentum analysis
    #   rsi = indicators.rsi("AAPL", window: 14, timespan: "day")
    #
    #   # MACD for trend confirmation
    #   macd = indicators.macd("AAPL",
    #     short_window: 12,
    #     long_window: 26,
    #     signal_window: 9,
    #     timespan: "day"
    #   )
    #
    #   # Analyze trend direction
    #   if sma_20.current_value > sma_50.current_value && rsi.current_value < 70
    #     puts "Bullish trend with momentum room to run"
    #   end
    #
    # @example Multi-timeframe analysis for regime identification
    #   # Daily trend
    #   daily_sma = indicators.sma("SPY", window: 200, timespan: "day")
    #
    #   # Weekly confirmation
    #   weekly_sma = indicators.sma("SPY", window: 50, timespan: "week")
    #
    #   # Regime identification
    #   if daily_sma.trending_up? && weekly_sma.trending_up?
    #     puts "Bull market regime confirmed"
    #   end
    #
    # @example Comprehensive trading signal generation
    #   # Get all indicators for comprehensive analysis
    #   sma_20 = indicators.sma("TSLA", window: 20, timespan: "day")
    #   ema_12 = indicators.ema("TSLA", window: 12, timespan: "day")
    #   rsi = indicators.rsi("TSLA", window: 14, timespan: "day")
    #   macd = indicators.macd("TSLA",
    #     short_window: 12, long_window: 26, signal_window: 9, timespan: "day")
    #
    #   # Generate comprehensive trading signal
    #   trend_bullish = sma_20.trending_up? && ema_12.trending_up?
    #   momentum_favorable = !rsi.overbought? && rsi.current_value > 50
    #   macd_signal = macd.trading_signal
    #
    #   if trend_bullish && momentum_favorable && macd_signal[:type] == :buy
    #     puts "Strong buy signal: Trend + Momentum + MACD alignment"
    #     puts "Signal strength: #{macd_signal[:strength]}"
    #     puts "Confidence: #{macd_signal[:confidence]}"
    #   end
    #
    # @example Backtesting with historical data
    #   # Get historical indicators with date range
    #   from_date = "2024-01-01"
    #   to_date = "2024-06-30"
    #
    #   sma_50 = indicators.sma("SPY",
    #     window: 50,
    #     timespan: "day",
    #     timestamp_gte: from_date,
    #     timestamp_lte: to_date
    #   )
    #
    #   # Analyze historical performance
    #   total_return = sma_50.percent_change(sma_50.values.length - 1)
    #   puts "SMA-50 tracked return over period: #{total_return}%"
    #   puts "Trend consistency: #{sma_50.trending_up? ? 'Bullish' : 'Bearish'}"
    #
    # @see SMA Simple Moving Average with trend analysis
    # @see EMA Exponential Moving Average with momentum detection
    # @see RSI Relative Strength Index with overbought/oversold analysis
    # @see MACD Moving Average Convergence Divergence with crossover signals
    class TechnicalIndicators < Polymux::Client::PolymuxRestHandler
      # Get Simple Moving Average (SMA) for a stock ticker.
      #
      # The SMA smooths price data by calculating the average price over a
      # specified number of periods. It's widely used for trend identification,
      # support/resistance levels, and signal generation.
      #
      # @param ticker [String] Stock ticker symbol (e.g., "AAPL")
      # @param window [Integer] Number of periods for calculation (e.g., 20, 50, 200)
      # @param timespan [String] Time period: "minute", "hour", "day", "week", "month"
      # @param options [Hash] Additional query parameters
      # @option options [String] :series_type Price type to use ("open", "high", "low", "close", "volume")
      # @option options [String] :timestamp_gte Start date (YYYY-MM-DD)
      # @option options [String] :timestamp_lte End date (YYYY-MM-DD)
      # @option options [Boolean] :adjusted Use split-adjusted prices (default: true)
      # @option options [Integer] :limit Maximum results to return (default: 5000)
      # @option options [String] :order Result ordering ("asc" or "desc")
      #
      # @return [SMA] Simple Moving Average data with analysis methods
      # @raise [ArgumentError] if ticker is not a string or window is invalid
      # @raise [Polymux::Api::Error] if the API request fails
      #
      # @example Trend analysis with multiple SMAs
      #   sma_20 = indicators.sma("AAPL", window: 20, timespan: "day")
      #   sma_50 = indicators.sma("AAPL", window: 50, timespan: "day")
      #
      #   if sma_20.current_value > sma_50.current_value
      #     puts "Short-term uptrend confirmed"
      #   end
      #
      #   # Identify crossover signals
      #   if sma_20.crossed_above?(sma_50)
      #     puts "Golden cross - bullish signal"
      #   end
      def sma(ticker, window:, timespan:, **options)
        validate_ticker(ticker)
        validate_window(window)
        validate_timespan(timespan)

        fetch_indicator("sma", SMA, ticker, {window: window, timespan: timespan, **options})
      end

      # Get Exponential Moving Average (EMA) for a stock ticker.
      #
      # The EMA gives more weight to recent prices, making it more responsive
      # to price changes than SMA. Popular for short-term trading signals
      # and trend identification.
      #
      # @param ticker [String] Stock ticker symbol (e.g., "AAPL")
      # @param window [Integer] Number of periods for calculation (e.g., 12, 26)
      # @param timespan [String] Time period: "minute", "hour", "day", "week", "month"
      # @param options [Hash] Additional query parameters
      # @option options [String] :series_type Price type to use (default: "close")
      # @option options [String] :timestamp_gte Start date (YYYY-MM-DD)
      # @option options [String] :timestamp_lte End date (YYYY-MM-DD)
      # @option options [Boolean] :adjusted Use split-adjusted prices (default: true)
      # @option options [Integer] :limit Maximum results to return (default: 5000)
      # @option options [String] :order Result ordering ("asc" or "desc")
      #
      # @return [EMA] Exponential Moving Average data with analysis methods
      # @raise [ArgumentError] if ticker is not a string or window is invalid
      # @raise [Polymux::Api::Error] if the API request fails
      #
      # @example Responsive trend analysis
      #   ema_12 = indicators.ema("AAPL", window: 12, timespan: "day")
      #   ema_26 = indicators.ema("AAPL", window: 26, timespan: "day")
      #
      #   # EMA is more responsive to recent price changes
      #   if ema_12.trending_up? && ema_12.current_value > ema_26.current_value
      #     puts "Strong short-term uptrend"
      #   end
      def ema(ticker, window:, timespan:, **options)
        validate_ticker(ticker)
        validate_window(window)
        validate_timespan(timespan)

        fetch_indicator("ema", EMA, ticker, {window: window, timespan: timespan, **options})
      end

      # Get Relative Strength Index (RSI) for a stock ticker.
      #
      # RSI is a momentum indicator that ranges from 0 to 100, commonly used
      # to identify overbought (>70) and oversold (<30) conditions. Essential
      # for timing entries and exits.
      #
      # @param ticker [String] Stock ticker symbol (e.g., "AAPL")
      # @param window [Integer] Number of periods for calculation (typically 14)
      # @param timespan [String] Time period: "minute", "hour", "day", "week", "month"
      # @param options [Hash] Additional query parameters
      # @option options [String] :series_type Price type to use (default: "close")
      # @option options [String] :timestamp_gte Start date (YYYY-MM-DD)
      # @option options [String] :timestamp_lte End date (YYYY-MM-DD)
      # @option options [Boolean] :adjusted Use split-adjusted prices (default: true)
      # @option options [Integer] :limit Maximum results to return (default: 5000)
      # @option options [String] :order Result ordering ("asc" or "desc")
      #
      # @return [RSI] Relative Strength Index data with overbought/oversold analysis
      # @raise [ArgumentError] if ticker is not a string or window is invalid
      # @raise [Polymux::Api::Error] if the API request fails
      #
      # @example Momentum analysis and signal generation
      #   rsi = indicators.rsi("AAPL", window: 14, timespan: "day")
      #
      #   if rsi.oversold?
      #     puts "Potential buy opportunity - RSI: #{rsi.current_value}"
      #   elsif rsi.overbought?
      #     puts "Potential sell opportunity - RSI: #{rsi.current_value}"
      #   end
      #
      #   # Detect momentum shifts
      #   if rsi.recovering_from_oversold?
      #     puts "Momentum turning positive"
      #   end
      def rsi(ticker, window:, timespan:, **options)
        validate_ticker(ticker)
        validate_window(window)
        validate_timespan(timespan)

        fetch_indicator("rsi", RSI, ticker, {window: window, timespan: timespan, **options})
      end

      # Get MACD (Moving Average Convergence Divergence) for a stock ticker.
      #
      # MACD is a momentum and trend-following indicator that shows the
      # relationship between two moving averages. Consists of MACD line,
      # signal line, and histogram for comprehensive analysis.
      #
      # @param ticker [String] Stock ticker symbol (e.g., "AAPL")
      # @param short_window [Integer] Fast EMA period (typically 12)
      # @param long_window [Integer] Slow EMA period (typically 26)
      # @param signal_window [Integer] Signal line EMA period (typically 9)
      # @param timespan [String] Time period: "minute", "hour", "day", "week", "month"
      # @param options [Hash] Additional query parameters
      # @option options [String] :series_type Price type to use (default: "close")
      # @option options [String] :timestamp_gte Start date (YYYY-MM-DD)
      # @option options [String] :timestamp_lte End date (YYYY-MM-DD)
      # @option options [Boolean] :adjusted Use split-adjusted prices (default: true)
      # @option options [Integer] :limit Maximum results to return (default: 5000)
      # @option options [String] :order Result ordering ("asc" or "desc")
      #
      # @return [MACD] MACD data with crossover and histogram analysis
      # @raise [ArgumentError] if ticker is not a string or windows are invalid
      # @raise [Polymux::Api::Error] if the API request fails
      #
      # @example Trend confirmation and signal generation
      #   macd = indicators.macd("AAPL",
      #     short_window: 12,
      #     long_window: 26,
      #     signal_window: 9,
      #     timespan: "day"
      #   )
      #
      #   if macd.bullish_crossover?
      #     puts "MACD bullish crossover - trend confirmation"
      #   elsif macd.bearish_crossover?
      #     puts "MACD bearish crossover - trend reversal"
      #   end
      #
      #   # Analyze momentum strength
      #   if macd.histogram_increasing?
      #     puts "Momentum strengthening"
      #   end
      def macd(ticker, short_window:, long_window:, signal_window:, timespan:, **options)
        validate_ticker(ticker)
        validate_macd_windows(short_window, long_window, signal_window)
        validate_timespan(timespan)

        fetch_indicator("macd", MACD, ticker, {
          short_window: short_window,
          long_window: long_window,
          signal_window: signal_window,
          timespan: timespan,
          **options
        })
      end

      private

      # Template method for fetching technical indicators.
      # Eliminates duplication in HTTP calls and error handling.
      #
      # @param indicator_name [String] Name of the indicator ("sma", "ema", etc.)
      # @param result_class [Class] The result class to instantiate
      # @param ticker [String] Stock ticker symbol
      # @param params_hash [Hash] Parameters for the API request
      # @return [Object] Instance of the result_class
      def fetch_indicator(indicator_name, result_class, ticker, params_hash)
        params = build_indicator_params(**params_hash)
        url = "/v1/indicators/#{indicator_name}/#{ticker.upcase}"

        response = _client.http.get(url, params)
        raise Polymux::Api::Error, "Failed to fetch #{indicator_name.upcase} for #{ticker}" unless response.success?

        result_class.from_api(ticker, response.body)
      end

      # Validates that ticker is a string
      # @param ticker [Object] The ticker to validate
      # @raise [ArgumentError] if ticker is not a string
      def validate_ticker(ticker)
        raise ArgumentError, "Ticker must be a string" unless ticker.instance_of?(String)
      end

      # Validates that window is a positive integer
      # @param window [Object] The window to validate
      # @raise [ArgumentError] if window is not a positive integer
      def validate_window(window)
        raise ArgumentError, "Window must be a positive integer" unless window.instance_of?(Integer) && window > 0
      end

      # Validates that timespan is one of the allowed values
      # @param timespan [Object] The timespan to validate
      # @raise [ArgumentError] if timespan is not valid
      def validate_timespan(timespan)
        raise ArgumentError, "Timespan must be a valid time unit" unless %w[minute hour day week month].include?(timespan)
      end

      # Validates MACD-specific window parameters
      # @param short_window [Object] The short window to validate
      # @param long_window [Object] The long window to validate
      # @param signal_window [Object] The signal window to validate
      # @raise [ArgumentError] if any window parameter is invalid
      def validate_macd_windows(short_window, long_window, signal_window)
        raise ArgumentError, "Short window must be a positive integer" unless short_window.instance_of?(Integer) && short_window > 0
        raise ArgumentError, "Long window must be a positive integer" unless long_window.instance_of?(Integer) && long_window > 0
        raise ArgumentError, "Signal window must be a positive integer" unless signal_window.instance_of?(Integer) && signal_window > 0
        raise ArgumentError, "Short window must be less than long window" unless short_window < long_window
      end

      # Build standardized parameters for technical indicator requests.
      #
      # @param options [Hash] Request parameters
      # @return [Hash] Formatted parameters for API request
      def build_indicator_params(**options)
        params = {
          adjusted: true,
          series_type: "close",
          limit: 5000
        }

        # Handle timestamp parameters
        params["timestamp.gte"] = options[:timestamp_gte] if options[:timestamp_gte]
        params["timestamp.lte"] = options[:timestamp_lte] if options[:timestamp_lte]

        # Add indicator-specific parameters
        params[:window] = options[:window] if options[:window]
        params[:short_window] = options[:short_window] if options[:short_window]
        params[:long_window] = options[:long_window] if options[:long_window]
        params[:signal_window] = options[:signal_window] if options[:signal_window]

        # Add common parameters
        params[:timespan] = options[:timespan] if options[:timespan]
        params[:series_type] = options[:series_type] if options[:series_type]
        params[:adjusted] = options[:adjusted] if options.key?(:adjusted)
        params[:limit] = options[:limit] if options[:limit]
        params[:order] = options[:order] if options[:order]

        params
      end

      # Load comprehensive technical indicator classes from separate files.
      # These provide extensive analysis capabilities for each indicator type
      # with rich analytical methods for trading signal generation.
      #
      # @see Polymux::Api::TechnicalIndicators::SMA Comprehensive SMA analysis
      # @see Polymux::Api::TechnicalIndicators::EMA Advanced EMA calculations
      # @see Polymux::Api::TechnicalIndicators::RSI Momentum and divergence analysis
      # @see Polymux::Api::TechnicalIndicators::MACD Crossover and histogram analysis
      autoload :SMA, "polymux/api/technical_indicators/sma"
      autoload :EMA, "polymux/api/technical_indicators/ema"
      autoload :RSI, "polymux/api/technical_indicators/rsi"
      autoload :MACD, "polymux/api/technical_indicators/macd"
    end
  end
end
