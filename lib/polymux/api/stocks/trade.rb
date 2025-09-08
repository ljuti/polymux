require "dry/struct"
require "polymux/api/transformers"

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

          # Parse timestamp and check if between 9:30 AM and 4:00 PM ET
          begin
            time = Time.parse(timestamp)
            # Convert to ET (this is simplified - doesn't handle DST properly)
            et_time = time.getlocal("-05:00")
            hour_minute = et_time.hour * 100 + et_time.minute

            hour_minute.between?(930, 1600)
          rescue
            false
          end
        end

        # Check if this is an extended hours trade.
        # @return [Boolean] true if outside regular trading hours
        def extended_hours?
          !regular_hours?
        end

        # Get exchange name from exchange code.
        # @return [String] Human-readable exchange name
        def exchange_name
          case exchange.to_i
          when 1 then "NYSE"
          when 2 then "NASDAQ"
          when 3 then "NYSE MKT"
          when 4 then "NYSE Arca"
          when 5 then "BATS"
          when 6 then "IEX"
          when 11 then "NASDAQ OMX BX"
          when 12 then "NASDAQ OMX PSX"
          else "Unknown (#{exchange})"
          end
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
      end
    end
  end
end
