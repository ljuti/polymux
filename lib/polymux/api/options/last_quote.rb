require "dry/struct"

module Polymux
  module Api
    class Options
      # Represents the most recent bid/ask quote for an options contract.
      #
      # Attribute names follow the live snapshot wire format (`ask`/`bid`).
      # Legacy `ask_price`/`bid_price` input keys are still accepted via key
      # transformation, and `ask_price`/`bid_price` reader aliases are kept
      # for backwards compatibility.
      class LastQuote < Dry::Struct
        transform_keys do |key|
          case key.to_s
          when "ask_price" then :ask
          when "bid_price" then :bid
          else key.to_sym
          end
        end

        # Best ask price
        # @return [Integer, Float] Price sellers are asking
        attribute :ask, Types::PolymuxNumber

        # Number of contracts available at ask price
        # @return [Integer, Float] Ask size (contracts)
        attribute :ask_size, Types::PolymuxNumber

        # Exchange where the ask originated
        # @return [Integer, Float, nil] Ask exchange ID
        attribute? :ask_exchange, Types::PolymuxNumber

        # Best bid price
        # @return [Integer, Float] Price buyers are bidding
        attribute :bid, Types::PolymuxNumber

        # Number of contracts available at bid price
        # @return [Integer, Float] Bid size (contracts)
        attribute :bid_size, Types::PolymuxNumber

        # Exchange where the bid originated
        # @return [Integer, Float, nil] Bid exchange ID
        attribute? :bid_exchange, Types::PolymuxNumber

        # Midpoint of bid and ask
        # @return [Integer, Float, nil] Midpoint price
        attribute? :midpoint, Types::PolymuxNumber

        # Timestamp when the quote was last updated (nanoseconds)
        # @return [Integer] Unix timestamp with nanosecond precision
        attribute :last_updated, Types::Integer

        # Indicates whether data is real-time or delayed
        # @return [String, nil] "REAL-TIME" or "DELAYED"
        attribute? :timeframe, Types::String

        # Backwards-compatible alias for the ask price.
        # @return [Integer, Float] Ask price
        def ask_price
          ask
        end

        # Backwards-compatible alias for the bid price.
        # @return [Integer, Float] Bid price
        def bid_price
          bid
        end

        # Convert nanosecond timestamp to DateTime object.
        # @return [DateTime, nil] Converted timestamp for easy manipulation
        def timestamp
          Time.at(Rational(last_updated, 1_000_000_000)).to_datetime if last_updated
        end

        # Check if quote data is real-time.
        # @return [Boolean] true if timeframe is "REAL-TIME"
        def realtime?
          timeframe == "REAL-TIME"
        end

        # Check if quote data is delayed.
        # @return [Boolean] true if timeframe is "DELAYED"
        def delayed?
          timeframe == "DELAYED"
        end

        # Calculate the bid-ask spread.
        # @return [Float] Difference between ask and bid prices
        def spread
          (ask - bid).round(4)
        end

        # Calculate the bid-ask spread as a percentage of the midpoint.
        # @return [Float] Spread as percentage of mid price
        def spread_percentage
          mid = midpoint_price
          return 0.0 if mid.zero?
          ((spread / mid) * 100).round(4)
        end

        # Calculate the midpoint price between bid and ask.
        # @return [Float] Average of bid and ask prices, using attribute if available
        def midpoint_price
          return midpoint if midpoint
          ((bid + ask) / 2.0).round(4)
        end
      end
    end
  end
end
