require "dry/struct"
require "polymux/api/transformers"

module Polymux
  module Api
    class Stocks
      # Represents a daily open/close summary for a stock.
      #
      # Contains official daily summary data including opening and closing
      # prices, along with after-hours trading information. This provides
      # the canonical daily price points used for historical analysis.
      #
      # @example Daily price analysis
      #   summary = client.stocks.daily_summary("AAPL", "2024-08-15")
      #
      #   puts "Date: #{summary.formatted_date}"
      #   puts "Open: $#{summary.open}"
      #   puts "Close: $#{summary.close}"
      #   puts "After Hours: $#{summary.after_hours_close}"
      #   puts "Change: #{summary.formatted_change}"
      class DailySummary < Dry::Struct
        transform_keys(&:to_sym)

        # Stock ticker symbol
        # @return [String, nil] The ticker symbol
        attribute? :symbol, Types::String | Types::Nil

        # Trading date
        # @return [String, nil] Date in YYYY-MM-DD format
        attribute? :from, Types::String | Types::Nil

        # Opening price
        # @return [Integer, Float, nil] Opening price
        attribute? :open, Types::PolymuxNumber | Types::Nil

        # Closing price
        # @return [Integer, Float, nil] Closing price
        attribute? :close, Types::PolymuxNumber | Types::Nil

        # After hours closing price
        # @return [Integer, Float, nil] After hours close
        attribute? :after_hours_close, Types::PolymuxNumber | Types::Nil

        # Pre-market opening price
        # @return [Integer, Float, nil] Pre-market open
        attribute? :pre_market_open, Types::PolymuxNumber | Types::Nil

        # Status of the response
        # @return [String, nil] Response status
        attribute? :status, Types::String | Types::Nil

        # Whether data has been adjusted
        # @return [Boolean, nil] Adjustment status
        attribute? :adjusted, Types::Bool | Types::Nil

        # Query count (API usage tracking)
        # @return [Integer, nil] Number of queries used
        attribute? :query_count, Types::Integer | Types::Nil

        # Result count
        # @return [Integer, nil] Number of results
        attribute? :result_count, Types::Integer | Types::Nil

        # Calculate intraday change (close - open).
        # @return [Numeric, nil] Dollar change from open to close
        def intraday_change
          return nil unless open && close
          close - open
        end

        # Calculate intraday change percentage.
        # @return [Float, nil] Percentage change from open to close
        def intraday_change_percent
          return nil unless intraday_change && open && open > 0
          (intraday_change / open * 100).round(4)
        end

        # Calculate after-hours change (after_hours_close - close).
        # @return [Numeric, nil] Dollar change in after-hours
        def after_hours_change
          return nil unless close && after_hours_close
          after_hours_close - close
        end

        # Calculate after-hours change percentage.
        # @return [Float, nil] Percentage change in after-hours
        def after_hours_change_percent
          return nil unless after_hours_change && close && close > 0
          (after_hours_change / close * 100).round(4)
        end

        # Calculate pre-market change if available.
        # Note: This assumes pre_market_open is compared to previous close,
        # but without previous close data, this returns nil.
        # @return [Numeric, nil] Pre-market change (requires additional context)
        def pre_market_change
          # Would need previous day's close to calculate meaningful pre-market change
          nil
        end

        # Check if the stock was up for the day.
        # @return [Boolean] true if close > open
        def up_day?
          return false unless intraday_change
          intraday_change > 0
        end

        # Check if the stock was down for the day.
        # @return [Boolean] true if close < open
        def down_day?
          return false unless intraday_change
          intraday_change < 0
        end

        # Check if the stock was flat for the day.
        # @return [Boolean] true if close == open
        def flat_day?
          return false unless intraday_change
          intraday_change == 0
        end

        # Check if after-hours trading was up.
        # @return [Boolean] true if after_hours_close > close
        def after_hours_up?
          return false unless after_hours_change
          after_hours_change > 0
        end

        # Check if after-hours trading was down.
        # @return [Boolean] true if after_hours_close < close
        def after_hours_down?
          return false unless after_hours_change
          after_hours_change < 0
        end

        # Get the effective closing price (after-hours if available, else regular close).
        # @return [Numeric, nil] Most recent closing price
        def effective_close
          after_hours_close || close
        end

        # Format the date for display.
        # @return [String] Human-readable date
        def formatted_date
          return "N/A" unless from

          begin
            Date.parse(from).strftime("%B %d, %Y")
          rescue
            from.to_s
          end
        end

        # Format intraday change for display.
        # @return [String] Formatted change with direction indicator
        def formatted_change
          return "N/A" unless intraday_change && intraday_change_percent

          sign = (intraday_change >= 0) ? "+" : ""
          "#{sign}$#{intraday_change.round(2)} (#{sign}#{intraday_change_percent.round(2)}%)"
        end

        # Format after-hours change for display.
        # @return [String] Formatted after-hours change
        def formatted_after_hours_change
          return "N/A" unless after_hours_change && after_hours_change_percent

          sign = (after_hours_change >= 0) ? "+" : ""
          "#{sign}$#{after_hours_change.round(2)} (#{sign}#{after_hours_change_percent.round(2)}%)"
        end

        # Get summary as formatted string.
        # @return [String] Complete daily summary
        def summary_string
          parts = []
          parts << "#{symbol} #{formatted_date}" if symbol && from
          parts << "Open: $#{open}" if open
          parts << "Close: $#{close}" if close
          parts << "Change: #{formatted_change}" if intraday_change
          parts << "After Hours: $#{after_hours_close}" if after_hours_close
          parts << "AH Change: #{formatted_after_hours_change}" if after_hours_change

          parts.join(" | ")
        end

        # Create DailySummary object from API response data.
        #
        # @param json [Hash] Raw daily summary data from API
        # @return [DailySummary] Transformed daily summary object
        # @api private
        def self.from_api(json)
          attrs = Api::Transformers.stock_daily_summary(json)
          new(attrs)
        end
      end
    end
  end
end
