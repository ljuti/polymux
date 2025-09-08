# frozen_string_literal: true

require "dry/struct"
require_relative "../../types"

module Polymux
  module Api
    class TechnicalIndicators
      # Represents Exponential Moving Average (EMA) data with analysis methods.
      #
      # EMA gives more weight to recent prices, making it more responsive to
      # price changes than SMA. This makes it popular for short-term trading
      # signals and reactive trend analysis.
      #
      # @example Responsive trend analysis
      #   ema = client.technical_indicators.ema("AAPL", window: 12, timespan: "day")
      #
      #   if ema.trending_up?
      #     puts "12-day EMA uptrend - responsive to recent gains"
      #   end
      #
      #   # EMA reacts faster to price changes
      #   if ema.momentum_increasing?
      #     puts "Recent price momentum accelerating"
      #   end
      #
      # @example MACD component analysis
      #   ema_12 = client.technical_indicators.ema("AAPL", window: 12, timespan: "day")
      #   ema_26 = client.technical_indicators.ema("AAPL", window: 26, timespan: "day")
      #
      #   macd_line = ema_12.current_value - ema_26.current_value
      #   puts "MACD Line: #{macd_line}"
      class EMA < Dry::Struct
        # Individual EMA value point with timestamp
        class Value < Dry::Struct
          transform_keys(&:to_sym)

          # Timestamp of the EMA calculation
          # @return [String, Integer, Time, nil] When this EMA value was calculated
          attribute :timestamp, Types::String | Types::Integer | Types.Instance(Time) | Types::Nil

          # Exponential Moving Average value
          # @return [Float] The calculated EMA value
          attribute :value, Types::PolymuxNumber
        end

        transform_keys(&:to_sym)

        # Stock ticker symbol
        # @return [String] The ticker this EMA belongs to
        attribute :ticker, Types::String

        # EMA calculation window
        # @return [Integer] Number of periods used in calculation
        attribute :window, Types::Integer

        # Time period for each calculation
        # @return [String] Timespan (day, hour, minute, etc.)
        attribute :timespan, Types::String

        # Array of EMA values over time
        # @return [Array<Value>] Historical EMA values
        attribute :values, Types::Array.of(Value)

        # Get the most recent EMA value.
        # @return [Float, nil] Latest EMA value
        def current_value
          values.last&.value
        end

        # Get the oldest EMA value in the dataset.
        # @return [Float, nil] Earliest EMA value
        def first_value
          values.first&.value
        end

        # Check if EMA is trending upward.
        # Uses shorter lookback than SMA due to EMA's responsiveness.
        # @return [Boolean] true if trending up
        def trending_up?
          return false if values.length < 4
          current_value > values[-4].value
        end

        # Check if EMA is trending downward.
        # Uses shorter lookback than SMA due to EMA's responsiveness.
        # @return [Boolean] true if trending down
        def trending_down?
          return false if values.length < 4
          current_value < values[-4].value
        end

        # Check if EMA momentum is increasing (accelerating upward).
        # @return [Boolean] true if rate of change is increasing
        def momentum_increasing?
          return false if values.length < 6

          recent_change = current_value - values[-3].value
          previous_change = values[-3].value - values[-6].value

          recent_change > previous_change && recent_change > 0
        end

        # Check if EMA momentum is decreasing (decelerating).
        # @return [Boolean] true if rate of change is decreasing
        def momentum_decreasing?
          return false if values.length < 6

          recent_change = (current_value - values[-3].value).abs
          previous_change = (values[-3].value - values[-6].value).abs

          recent_change < previous_change
        end

        # Calculate the smoothing constant (alpha) used in EMA calculation.
        # @return [Float] Alpha value for this EMA
        def smoothing_constant
          2.0 / (window + 1)
        end

        # Calculate percentage change over specified periods.
        # @param periods [Integer] Number of periods to look back
        # @return [Float, nil] Percentage change
        def percent_change(periods = 3)
          return nil if values.length < periods + 1

          current = current_value
          previous = values[-periods - 1].value

          return nil if previous.zero?

          ((current - previous) / previous * 100).round(4)
        end

        # Check if EMA has crossed above another EMA.
        # @param other_ema [EMA] Another EMA to compare against
        # @return [Boolean] true if recently crossed above
        def crossed_above?(other_ema)
          return false if values.length < 2 || other_ema.values.length < 2

          # Current values
          current_self = current_value
          current_other = other_ema.current_value

          # Previous values
          previous_self = values[-2].value
          previous_other = other_ema.values[-2].value

          # Cross above: was below or equal, now above
          previous_self <= previous_other && current_self > current_other
        end

        # Check if EMA has crossed below another EMA.
        # @param other_ema [EMA] Another EMA to compare against
        # @return [Boolean] true if recently crossed below
        def crossed_below?(other_ema)
          return false if values.length < 2 || other_ema.values.length < 2

          # Current values
          current_self = current_value
          current_other = other_ema.current_value

          # Previous values
          previous_self = values[-2].value
          previous_other = other_ema.values[-2].value

          # Cross below: was above or equal, now below
          previous_self >= previous_other && current_self < current_other
        end

        # Calculate responsiveness compared to SMA of same period.
        # Higher values indicate more responsive to recent price changes.
        # @return [Float] Responsiveness ratio
        def responsiveness_ratio
          return 1.0 if values.length < window + 1

          # Calculate what SMA would be for comparison
          recent_values = values.last(window).map(&:value)
          sma_equivalent = recent_values.sum / recent_values.length

          return 1.0 if sma_equivalent.zero?

          (current_value / sma_equivalent).round(4)
        end

        # Check if EMA is converging with another EMA.
        # @param other_ema [EMA] Another EMA to compare against
        # @return [Boolean] true if EMAs are getting closer together
        def converging_with?(other_ema)
          return false if values.length < 3 || other_ema.values.length < 3

          current_diff = (current_value - other_ema.current_value).abs
          previous_diff = (values[-2].value - other_ema.values[-2].value).abs

          current_diff < previous_diff
        end

        # Check if EMA is diverging from another EMA.
        # @param other_ema [EMA] Another EMA to compare against
        # @return [Boolean] true if EMAs are getting further apart
        def diverging_from?(other_ema)
          return false if values.length < 3 || other_ema.values.length < 3

          current_diff = (current_value - other_ema.current_value).abs
          previous_diff = (values[-2].value - other_ema.values[-2].value).abs

          current_diff > previous_diff
        end

        # Get EMA value at specific timestamp.
        # @param timestamp [Integer, String] The timestamp to lookup
        # @return [Float, nil] EMA value at that time
        def value_at(timestamp)
          value_point = values.find { |v| v.timestamp == timestamp }
          value_point&.value
        end

        # Get the date range covered by this EMA data.
        # @return [Hash] Hash with :start and :end timestamps
        def date_range
          return {} if values.empty?

          {
            start: values.first.timestamp,
            end: values.last.timestamp
          }
        end

        # Calculate recent volatility based on EMA value changes.
        # @param periods [Integer] Number of periods for volatility calculation
        # @return [Float] Volatility measure
        def recent_volatility(periods = 10)
          return 0.0 if values.length < periods + 1

          recent_values = values.last(periods + 1).map(&:value)
          changes = recent_values.each_cons(2).map { |prev, curr| (curr - prev) / prev }

          mean_change = changes.sum / changes.length
          variance = changes.map { |change| (change - mean_change)**2 }.sum / changes.length

          (Math.sqrt(variance) * 100).round(4) # Return as percentage
        end

        # Check if EMA is showing strong directional bias.
        # @return [Symbol] :bullish, :bearish, or :neutral
        def directional_bias
          return :neutral if values.length < 5

          recent_trend = percent_change(3) || 0
          momentum_strength = if momentum_increasing?
            1
          else
            (momentum_decreasing? ? -1 : 0)
          end

          if recent_trend > 1.0 && momentum_strength >= 0
            :bullish
          elsif recent_trend < -1.0 && momentum_strength <= 0
            :bearish
          else
            :neutral
          end
        end

        # Calculate signal strength for trading decisions.
        # @return [Hash] Signal analysis with strength and direction
        def signal_analysis
          {
            direction: directional_bias,
            strength: signal_strength,
            momentum: momentum_status,
            trend_quality: trend_quality
          }
        end

        # Create EMA object from API response data.
        #
        # @param ticker [String] Stock ticker symbol
        # @param json [Hash] Raw API response
        # @return [EMA] Transformed EMA object
        # @api private
        def self.from_api(ticker, json)
          data = JSON.parse(json.is_a?(String) ? json : json.to_json)
          results = data["results"] || {}

          # Extract values and convert timestamps
          api_values = results["values"] || []
          ema_values = api_values.map do |value_data|
            timestamp = value_data["timestamp"]
            # Convert millisecond timestamp to Time object
            time_obj = timestamp.is_a?(Integer) ? Time.at(timestamp / 1000.0) : timestamp
            {
              timestamp: time_obj,
              value: value_data["value"].to_f
            }
          end

          # Determine window and timespan from request or use defaults
          window = 12 # Would be passed from the API call context
          timespan = "day" # Would be passed from the API call context

          new(
            ticker: ticker.upcase,
            window: window,
            timespan: timespan,
            values: ema_values
          )
        end

        private

        # Calculate signal strength based on trend and momentum.
        # @return [String] Signal strength classification
        def signal_strength
          trend_pct = percent_change(3) || 0
          momentum_factor = if momentum_increasing?
            1.2
          else
            (momentum_decreasing? ? 0.8 : 1.0)
          end

          strength_score = trend_pct.abs * momentum_factor

          case strength_score
          when 0..0.5 then "weak"
          when 0.5..1.5 then "moderate"
          when 1.5..3.0 then "strong"
          else "very_strong"
          end
        end

        # Determine current momentum status.
        # @return [String] Momentum classification
        def momentum_status
          if momentum_increasing?
            "accelerating"
          elsif momentum_decreasing?
            "decelerating"
          else
            "stable"
          end
        end

        # Assess trend quality based on consistency.
        # @return [String] Trend quality assessment
        def trend_quality
          return "insufficient_data" if values.length < 8

          # Look at last 6 values to assess trend consistency
          recent_values = values.last(6).map(&:value)
          changes = recent_values.each_cons(2).map { |prev, curr| (curr > prev) ? 1 : -1 }

          consistency = changes.sum.abs / changes.length.to_f

          case consistency
          when 0.8..1.0 then "strong"
          when 0.5..0.8 then "moderate"
          else "choppy"
          end
        end
      end
    end
  end
end
