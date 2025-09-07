require "dry/struct"
require "polymux/api/transformers"

module Polymux
  module Api
    class Options
      class Quote < Dry::Struct
        transform_keys(&:to_sym)

        attribute :ticker, Types::String
        attribute :timestamp, Types::Integer
        attribute :datetime, Types::DateTime
        attribute :ask_price, Types::PolymuxNumber
        attribute :bid_price, Types::PolymuxNumber
        attribute :ask_size, Types::Integer
        attribute :bid_size, Types::Integer
        attribute :sequence, Types::Integer

        def self.from_api(ticker, json)
          attrs = Api::Transformers.quote(json)
          attrs[:ticker] = ticker
          new(attrs)
        end
      end
    end
  end
end
