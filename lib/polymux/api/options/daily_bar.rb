require "dry/struct"

module Polymux
  module Api
    class Options
      class DailyBar < Dry::Struct
        transform_keys(&:to_sym)

        attribute :open, Types::PolymuxNumber
        attribute :high, Types::PolymuxNumber
        attribute :low, Types::PolymuxNumber
        attribute :close, Types::PolymuxNumber
        attribute :volume, Types::PolymuxNumber
        attribute :vwap, Types::PolymuxNumber
        attribute :previous_close, Types::PolymuxNumber
        attribute :change, Types::PolymuxNumber
        attribute :change_percent, Types::PolymuxNumber
      end
    end
  end
end
