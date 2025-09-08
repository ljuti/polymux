require "dry/struct"
require "polymux/api/transformers"

module Polymux
  module Api
    class Stocks
      # Represents a stock bid/ask quote with market maker information.
      #
      # Contains comprehensive quote information including bid and ask prices,
      # sizes, timestamps, and exchange data. This data structure provides
      # detailed market depth information for understanding liquidity and
      # spread patterns.
      #
      # @example Analyze bid/ask spread
      #   quotes = client.stocks.quotes("AAPL", limit: 100)
      #   quote = quotes.first
      #
      #   puts "Bid: #{quote.bid_size} @ $#{quote.bid_price}"
      #   puts "Ask: #{quote.ask_size} @ $#{quote.ask_price}"
      #   puts "Spread: $#{quote.spread} (#{quote.spread_percentage}%)"
      #   puts "Midpoint: $#{quote.midpoint}"
      class Quote < Dry::Struct
        transform_keys(&:to_sym)

        # Stock ticker symbol
        # @return [String] The ticker symbol this quote belongs to
        attribute :ticker, Types::String

        # Quote timestamp
        # @return [String, Integer, nil] Timestamp in ISO format or nanoseconds
        attribute? :timestamp, Types::String | Types::Integer | Types::Nil

        # Bid price
        # @return [Integer, Float, nil] Best bid price
        attribute? :bid_price, Types::PolymuxNumber | Types::Nil

        # Ask price
        # @return [Integer, Float, nil] Best ask price
        attribute? :ask_price, Types::PolymuxNumber | Types::Nil

        # Bid size
        # @return [Integer, nil] Number of shares at bid price
        attribute? :bid_size, Types::Integer | Types::Nil

        # Ask size
        # @return [Integer, nil] Number of shares at ask price
        attribute? :ask_size, Types::Integer | Types::Nil

        # Bid exchange
        # @return [Integer, String, nil] Exchange providing bid
        attribute? :bid_exchange, Types::Integer | Types::String | Types::Nil

        # Ask exchange
        # @return [Integer, String, nil] Exchange providing ask
        attribute? :ask_exchange, Types::Integer | Types::String | Types::Nil

        # Participant timestamp (nanoseconds)
        # @return [Integer, String, nil] Participant-reported timestamp
        attribute? :participant_timestamp, Types::Integer | Types::String | Types::Nil

        # Quote conditions
        # @return [Array<Integer>, nil] Array of condition codes
        attribute? :conditions, Types::Array.of(Types::Integer) | Types::Nil

        # Indicators
        # @return [Array<Integer>, nil] Quote indicators
        attribute? :indicators, Types::Array.of(Types::Integer) | Types::Nil

        # Tape designation
        # @return [String, nil] SIP tape (A, B, or C)
        attribute? :tape, Types::String | Types::Nil

        # Calculate bid/ask spread.
        # @return [Numeric, nil] Spread in dollars
        def spread
          return nil unless bid_price && ask_price
          ask_price - bid_price
        end

        # Calculate bid/ask spread as percentage of midpoint.
        # @return [Float, nil] Spread percentage
        def spread_percentage
          return nil unless spread && midpoint && midpoint > 0
          (spread / midpoint * 100).round(4)
        end

        # Calculate midpoint between bid and ask.
        # @return [Float, nil] Midpoint price
        def midpoint
          return nil unless bid_price && ask_price
          (bid_price + ask_price) / 2.0
        end

        # Calculate total bid value.
        # @return [Numeric, nil] Total dollar value at bid
        def bid_value
          return nil unless bid_price && bid_size
          bid_price * bid_size
        end

        # Calculate total ask value.
        # @return [Numeric, nil] Total dollar value at ask
        def ask_value
          return nil unless ask_price && ask_size
          ask_price * ask_size
        end

        # Check if spread is tight (< 0.1% of midpoint).
        # @return [Boolean] true if spread is tight
        def tight_spread?
          return false unless spread_percentage
          spread_percentage < 0.1
        end

        # Check if spread is wide (> 1% of midpoint).
        # @return [Boolean] true if spread is wide
        def wide_spread?
          return false unless spread_percentage
          spread_percentage > 1.0
        end

        # Check if this quote has size on both sides.
        # @return [Boolean] true if both bid and ask have size
        def two_sided?
          bid_size && ask_size && bid_size > 0 && ask_size > 0
        end

        # Get bid exchange name.
        # @return [String] Human-readable bid exchange name
        def bid_exchange_name
          exchange_name_for(bid_exchange)
        end

        # Get ask exchange name.
        # @return [String] Human-readable ask exchange name
        def ask_exchange_name
          exchange_name_for(ask_exchange)
        end

        # Format timestamp for display.
        # @return [String] Human-readable timestamp
        def formatted_timestamp
          return "N/A" unless timestamp

          begin
            Time.parse(timestamp).strftime("%Y-%m-%d %H:%M:%S")
          rescue
            timestamp.to_s
          end
        end

        # Create Quote object from API response data.
        #
        # @param ticker [String] Stock ticker symbol
        # @param json [Hash] Raw quote data from API
        # @return [Quote] Transformed quote object
        # @api private
        def self.from_api(ticker, json)
          attrs = Api::Transformers.stock_quote(ticker, json)
          new(attrs)
        end

        private

        # Convert exchange code to name.
        # @param exchange_code [Integer, String, nil] Exchange identifier
        # @return [String] Exchange name
        def exchange_name_for(exchange_code)
          case exchange_code.to_i
          when 1 then "NYSE"
          when 2 then "NASDAQ"
          when 3 then "NYSE MKT"
          when 4 then "NYSE Arca"
          when 5 then "BATS"
          when 6 then "IEX"
          when 11 then "NASDAQ OMX BX"
          when 12 then "NASDAQ OMX PSX"
          else "Unknown (#{exchange_code})"
          end
        end
      end
    end
  end
end
