require "dry/struct"

module Polymux
  module Api
    class Options
      # Represents the underlying asset information for an options contract.
      #
      # Contains current price and status information for the stock or asset
      # that underlies the options contract. This data is essential for
      # understanding the relationship between option and underlying prices.
      #
      # @example Underlying asset analysis
      #   snapshot = client.options.snapshot(contract)
      #   underlying = snapshot.underlying_asset
      #
      #   puts "Underlying: #{underlying.ticker} @ $#{underlying.price}"
      #   puts "Data type: #{underlying.realtime? ? 'Real-time' : 'Delayed'}"
      #   puts "Last updated: #{underlying.timestamp}"
      #
      #   if underlying.change_to_break_even > 0
      #     puts "Underlying needs to move up $#{underlying.change_to_break_even} to break even"
      #   else
      #     puts "Underlying needs to move down $#{underlying.change_to_break_even.abs} to break even"
      #   end
      class UnderlyingAsset < Dry::Struct
        transform_keys(&:to_sym)

        # Ticker symbol of the underlying asset
        # @return [String] Stock ticker (e.g., "AAPL")
        attribute :ticker, Types::String

        # Current price of the underlying asset
        # @return [Integer, Float, nil] Current stock price
        attribute? :price, Types::PolymuxNumber | Types::Nil

        # Current value (may be same as price or calculated differently)
        # @return [Integer, Float, nil] Asset value
        attribute? :value, Types::PolymuxNumber | Types::Nil

        # Timestamp when underlying data was last updated (nanoseconds)
        # @return [Integer, nil] Unix timestamp with nanosecond precision
        attribute? :last_updated, Types::Integer | Types::Nil

        # Indicates whether data is real-time or delayed
        # @return [String, nil] "REAL-TIME" or "DELAYED"
        attribute? :timeframe, Types::String | Types::Nil

        # Dollar amount underlying needs to move to reach option break-even
        # @return [Integer, Float] Positive = needs to go up, negative = needs to go down
        attribute :change_to_break_even, Types::PolymuxNumber

        # Convert nanosecond timestamp to DateTime object.
        # @return [DateTime, nil] Converted timestamp for easy manipulation
        def timestamp
          Time.at(Rational(last_updated, 1_000_000_000)).to_datetime if last_updated
        end

        # Check if underlying data is real-time.
        # @return [Boolean] true if timeframe is "REAL-TIME"
        def realtime?
          timeframe == "REAL-TIME"
        end

        # Check if underlying data is delayed.
        # @return [Boolean] true if timeframe is "DELAYED"
        def delayed?
          timeframe == "DELAYED"
        end

        # Check if underlying needs to move up to reach break-even.
        # @return [Boolean] true if change_to_break_even is positive
        def needs_to_rise?
          change_to_break_even > 0
        end

        # Check if underlying needs to move down to reach break-even.
        # @return [Boolean] true if change_to_break_even is negative
        def needs_to_fall?
          change_to_break_even < 0
        end

        # Get the absolute distance to break-even.
        # @return [Float] Absolute dollar amount to break-even
        def distance_to_break_even
          change_to_break_even.abs
        end

        # Calculate percentage move needed to reach break-even.
        # @return [Float, nil] Percentage move required (nil if no price data)
        def break_even_move_percentage
          return nil unless price && !price.zero?
          ((change_to_break_even / price) * 100).round(4)
        end

        # Check if underlying price data is stale (>5 minutes old).
        # @return [Boolean] true if data appears stale
        def stale_data?
          return false unless last_updated
          current_time = Time.now.to_f * 1_000_000_000
          (current_time - last_updated) > (5 * 60 * 1_000_000_000)
        end
      end
    end
  end
end
