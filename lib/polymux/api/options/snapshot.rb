require "dry/struct"
require "polymux/api/transformers"
require "polymux/api/options/underlying_asset"

module Polymux
  module Api
    class Options
      class Snapshot < Dry::Struct
        transform_keys(&:to_sym)

        attribute :break_even_price, Types::Float
        attribute? :daily_bar, DailyBar
        attribute? :implied_volatility, Types::Float
        attribute? :last_quote, LastQuote
        attribute? :last_trade, LastTrade
        attribute :open_interest, Types::Integer
        attribute :underlying_asset, UnderlyingAsset

        attribute? :greeks, Greeks

        def self.from_api(json)
          attrs = Api::Transformers.snapshot(json.deep_symbolize_keys)
          new(attrs)
        end
      end
    end
  end
end