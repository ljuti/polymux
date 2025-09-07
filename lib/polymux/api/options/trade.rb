require "dry/struct"
require "polymux/api/transformers"

module Polymux
  module Api
    class Options
      # Represents a completed options trade with execution details.
      #
      # Contains information about actual trade executions including price,
      # quantity, and timestamp. Essential for analyzing trading activity,
      # price discovery, and market liquidity patterns.
      #
      # @example Analyze trade execution
      #   trades = client.options.trades("O:AAPL240315C00150000", limit: 100)
      #
      #   trades.each do |trade|
      #     puts "#{trade.datetime.strftime('%H:%M:%S')}: #{trade.size} @ $#{trade.price}"
      #     puts "  Total premium: $#{trade.total_price}"
      #     puts "  Notional value: $#{trade.total_value}"
      #   end
      class Trade < Dry::Struct
        transform_keys(&:to_sym)

        # Options contract ticker symbol
        # @return [String] Contract identifier
        attribute :ticker, Types::String

        # Trade execution timestamp in nanoseconds
        # @return [Integer] Unix timestamp with nanosecond precision
        attribute :timestamp, Types::Integer

        # Trade execution time as DateTime object
        # @return [DateTime] Converted timestamp for easy manipulation
        attribute :datetime, Types::DateTime

        # Price per contract at execution
        # @return [Integer, Float] Trade price in dollars
        attribute :price, Types::PolymuxNumber

        # Number of contracts traded
        # @return [Integer, Float] Contract quantity
        attribute :size, Types::PolymuxNumber

        # Calculate total premium paid/received for the trade.
        #
        # This is the actual dollar amount that changed hands for
        # the options premium only (price × size).
        #
        # @return [Float] Total premium amount rounded to 2 decimal places
        # @example
        #   # Trade: 5 contracts at $2.50 each
        #   trade.total_price  # => 12.50
        def total_price
          (price * size).round(2)
        end

        # Calculate total notional value of the trade.
        #
        # This represents the total dollar value controlled by the trade,
        # calculated as premium × contract multiplier (typically 100).
        # Useful for understanding the scale of the position.
        #
        # @return [Float] Total notional value rounded to 2 decimal places
        # @example
        #   # Trade: 5 contracts at $2.50 each (standard 100 multiplier)
        #   trade.total_value  # => 1250.00
        def total_value
          (price * size * 100).round(2)
        end

        # Create Trade object from API response data.
        #
        # @param ticker [String] Contract ticker symbol
        # @param json [Hash] Raw trade data from API
        # @return [Trade] Transformed trade object
        # @api private
        def self.from_api(ticker, json)
          attrs = Api::Transformers.trade(json)
          attrs[:ticker] = ticker
          new(attrs)
        end
      end
    end
  end
end
