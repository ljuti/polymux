require "dry/struct"
require "polymux/api/transformers"

module Polymux
  module Api
    class Stocks
      # Represents an OHLC (Open, High, Low, Close) aggregate bar for a stock.
      #
      # Contains comprehensive aggregate data for a specific time period including
      # price data (open, high, low, close), volume, VWAP, and statistical metrics.
      # This is the foundation for charting, technical analysis, and backtesting.
      #
      # @example Price analysis
      #   aggregates = client.stocks.aggregates("AAPL", 1, "day", "2024-01-01", "2024-06-30")
      #   bar = aggregates.first
      #
      #   puts "Date: #{bar.formatted_timestamp}"
      #   puts "OHLC: #{bar.open}/#{bar.high}/#{bar.low}/#{bar.close}"
      #   puts "Volume: #{bar.volume}"
      #   puts "VWAP: $#{bar.vwap}"
      #   puts "Range: #{bar.range_percent}%"
      class Aggregate < Dry::Struct
        transform_keys(&:to_sym)

        # Stock ticker symbol
        # @return [String] The ticker symbol this bar belongs to
        attribute :ticker, Types::String

        # Opening price
        # @return [Integer, Float, nil] Opening price for the period
        attribute? :open, Types::PolymuxNumber | Types::Nil

        # Highest price
        # @return [Integer, Float, nil] Highest price during the period
        attribute? :high, Types::PolymuxNumber | Types::Nil

        # Lowest price
        # @return [Integer, Float, nil] Lowest price during the period
        attribute? :low, Types::PolymuxNumber | Types::Nil

        # Closing price
        # @return [Integer, Float, nil] Closing price for the period
        attribute? :close, Types::PolymuxNumber | Types::Nil

        # Trading volume
        # @return [Integer, nil] Number of shares traded
        attribute? :volume, Types::Integer | Types::Nil

        # Volume Weighted Average Price
        # @return [Integer, Float, nil] VWAP for the period
        attribute? :vwap, Types::PolymuxNumber | Types::Nil

        # Period timestamp (Unix milliseconds)
        # @return [Integer, String, nil] Start of the period
        attribute? :timestamp, Types::Integer | Types::String | Types::Nil

        # Number of transactions
        # @return [Integer, nil] Number of trades in this period
        attribute? :transactions, Types::Integer | Types::Nil

        # Check if this is a green/up bar.
        # @return [Boolean] true if close > open
        def green?
          return false unless open && close
          close > open
        end

        # Check if this is a red/down bar.
        # @return [Boolean] true if close < open
        def red?
          return false unless open && close
          close < open
        end

        # Check if this is a doji (open equals close).
        # @return [Boolean] true if open == close
        def doji?
          return false unless open && close
          open == close
        end

        # Calculate the bar's body size (absolute difference between open and close).
        # @return [Numeric, nil] Size of the candlestick body
        def body_size
          return nil unless open && close
          (close - open).abs.round(10)
        end

        # Calculate the bar's range (high - low).
        # @return [Numeric, nil] Full range of the bar
        def range
          return nil unless high && low
          (high - low).round(10)
        end

        # Calculate range as percentage of opening price.
        # @return [Float, nil] Range percentage
        def range_percent
          return nil unless range && open && open > 0
          (range / open * 100).round(4)
        end

        # Calculate upper shadow (wick above body).
        # @return [Numeric, nil] Size of upper shadow
        def upper_shadow
          return nil unless high && open && close
          body_top = [open, close].max
          (high - body_top).round(10)
        end

        # Calculate lower shadow (wick below body).
        # @return [Numeric, nil] Size of lower shadow
        def lower_shadow
          return nil unless low && open && close
          body_bottom = [open, close].min
          (body_bottom - low).round(10)
        end

        # Calculate percentage change from open to close.
        # @return [Float, nil] Percentage change
        def change_percent
          return nil unless open && close && open > 0
          ((close - open) / open * 100).round(4)
        end

        # Calculate dollar change from open to close.
        # @return [Numeric, nil] Dollar change
        def change_amount
          return nil unless open && close
          (close - open).round(10)
        end

        # Check if this is a high-volume bar (> 2x average).
        # This is a simplified check - ideally would compare to historical average.
        # @return [Boolean] true if volume appears high
        def high_volume?
          return false unless volume
          # This is a placeholder - would need historical data for proper calculation
          volume > 1_000_000 # Simplified threshold
        end

        # Calculate turnover ratio if shares outstanding available.
        # @param shares_outstanding [Integer] Number of shares outstanding
        # @return [Float, nil] Volume as percentage of shares outstanding
        def turnover_ratio(shares_outstanding)
          return nil unless volume && shares_outstanding && shares_outstanding > 0
          (volume.to_f / shares_outstanding * 100).round(4)
        end

        # Get typical price (average of high, low, close).
        # @return [Float, nil] Typical price for the period
        def typical_price
          return nil unless high && low && close
          (high + low + close) / 3.0
        end

        # Check if VWAP is above closing price (potential support).
        # @return [Boolean, nil] true if VWAP > close
        def vwap_above_close?
          return nil unless vwap && close
          vwap > close
        end

        # Check if closing price is near high (within 2%).
        # @return [Boolean] true if close is near high
        def close_near_high?
          return false unless close && high && high > 0
          ((high - close) / high * 100).round(4) <= 2.0
        end

        # Check if closing price is near low (within 2%).
        # @return [Boolean] true if close is near low
        def close_near_low?
          return false unless close && low && low > 0
          ((close - low) / low * 100).round(4) <= 2.0
        end

        # Format timestamp as date string.
        # @return [String] Human-readable date
        def formatted_timestamp
          return "N/A" unless timestamp
          return "N/A" if timestamp.to_s.strip.empty?

          # If timestamp is not a valid number, return as-is
          return timestamp.to_s unless /^\d+$/.match?(timestamp.to_s)

          begin
            # Convert milliseconds to seconds for Time.at
            time_seconds = timestamp.to_i / 1000.0
            Time.at(time_seconds).utc.strftime("%Y-%m-%d")
          rescue
            timestamp.to_s
          end
        end

        # Format timestamp as datetime string.
        # @return [String] Human-readable datetime
        def formatted_datetime
          return "N/A" unless timestamp
          return "N/A" if timestamp.to_s.strip.empty?

          # If timestamp is not a valid number, return as-is
          return timestamp.to_s unless /^\d+$/.match?(timestamp.to_s)

          begin
            # Convert milliseconds to seconds for Time.at
            time_seconds = timestamp.to_i / 1000.0
            Time.at(time_seconds).utc.strftime("%Y-%m-%d %H:%M:%S")
          rescue
            timestamp.to_s
          end
        end

        # Get OHLC as formatted string.
        # @return [String] OHLC values formatted for display
        def ohlc_string
          return "N/A" unless open && high && low && close
          "O:#{open} H:#{high} L:#{low} C:#{close}"
        end

        # Create Aggregate object from API response data.
        #
        # @param ticker [String] Stock ticker symbol
        # @param json [Hash] Raw aggregate data from API
        # @return [Aggregate] Transformed aggregate object
        # @api private
        def self.from_api(ticker, json)
          attrs = Api::Transformers.stock_aggregate(ticker, json)
          new(attrs)
        end
      end
    end
  end
end
