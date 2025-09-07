require "dry/struct"

module Polymux
  module Api
    class Options
      class UnderlyingAsset < Dry::Struct
        transform_keys(&:to_sym)

        attribute :ticker, Types::String
        attribute? :price, Types::Float | Types::Nil
        attribute? :value, Types::Float | Types::Nil
        attribute? :last_updated, Types::Integer | Types::Nil
        attribute? :timeframe, Types::String | Types::Nil
        attribute :change_to_break_even, Types::Float | Types::Integer

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