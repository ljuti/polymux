require "dry/struct"

module Polymux
  module Api
    class Options
      class LastTrade < Dry::Struct
        transform_keys(&:to_sym)

        attribute :price, Types::PolymuxNumber
        attribute :size, Types::Integer
        attribute :sip_timestamp, Types::Integer
        attribute? :timeframe, Types::String

        def timestamp
          Time.at(Rational(sip_timestamp, 1_000_000_000)).to_datetime if sip_timestamp
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
