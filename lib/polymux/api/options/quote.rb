require "dry/struct"
require "polymux/api/transformers"

module Polymux
  module Api
    class Options
      # Represents a market quote with bid/ask prices and sizes.
      #
      # Contains the best available bid and ask prices along with the
      # quantities available at those prices. Essential for understanding
      # market liquidity, spreads, and for making informed trading decisions.
      #
      # @example Analyze market liquidity
      #   quotes = client.options.quotes("O:AAPL240315C00150000", limit: 10)
      #   latest_quote = quotes.last
      #
      #   spread = latest_quote.spread
      #   spread_pct = latest_quote.spread_percentage
      #
      #   puts "Bid: #{latest_quote.bid_size} @ $#{latest_quote.bid_price}"
      #   puts "Ask: #{latest_quote.ask_size} @ $#{latest_quote.ask_price}"
      #   puts "Spread: $#{spread} (#{spread_pct.round(2)}%)"
      class Quote < Dry::Struct
        transform_keys(&:to_sym)

        # Options contract ticker symbol
        # @return [String] Contract identifier
        attribute :ticker, Types::String

        # Quote timestamp in nanoseconds
        # @return [Integer] Unix timestamp with nanosecond precision
        attribute :timestamp, Types::Integer

        # Quote time as DateTime object
        # @return [DateTime] Converted timestamp for easy manipulation
        attribute :datetime, Types::DateTime

        # Best ask (offer) price
        # @return [Integer, Float] Price sellers are asking
        attribute :ask_price, Types::PolymuxNumber

        # Best bid price
        # @return [Integer, Float] Price buyers are bidding
        attribute :bid_price, Types::PolymuxNumber

        # Number of contracts available at ask price
        # @return [Integer] Ask size (contracts)
        attribute :ask_size, Types::Integer

        # Number of contracts wanted at bid price
        # @return [Integer] Bid size (contracts)
        attribute :bid_size, Types::Integer

        # Sequence number for quote ordering
        # @return [Integer] Message sequence identifier
        attribute :sequence, Types::Integer

        # Calculate the bid-ask spread.
        #
        # @return [Float] Difference between ask and bid prices
        # @example
        #   quote.spread  # => 0.05 (ask $2.50, bid $2.45)
        def spread
          (ask_price - bid_price).round(4)
        end

        # Calculate the bid-ask spread as a percentage of the midpoint.
        #
        # @return [Float] Spread as percentage of mid price
        # @example
        #   quote.spread_percentage  # => 2.04 (2.04% spread)
        def spread_percentage
          return 0.0 if midpoint.zero?
          ((spread / midpoint) * 100).round(4)
        end

        # Calculate the midpoint price between bid and ask.
        #
        # @return [Float] Average of bid and ask prices
        # @example
        #   quote.midpoint  # => 2.475 (bid $2.45, ask $2.50)
        def midpoint
          ((bid_price + ask_price) / 2.0).round(4)
        end

        # Check if the market appears to be crossed (bid >= ask).
        #
        # This is unusual and may indicate data issues or very illiquid markets.
        #
        # @return [Boolean] true if bid price >= ask price
        def crossed?
          bid_price >= ask_price
        end

        # Get the total notional value at bid (bid price × bid size × 100).
        #
        # @return [Float] Dollar value of bid liquidity
        def bid_notional
          (bid_price * bid_size * 100).round(2)
        end

        # Get the total notional value at ask (ask price × ask size × 100).
        #
        # @return [Float] Dollar value of ask liquidity
        def ask_notional
          (ask_price * ask_size * 100).round(2)
        end

        # Create Quote object from API response data.
        #
        # @param ticker [String] Contract ticker symbol
        # @param json [Hash] Raw quote data from API
        # @return [Quote] Transformed quote object
        # @api private
        def self.from_api(ticker, json)
          attrs = Api::Transformers.quote(json)
          attrs[:ticker] = ticker
          new(attrs)
        end
      end
    end
  end
end
