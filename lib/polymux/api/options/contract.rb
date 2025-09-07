require "dry/struct"
require "polymux/api/transformers"

module Polymux
  module Api
    class Options
      class Contract < Dry::Struct
        transform_keys(&:to_sym)

        attribute :cfi, Types::String
        attribute :contract_type, Types::String
        attribute :exercise_style, Types::String
        attribute :expiration_date, Types::String
        attribute :primary_exchange, Types::String
        attribute :strike_price, Types::PolymuxNumber
        attribute :shares_per_contract, Types::Integer
        attribute :ticker, Types::String
        attribute :underlying_ticker, Types::String

        def self.from_api(json)
          attrs = Api::Transformers.contract(json)
          new(attrs)
        end
      end
    end
  end
end
