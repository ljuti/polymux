require "dry/struct"
require "polymux/api/transformers"

module Polymux
  module Api
    class Options
      class PreviousDay < Dry::Struct
        transform_keys(&:to_sym)

        attribute :ticker, Types::String
        attribute :timestamp, Types::Integer
        attribute :open, Types::PolymuxNumber
        attribute :high, Types::PolymuxNumber
        attribute :low, Types::PolymuxNumber
        attribute :close, Types::PolymuxNumber
        attribute :volume, Types::Integer
        attribute :vwap, Types::PolymuxNumber

        def datetime
          Time.at(Rational(timestamp, 1000)).to_datetime if timestamp
        end

        def self.from_api(json)
          attrs = Api::Transformers.previous_day(json)
          new(attrs)
        end
      end
    end
  end
end
