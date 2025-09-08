# frozen_string_literal: true

require "dry/struct"
require_relative "../../types"

module Polymux
  module Api
    class TechnicalIndicators
      # Represents Simple Moving Average (SMA) data with analysis methods.
      #
      # SMA smooths price data by calculating the average price over a specified
      # number of periods. It's the most basic trend-following indicator and forms
      # the foundation for many trading strategies.
      #
      # @example Trend analysis
      #   sma = client.technical_indicators.sma("AAPL", window: 20, timespan: "day")
      #
      #   if sma.trending_up?
      #     puts "20-day uptrend confirmed"
      #   end
      #
      #   current_price = 175.50
      #   if current_price > sma.current_value
      #     puts "Price above 20-day SMA - bullish"
      #   end
      #
      # @example Multi-timeframe analysis
      #   sma_20 = client.technical_indicators.sma("AAPL", window: 20, timespan: "day")
      #   sma_50 = client.technical_indicators.sma("AAPL", window: 50, timespan: "day")
      #
      #   if sma_20.current_value > sma_50.current_value
      #     puts "Golden cross formation - bullish signal"
      #   end
      class SMA < Dry::Struct
        # Individual SMA value point with timestamp
        class Value < Dry::Struct
          transform_keys(&:to_sym)

          # Timestamp of the SMA calculation
          # @return [String, Integer, Time, nil] When this SMA value was calculated
          attribute :timestamp, Types::String | Types::Integer | Types.Instance(Time) | Types::Nil

          # Simple Moving Average value
          # @return [Float] The calculated SMA value
          attribute :value, Types::PolymuxNumber
        end

        transform_keys(&:to_sym)

        # Stock ticker symbol
        # @return [String] The ticker this SMA belongs to
        attribute :ticker, Types::String

        # SMA calculation window
        # @return [Integer] Number of periods used in calculation
        attribute :window, Types::Integer

        # Time period for each calculation
        # @return [String] Timespan (day, hour, minute, etc.)
        attribute :timespan, Types::String

        # Array of SMA values over time
        # @return [Array<Value>] Historical SMA values
        attribute :values, Types::Array.of(Value)

        # Get the most recent SMA value.
        # @return [Float, nil] Latest SMA value
        def current_value
          values.last&.value
        end

        # Get the oldest SMA value in the dataset.
        # @return [Float, nil] Earliest SMA value
        def first_value
          values.first&.value
        end

        # Check if SMA is trending upward.
        # Compares current value to value from 5 periods ago.
        # @return [Boolean] true if trending up
        def trending_up?
          return false if values.length < 6
          current_value > values[-6].value
        end

        # Check if SMA is trending downward.
        # Compares current value to value from 5 periods ago.
        # @return [Boolean] true if trending down
        def trending_down?
          return false if values.length < 6
          current_value < values[-6].value
        end

        # Check if SMA is in a sideways trend.
        # @return [Boolean] true if not trending up or down
        def sideways?
          !trending_up? && !trending_down?
        end

        # Calculate the slope of the SMA trend.
        # @param periods [Integer] Number of periods to look back for slope calculation
        # @return [Float, nil] Slope of the trend line (positive = upward, negative = downward)
        def slope(periods = 5)
          return nil if values.length < periods + 1

          recent_values = values.last(periods + 1).map(&:value)

          # Simple linear regression slope calculation
          x_values = (0...recent_values.length).to_a
          n = recent_values.length

          sum_x = x_values.sum
          sum_y = recent_values.sum
          sum_xy = x_values.zip(recent_values).map { |x, y| x * y }.sum
          sum_x_squared = x_values.map { |x| x**2 }.sum

          slope = (n * sum_xy - sum_x * sum_y) / (n * sum_x_squared - sum_x**2)
          slope.round(4)
        end

        # Calculate percentage change over specified periods.
        # @param periods [Integer] Number of periods to look back
        # @return [Float, nil] Percentage change
        def percent_change(periods = 5)
          return nil if values.length < periods + 1

          current = current_value
          previous = values[-periods - 1].value

          return nil if previous.zero?

          ((current - previous) / previous * 100).round(4)
        end

        # Check if SMA has crossed above another SMA (golden cross).
        # @param other_sma [SMA] Another SMA to compare against
        # @return [Boolean] true if recently crossed above
        def crossed_above?(other_sma)
          return false if values.length < 2 || other_sma.values.length < 2

          # Current values
          current_self = current_value
          current_other = other_sma.current_value

          # Previous values
          previous_self = values[-2].value
          previous_other = other_sma.values[-2].value

          # Cross above: was below, now above
          previous_self <= previous_other && current_self > current_other
        end

        # Check if SMA has crossed below another SMA (death cross).
        # @param other_sma [SMA] Another SMA to compare against
        # @return [Boolean] true if recently crossed below
        def crossed_below?(other_sma)
          return false if values.length < 2 || other_sma.values.length < 2

          # Current values
          current_self = current_value
          current_other = other_sma.current_value

          # Previous values
          previous_self = values[-2].value
          previous_other = other_sma.values[-2].value

          # Cross below: was above, now below
          previous_self >= previous_other && current_self < current_other
        end

        # Get SMA value at specific timestamp.
        # @param timestamp [Integer, String] The timestamp to lookup
        # @return [Float, nil] SMA value at that time
        def value_at(timestamp)
          value_point = values.find { |v| v.timestamp == timestamp }
          value_point&.value
        end

        # Get the date range covered by this SMA data.
        # @return [Hash] Hash with :start and :end timestamps
        def date_range
          return {} if values.empty?

          {
            start: values.first.timestamp,
            end: values.last.timestamp
          }
        end

        # Calculate volatility of SMA values.
        # @return [Float] Standard deviation of SMA values
        def volatility
          return 0.0 if values.length < 2

          sma_values = values.map(&:value)
          mean = sma_values.sum / sma_values.length

          variance = sma_values.map { |v| (v - mean)**2 }.sum / sma_values.length
          Math.sqrt(variance).round(4)
        end

        # Check if SMA is accelerating upward.
        # @return [Boolean] true if rate of change is increasing
        def accelerating_up?
          return false if values.length < 10

          recent_slope = slope(3)
          previous_slope = slope_at_index(-4, 3)

          return false unless recent_slope && previous_slope

          recent_slope > previous_slope && recent_slope > 0
        end

        # Check if SMA is decelerating (slowing down).
        # @return [Boolean] true if rate of change is decreasing
        def decelerating?
          return false if values.length < 10

          recent_slope = slope(3)
          previous_slope = slope_at_index(-4, 3)

          return false unless recent_slope && previous_slope

          recent_slope.abs < previous_slope.abs
        end

        # Create SMA object from API response data.
        #
        # @param ticker [String] Stock ticker symbol
        # @param json [Hash] Raw API response
        # @return [SMA] Transformed SMA object
        # @api private
        def self.from_api(ticker, json)
          data = JSON.parse(json.is_a?(String) ? json : json.to_json)
          results = data["results"] || {}

          # Extract values and convert timestamps
          api_values = results["values"] || []
          sma_values = api_values.map do |value_data|
            timestamp = value_data["timestamp"]
            # Convert millisecond timestamp to Time object
            time_obj = timestamp.is_a?(Integer) ? Time.at(timestamp / 1000.0) : timestamp
            {
              timestamp: time_obj,
              value: value_data["value"].to_f
            }
          end

          # Determine window and timespan from request or use defaults
          window = 20 # Would be passed from the API call context
          timespan = "day" # Would be passed from the API call context

          new(
            ticker: ticker.upcase,
            window: window,
            timespan: timespan,
            values: sma_values
          )
        end

        private

        # Calculate slope at a specific index position.
        # @param index [Integer] Position in values array (negative for from end)
        # @param periods [Integer] Number of periods for slope calculation
        # @return [Float, nil] Slope at that position
        def slope_at_index(index, periods)
          return nil if values.length < (-index + periods + 1)

          end_index = (index < 0) ? values.length + index : index
          start_index = end_index - periods

          return nil if start_index < 0

          subset_values = values[start_index..end_index].map(&:value)
          x_values = (0...subset_values.length).to_a
          n = subset_values.length

          sum_x = x_values.sum
          sum_y = subset_values.sum
          sum_xy = x_values.zip(subset_values).map { |x, y| x * y }.sum
          sum_x_squared = x_values.map { |x| x**2 }.sum

          slope = (n * sum_xy - sum_x * sum_y) / (n * sum_x_squared - sum_x**2)
          slope.round(4)
        end
      end
    end
  end
end
