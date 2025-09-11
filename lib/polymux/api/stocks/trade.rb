require "dry/struct"
require "polymux/api/transformers"
require_relative "exchange_mapping"
require_relative "timestamp_formatting"

module Polymux
  module Api
    class Stocks
      # Represents a stock trade execution with full transaction details.
      #
      # Contains comprehensive information about an individual stock trade
      # including price, size, timestamp, exchange, and conditions. This
      # data structure provides detailed trade execution information for
      # analysis and reconstruction of price movements.
      #
      # @example Analyze trade execution
      #   trades = client.stocks.trades("AAPL", limit: 100)
      #   trade = trades.first
      #
      #   puts "Executed: #{trade.timestamp}"
      #   puts "Price: $#{trade.price}"
      #   puts "Size: #{trade.size} shares"
      #   puts "Value: $#{trade.total_value}"
      #   puts "Exchange: #{trade.exchange}"
      class Trade < Dry::Struct
        include ExchangeMapping
        include TimestampFormatting

        transform_keys(&:to_sym)

        # Stock ticker symbol
        # @return [String] The ticker symbol this trade belongs to
        attribute :ticker, Types::String

        # Trade execution timestamp
        # @return [String, Integer, nil] Timestamp in ISO format or nanoseconds
        attribute? :timestamp, Types::String | Types::Integer | Types::Nil

        # Trade execution price
        # @return [Integer, Float, nil] Price per share
        attribute? :price, Types::PolymuxNumber | Types::Nil

        # Number of shares traded
        # @return [Integer, nil] Share quantity
        attribute? :size, Types::Integer | Types::Nil

        # Exchange where trade occurred
        # @return [Integer, String, nil] Exchange identifier
        attribute? :exchange, Types::Integer | Types::String | Types::Nil

        # Trade conditions
        # @return [Array<Integer>, nil] Array of condition codes
        attribute? :conditions, Types::Array.of(Types::Integer) | Types::Nil

        # Participant timestamp (nanoseconds)
        # @return [Integer, String, nil] Participant-reported timestamp
        attribute? :participant_timestamp, Types::Integer | Types::String | Types::Nil

        # Trade ID
        # @return [String, nil] Unique trade identifier
        attribute? :id, Types::String | Types::Nil

        # Tape designation
        # @return [String, nil] SIP tape (A, B, or C)
        attribute? :tape, Types::String | Types::Nil

        # TRF (Trade Reporting Facility) ID
        # @return [Integer, nil] TRF identifier where applicable
        attribute? :trf_id, Types::Integer | Types::Nil

        # TRF timestamp
        # @return [String, Integer, nil] TRF timestamp
        attribute? :trf_timestamp, Types::String | Types::Integer | Types::Nil

        # Calculate total trade value.
        # @return [Numeric, nil] Total dollar value of the trade
        def total_value
          return nil unless price && size
          price * size
        end

        # Check if this is a large trade (block trade).
        # @return [Boolean] true if size >= 10,000 shares
        def block_trade?
          return false unless size
          size >= 10_000
        end

        # Check if this trade occurred during regular trading hours.
        # Assumes regular hours are 9:30 AM - 4:00 PM ET.
        # @return [Boolean] true if during regular hours
        def regular_hours?
          return false unless timestamp

          parse_trading_hours_time&.between?(930, 1600) || false
        end

        # Check if this is an extended hours trade.
        # @return [Boolean] true if outside regular trading hours
        def extended_hours?
          !regular_hours?
        end

        # Get exchange name from exchange code.
        # @return [String] Human-readable exchange name
        def exchange_name
          map_exchange_code(exchange)
        end

        # Format timestamp for display.
        # @return [String] Human-readable timestamp
        def formatted_timestamp
          format_timestamp(timestamp)
        end

        # Create Trade object from API response data.
        #
        # @param ticker [String] Stock ticker symbol
        # @param json [Hash] Raw trade data from API
        # @return [Trade] Transformed trade object
        # @api private
        def self.from_api(ticker, json)
          attrs = Api::Transformers.stock_trade(ticker, json)
          new(attrs)
        end

        private

        # Parses timestamp and converts to ET hour-minute format for trading hours check.
        # @return [Integer, nil] Hour-minute in HHMM format (e.g., 1430 for 2:30 PM) or nil if parsing fails
        def parse_trading_hours_time
          Time.parse(timestamp.to_s).getlocal("-05:00").then do |et_time|
            et_time.hour * 100 + et_time.min
          end
        rescue ArgumentError, TypeError
          nil
        end
      end
    end
  end
end
