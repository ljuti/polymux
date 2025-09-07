require "dry/transformer"

module Polymux
  module Api
    # Data transformation utilities for converting API responses to Ruby objects.
    #
    # This module provides transformation functions that normalize data from the
    # Polygon.io API into consistent Ruby hash structures suitable for use with
    # dry-struct objects. The transformers handle key renaming, timestamp conversion,
    # and data cleanup operations.
    #
    # All transformers are built on top of dry-transformer which provides a
    # functional approach to data transformations with composable operations.
    #
    # @example Using a transformer
    #   raw_quote = {
    #     "sip_timestamp" => 1678901234000000000,
    #     "ask_price" => 150.25,
    #     "bid_price" => 150.20
    #   }
    #
    #   transformed = Api::Transformers.quote(raw_quote)
    #   # => {
    #   #   timestamp: 1678901234000000000,
    #   #   datetime: 2023-03-15 14:30:34 UTC,
    #   #   ask_price: 150.25,
    #   #   bid_price: 150.20
    #   # }
    #
    # @see https://dry-rb.org/gems/dry-transformer/ dry-transformer documentation
    module Transformers
      extend Dry::Transformer::Registry

      import :symbolize_keys, from: Dry::Transformer::HashTransformations
      import :rename_keys, from: Dry::Transformer::HashTransformations
      import Dry::Transformer::Coercions

      # Transform contract data from API format to Ruby hash.
      #
      # Converts string keys to symbols for consistency with Ruby conventions.
      #
      # @param json [Hash] Raw contract data from API
      # @return [Hash] Transformed hash with symbolized keys
      def self.contract(json)
        self[:symbolize_keys].call(json)
      end

      # Transform quote data from API format to Ruby hash.
      #
      # Performs key renaming for Ruby conventions and converts nanosecond
      # timestamps to both Unix timestamp integers and DateTime objects.
      #
      # @param json [Hash] Raw quote data from API
      # @return [Hash] Transformed hash with:
      #   - :timestamp instead of :sip_timestamp
      #   - :sequence instead of :sequence_number
      #   - :datetime converted from nanosecond timestamp
      def self.quote(json)
        input = self[:symbolize_keys].call(json)
        input = self[:rename_keys].call(input, sip_timestamp: :timestamp, sequence_number: :sequence)
        input[:datetime] = Time.at(input[:timestamp] / 1_000_000_000).to_datetime if input[:timestamp]
        input
      end

      # Transform trade data from API format to Ruby hash.
      #
      # Performs key renaming and timestamp conversion similar to quotes
      # but with trade-specific field mappings.
      #
      # @param json [Hash] Raw trade data from API
      # @return [Hash] Transformed hash with:
      #   - :timestamp instead of :sip_timestamp
      #   - :datetime converted from nanosecond timestamp
      def self.trade(json)
        input = self[:symbolize_keys].call(json)
        input = self[:rename_keys].call(input, sip_timestamp: :timestamp)
        input[:datetime] = Time.at(input[:timestamp] / 1_000_000_000).to_datetime if input[:timestamp]
        input
      end

      # Transform market status data from API format to Ruby hash.
      #
      # Converts camelCase API keys to Ruby snake_case conventions for
      # market status and schedule information.
      #
      # @param json [Hash] Raw market status data from API
      # @return [Hash] Transformed hash with Ruby-style keys:
      #   - :after_hours instead of :afterHours
      #   - :pre_market instead of :earlyHours
      #   - :status instead of :market
      #   - :indices instead of :indiceGroups
      def self.market_status(json)
        return {} unless json.is_a?(Hash)
        input = self[:symbolize_keys].call(json)
        self[:rename_keys].call(input, afterHours: :after_hours, earlyHours: :pre_market, market: :status, indiceGroups: :indices)
      end

      # Transform previous day aggregate data from API format to Ruby hash.
      #
      # Converts single-letter API keys to descriptive Ruby field names
      # for OHLC (Open, High, Low, Close) market data.
      #
      # @param json [Hash] Raw previous day data from API
      # @return [Hash] Transformed hash with descriptive keys:
      #   - :ticker instead of :T
      #   - :close instead of :c
      #   - :open instead of :o
      #   - :high instead of :h
      #   - :low instead of :l
      #   - :volume instead of :v
      #   - :vwap instead of :vw
      #   - :timestamp instead of :t
      def self.previous_day(json)
        input = self[:symbolize_keys].call(json)
        self[:rename_keys].call(input, T: :ticker, c: :close, o: :open, h: :high, l: :low, v: :volume, vw: :vwap, t: :timestamp)
      end

      # Transform snapshot data from API format to Ruby hash.
      #
      # Performs key renaming and removes empty nested objects that would
      # cause issues in dry-struct initialization.
      #
      # @param json [Hash] Raw snapshot data from API
      # @return [Hash] Transformed hash with:
      #   - :daily_bar instead of :day
      #   - Empty :last_quote, :last_trade, and :daily_bar objects removed
      def self.snapshot(json)
        input = self[:symbolize_keys].call(json)
        input = self[:rename_keys].call(input, day: :daily_bar)
        input.delete(:last_quote) if input[:last_quote] && input[:last_quote].empty?
        input.delete(:last_trade) if input[:last_trade] && input[:last_trade].empty?
        input.delete(:daily_bar) if input[:daily_bar] && input[:daily_bar].empty?
        input
      end
    end
  end
end
