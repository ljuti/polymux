require "dry/struct"
require "polymux/api/transformers"

module Polymux
  module Api
    class Stocks
      # Represents a comprehensive market snapshot for a stock.
      #
      # Contains current market data including last trade, last quote,
      # daily bar information, previous close data, and market status.
      # This provides a complete real-time view of a stock's market state.
      #
      # @example Market analysis
      #   snapshot = client.stocks.snapshot("AAPL")
      #
      #   puts "Last Price: $#{snapshot.last_trade&.price}"
      #   puts "Change: $#{snapshot.daily_bar&.change} (#{snapshot.daily_bar&.change_percent}%)"
      #   puts "Volume: #{snapshot.daily_bar&.volume}"
      #   puts "Bid/Ask: $#{snapshot.last_quote&.bid_price}/$#{snapshot.last_quote&.ask_price}"
      class Snapshot < Dry::Struct
        transform_keys(&:to_sym)

        # Stock ticker symbol
        # @return [String] The ticker symbol
        attribute :ticker, Types::String

        # Market status for this ticker
        # @return [String, nil] Market status ("open", "closed", etc.)
        attribute? :market_status, Types::String | Types::Nil

        # Full market name
        # @return [String, nil] Market name ("stocks")
        attribute? :market, Types::String | Types::Nil

        # Last trade information
        # @return [Hash, nil] Last trade data
        attribute? :last_trade, Types::Hash | Types::Nil

        # Last quote information
        # @return [Hash, nil] Last quote data
        attribute? :last_quote, Types::Hash | Types::Nil

        # Daily bar information
        # @return [Hash, nil] Today's OHLC and volume data
        attribute? :daily_bar, Types::Hash | Types::Nil

        # Previous day's close information
        # @return [Hash, nil] Previous close data
        attribute? :prev_daily_bar, Types::Hash | Types::Nil

        # Session information
        # @return [Hash, nil] Session data
        attribute? :session, Types::Hash | Types::Nil

        # Updated timestamp
        # @return [String, Integer, nil] When snapshot was updated
        attribute? :updated, Types::String | Types::Integer | Types::Nil

        # Get last trade as structured object.
        # @return [LastTrade, nil] Last trade information
        def last_trade_info
          return nil unless last_trade
          LastTrade.new(last_trade)
        end

        # Get last quote as structured object.
        # @return [LastQuote, nil] Last quote information
        def last_quote_info
          return nil unless last_quote
          LastQuote.new(last_quote)
        end

        # Get daily bar as structured object.
        # @return [DailyBar, nil] Daily bar information
        def daily_bar_info
          return nil unless daily_bar
          DailyBar.new(daily_bar)
        end

        # Get previous daily bar as structured object.
        # @return [DailyBar, nil] Previous daily bar information
        def prev_daily_bar_info
          return nil unless prev_daily_bar
          DailyBar.new(prev_daily_bar)
        end

        # Get current price from last trade.
        # @return [Numeric, nil] Current stock price
        def current_price
          last_trade&.dig("p") || last_trade&.dig("price")
        end

        # Get current bid price.
        # @return [Numeric, nil] Current bid price
        def bid_price
          last_quote&.dig("P") || last_quote&.dig("bid_price")
        end

        # Get current ask price.
        # @return [Numeric, nil] Current ask price
        def ask_price
          last_quote&.dig("p") || last_quote&.dig("ask_price")
        end

        # Get today's volume.
        # @return [Integer, nil] Today's trading volume
        def volume
          daily_bar&.dig("v") || daily_bar&.dig("volume")
        end

        # Get today's change amount.
        # @return [Numeric, nil] Dollar change from previous close
        def change_amount
          daily_bar&.dig("c") || daily_bar&.dig("change")
        end

        # Get today's change percentage.
        # @return [Float, nil] Percentage change from previous close
        def change_percent
          daily_bar&.dig("cp") || daily_bar&.dig("change_percent")
        end

        # Get today's high.
        # @return [Numeric, nil] Today's high price
        def daily_high
          daily_bar&.dig("h") || daily_bar&.dig("high")
        end

        # Get today's low.
        # @return [Numeric, nil] Today's low price
        def daily_low
          daily_bar&.dig("l") || daily_bar&.dig("low")
        end

        # Get today's open.
        # @return [Numeric, nil] Today's opening price
        def daily_open
          daily_bar&.dig("o") || daily_bar&.dig("open")
        end

        # Get today's close.
        # @return [Numeric, nil] Today's closing price
        def daily_close
          daily_bar&.dig("c") || daily_bar&.dig("close")
        end

        # Get VWAP (Volume Weighted Average Price).
        # @return [Float, nil] Today's VWAP
        def vwap
          daily_bar&.dig("vw") || daily_bar&.dig("vwap")
        end

        # Check if stock is up for the day.
        # @return [Boolean] true if change is positive
        def up?
          return false unless change_amount
          change_amount > 0
        end

        # Check if stock is down for the day.
        # @return [Boolean] true if change is negative
        def down?
          return false unless change_amount
          change_amount < 0
        end

        # Check if stock is unchanged for the day.
        # @return [Boolean] true if change is zero
        def unchanged?
          return false unless change_amount
          change_amount == 0
        end

        # Check if market is open for this stock.
        # @return [Boolean] true if market status is open
        def market_open?
          market_status == "open"
        end

        # Calculate bid/ask spread.
        # @return [Numeric, nil] Bid/ask spread
        def spread
          return nil unless bid_price && ask_price
          (ask_price - bid_price).round(10)
        end

        # Calculate spread percentage.
        # @return [Float, nil] Spread as percentage of midpoint
        def spread_percentage
          return nil unless spread && bid_price && ask_price
          midpoint = (bid_price + ask_price) / 2.0
          return nil if midpoint <= 0
          (spread / midpoint * 100).round(4)
        end

        # Format change for display.
        # @return [String] Formatted change with direction indicator
        def formatted_change
          return "N/A" unless change_amount && change_percent

          if change_amount >= 0
            "+$#{change_amount.round(2)} (+#{change_percent.round(2)}%)"
          else
            "-$#{change_amount.abs.round(2)} (#{change_percent.round(2)}%)"
          end
        end

        # Create Snapshot object from API response data.
        #
        # @param json [Hash] Raw snapshot data from API
        # @return [Snapshot] Transformed snapshot object
        # @api private
        def self.from_api(json)
          attrs = Api::Transformers.stock_snapshot(json)
          new(attrs)
        end
      end

      # Nested struct for last trade within snapshot
      class LastTrade < Dry::Struct
        transform_keys(&:to_sym)

        attribute? :price, Types::PolymuxNumber | Types::Nil
        attribute? :size, Types::Integer | Types::Nil
        attribute? :exchange, Types::Integer | Types::Nil
        attribute? :timestamp, Types::String | Types::Integer | Types::Nil
        attribute? :conditions, Types::Array | Types::Nil
      end

      # Nested struct for last quote within snapshot
      class LastQuote < Dry::Struct
        transform_keys(&:to_sym)

        attribute? :bid_price, Types::PolymuxNumber | Types::Nil
        attribute? :ask_price, Types::PolymuxNumber | Types::Nil
        attribute? :bid_size, Types::Integer | Types::Nil
        attribute? :ask_size, Types::Integer | Types::Nil
        attribute? :bid_exchange, Types::Integer | Types::Nil
        attribute? :ask_exchange, Types::Integer | Types::Nil
        attribute? :timestamp, Types::String | Types::Integer | Types::Nil
      end

      # Nested struct for daily bar within snapshot
      class DailyBar < Dry::Struct
        transform_keys(&:to_sym)

        attribute? :open, Types::PolymuxNumber | Types::Nil
        attribute? :high, Types::PolymuxNumber | Types::Nil
        attribute? :low, Types::PolymuxNumber | Types::Nil
        attribute? :close, Types::PolymuxNumber | Types::Nil
        attribute? :volume, Types::Integer | Types::Nil
        attribute? :vwap, Types::PolymuxNumber | Types::Nil
        attribute? :change, Types::PolymuxNumber | Types::Nil
        attribute? :change_percent, Types::PolymuxNumber | Types::Nil
      end
    end
  end
end
