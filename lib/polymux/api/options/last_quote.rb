require "dry/struct"

module Polymux
  module Api
    class Options
      class LastQuote < Dry::Struct
        transform_keys(&:to_sym)

        attribute :ask, Types::PolymuxNumber
        attribute :ask_size, Types::PolymuxNumber
        attribute :bid, Types::PolymuxNumber
        attribute :bid_size, Types::PolymuxNumber
        attribute :midpoint, Types::PolymuxNumber
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
      end
    end
  end
end
