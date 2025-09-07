require "dry/struct"

module Polymux
  module Api
    class Options
      # Represents daily OHLC (Open, High, Low, Close) bar data for an options contract.
      #
      # Contains comprehensive daily trading statistics including price action,
      # volume, and percentage changes. Essential for technical analysis and
      # understanding daily trading patterns.
      #
      # @example Daily performance analysis
      #   snapshot = client.options.snapshot(contract)
      #   daily_bar = snapshot.daily_bar
      #
      #   if daily_bar
      #     puts "Daily range: $#{daily_bar.low} - $#{daily_bar.high}"
      #     puts "Volume: #{daily_bar.volume} contracts"
      #     puts "VWAP: $#{daily_bar.vwap}"
      #     puts "Change: #{daily_bar.change_direction} $#{daily_bar.change.abs} (#{daily_bar.change_percent}%)"
      #     puts "Volatility: #{daily_bar.intraday_volatility.round(2)}%"
      #   end
      class DailyBar < Dry::Struct
        transform_keys(&:to_sym)

        # Opening price for the trading day
        # @return [Integer, Float] First trade price of the day
        attribute :open, Types::PolymuxNumber

        # Highest price during the trading day
        # @return [Integer, Float] Peak price reached
        attribute :high, Types::PolymuxNumber

        # Lowest price during the trading day
        # @return [Integer, Float] Lowest price reached
        attribute :low, Types::PolymuxNumber

        # Closing price for the trading day
        # @return [Integer, Float] Last trade price of the day
        attribute :close, Types::PolymuxNumber

        # Total volume traded during the day
        # @return [Integer, Float] Number of contracts traded
        attribute :volume, Types::PolymuxNumber

        # Volume-weighted average price
        # @return [Integer, Float] Average price weighted by volume
        attribute :vwap, Types::PolymuxNumber

        # Previous day's closing price
        # @return [Integer, Float] Prior session close for comparison
        attribute :previous_close, Types::PolymuxNumber

        # Price change from previous close
        # @return [Integer, Float] Dollar change (close - previous_close)
        attribute :change, Types::PolymuxNumber

        # Percentage change from previous close
        # @return [Integer, Float] Percentage change as decimal
        attribute :change_percent, Types::PolymuxNumber

        # Calculate the intraday trading range.
        # @return [Float] Difference between high and low prices
        def range
          (high - low).round(4)
        end

        # Calculate intraday volatility as percentage of opening price.
        # @return [Float] Volatility percentage based on daily range
        def intraday_volatility
          return 0.0 if open.zero?
          ((range / open) * 100).round(4)
        end

        # Get the direction of price change.
        # @return [String] "up", "down", or "unchanged"
        def change_direction
          return "unchanged" if change.zero?
          (change > 0) ? "up" : "down"
        end

        # Check if the day was positive (close > open).
        # @return [Boolean] true if closing price exceeded opening price
        def green_day?
          close > open
        end

        # Check if the day was negative (close < open).
        # @return [Boolean] true if closing price was below opening price
        def red_day?
          close < open
        end

        # Check if the day was a doji (open ≈ close).
        # @return [Boolean] true if open and close are very close
        def doji?
          (open - close).abs < (range * 0.1)
        end

        # Check if volume was above average (simple heuristic: > 1000 contracts).
        # @return [Boolean] true if volume indicates active trading
        def high_volume?
          volume > 1000
        end

        # Calculate the body size (absolute difference between open and close).
        # @return [Float] Size of the candlestick body
        def body_size
          (close - open).abs.round(4)
        end

        # Calculate upper shadow (high - max(open, close)).
        # @return [Float] Length of upper wick/shadow
        def upper_shadow
          (high - [open, close].max).round(4)
        end

        # Calculate lower shadow (min(open, close) - low).
        # @return [Float] Length of lower wick/shadow
        def lower_shadow
          ([open, close].min - low).round(4)
        end
      end
    end
  end
end
