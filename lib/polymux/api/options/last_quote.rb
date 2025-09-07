require "dry/struct"

module Polymux
  module Api
    class Options
      class LastQuote < Dry::Struct
        transform_keys(&:to_sym)

        attribute :ask_price, Types::PolymuxNumber
        attribute :ask_size, Types::PolymuxNumber
        attribute :bid_price, Types::PolymuxNumber
        attribute :bid_size, Types::PolymuxNumber
        attribute? :midpoint, Types::PolymuxNumber
        attribute :last_updated, Types::Integer
        attribute? :timeframe, Types::String

        def timestamp
          Time.at(Rational(last_updated, 1_000_000_000)).to_datetime if last_updated
        end

        def realtime?
          timeframe == "REAL-TIME"
        end

        def delayed?
          timeframe == "DELAYED"
        end

        # Calculate the bid-ask spread.
        # @return [Float] Difference between ask and bid prices
        def spread
          (ask_price - bid_price).round(4)
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
          ((bid_price + ask_price) / 2.0).round(4)
        end
      end
    end
  end
end
