require "dry/struct"

module Polymux
  module Api
    class Options
      class DailySummary < Dry::Struct
        transform_keys(&:to_sym)

        attribute :symbol, Types::String
        attribute :date, Types::String
        attribute :open, Types::PolymuxNumber
        attribute :high, Types::PolymuxNumber
        attribute :low, Types::PolymuxNumber
        attribute :close, Types::PolymuxNumber
        attribute :volume, Types::Integer
        attribute? :pre_market_open, Types::PolymuxNumber
        attribute? :after_hours_close, Types::PolymuxNumber
      end
    end
  end
end
