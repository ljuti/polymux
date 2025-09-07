require "dry/struct"
require "polymux/api/transformers"

module Polymux
  module Api
    class Options
      class Trade < Dry::Struct
        transform_keys(&:to_sym)

        attribute :ticker, Types::String
        attribute :timestamp, Types::Integer
        attribute :datetime, Types::DateTime
        attribute :price, Types::PolymuxNumber
        attribute :size, Types::PolymuxNumber

        def total_price
          (price * size).round(2)
        end
        
        def total_value
          (price * size * 100).round(2)
        end

        def self.from_api(ticker, json)
          attrs = Api::Transformers.trade(json)
          attrs[:ticker] = ticker
          new(attrs)
        end
      end
    end
  end
end
