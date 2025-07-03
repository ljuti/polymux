require "dry/transformer"

module Polymux
  module Api
    module Transformers
      extend Dry::Transformer::Registry

      import :symbolize_keys, from: Dry::Transformer::HashTransformations
      import :rename_keys, from: Dry::Transformer::HashTransformations
      import Dry::Transformer::Coercions

      def self.contract(json)
        json = self[:symbolize_keys].(json)
        json
      end

      def self.quote(json)
        input = self[:symbolize_keys].(json)
        input = self[:rename_keys].(input, sip_timestamp: :timestamp, sequence_number: :sequence)
        input[:datetime] = Time.at(input[:timestamp] / 1_000_000_000).to_datetime if input[:timestamp]
        input
      end

      def self.trade(json)
        input = self[:symbolize_keys].(json)
        input = self[:rename_keys].(input, sip_timestamp: :timestamp)
        input[:datetime] = Time.at(input[:timestamp] / 1_000_000_000).to_datetime if input[:timestamp]
        input
      end

      def self.market_status(json)
        input = self[:symbolize_keys].(json)
        input = self[:rename_keys].(input, afterHours: :after_hours, earlyHours: :pre_market, market: :status, indiceGroups: :indices)
        input
      end

      def self.previous_day(json)
        input = self[:symbolize_keys].(json)
        input = self[:rename_keys].(input, T: :ticker, c: :close, o: :open, h: :high, l: :low, v: :volume, vw: :vwap, t: :timestamp)
        input
      end

      def self.snapshot(json)
        input = self[:rename_keys].(json, day: :daily_bar)
        input.delete(:last_quote) if input[:last_quote].empty?
        input.delete(:last_trade) if input[:last_trade].empty?
        input.delete(:daily_bar) if input[:daily_bar].empty?
        input
      end
    end
  end
end