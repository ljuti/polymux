# frozen_string_literal: true

require "dry/struct"
require_relative "../../types"

module Polymux
  module Api
    class TechnicalIndicators
      # Represents Relative Strength Index (RSI) data with overbought/oversold analysis.
      #
      # RSI is a momentum oscillator that ranges from 0 to 100, measuring the
      # speed and change of price movements. It's commonly used to identify
      # overbought (>70) and oversold (<30) conditions for entry/exit timing.
      #
      # @example Basic RSI analysis
      #   rsi = client.technical_indicators.rsi("AAPL", window: 14, timespan: "day")
      #
      #   if rsi.oversold?
      #     puts "Potential buy opportunity - RSI: #{rsi.current_value}"
      #   elsif rsi.overbought?
      #     puts "Potential sell opportunity - RSI: #{rsi.current_value}"
      #   end
      #
      # @example Advanced momentum analysis
      #   rsi = client.technical_indicators.rsi("AAPL", window: 14, timespan: "day")
      #
      #   if rsi.recovering_from_oversold?
      #     puts "Momentum turning positive from oversold levels"
      #   elsif rsi.failing_from_overbought?
      #     puts "Momentum turning negative from overbought levels"
      #   end
      #
      #   # Custom thresholds for different market conditions
      #   if rsi.extremely_oversold?
      #     puts "Extreme oversold - high probability reversal"
      #   end
      class RSI < Dry::Struct
        # Individual RSI value point with timestamp
        class Value < Dry::Struct
          transform_keys(&:to_sym)

          # Timestamp of the RSI calculation
          # @return [String, Integer, Time, nil] When this RSI value was calculated
          attribute :timestamp, Types::String | Types::Integer | Types.Instance(Time) | Types::Nil

          # Relative Strength Index value (0-100)
          # @return [Float] The calculated RSI value
          attribute :value, Types::PolymuxNumber
        end

        transform_keys(&:to_sym)

        # Stock ticker symbol
        # @return [String] The ticker this RSI belongs to
        attribute :ticker, Types::String

        # RSI calculation window
        # @return [Integer] Number of periods used in calculation (typically 14)
        attribute :window, Types::Integer

        # Time period for each calculation
        # @return [String] Timespan (day, hour, minute, etc.)
        attribute :timespan, Types::String

        # Array of RSI values over time
        # @return [Array<Value>] Historical RSI values
        attribute :values, Types::Array.of(Value)

        # Standard RSI thresholds
        OVERSOLD_THRESHOLD = 30.0
        OVERBOUGHT_THRESHOLD = 70.0
        EXTREME_OVERSOLD_THRESHOLD = 20.0
        EXTREME_OVERBOUGHT_THRESHOLD = 80.0
        NEUTRAL_LOWER = 40.0
        NEUTRAL_UPPER = 60.0

        # Get the most recent RSI value.
        # @return [Float, nil] Latest RSI value (0-100)
        def current_value
          values.last&.value
        end

        # Get the oldest RSI value in the dataset.
        # @return [Float, nil] Earliest RSI value
        def first_value
          values.first&.value
        end

        # Check if RSI indicates oversold conditions.
        # @param threshold [Float] Custom oversold threshold (default: 30)
        # @return [Boolean] true if RSI is below oversold threshold
        def oversold?(threshold = OVERSOLD_THRESHOLD)
          return false unless current_value
          current_value < threshold
        end

        # Check if RSI indicates overbought conditions.
        # @param threshold [Float] Custom overbought threshold (default: 70)
        # @return [Boolean] true if RSI is above overbought threshold
        def overbought?(threshold = OVERBOUGHT_THRESHOLD)
          return false unless current_value
          current_value > threshold
        end

        # Check if RSI is extremely oversold (high reversal probability).
        # @return [Boolean] true if RSI is below 20
        def extremely_oversold?
          oversold?(EXTREME_OVERSOLD_THRESHOLD)
        end

        # Check if RSI is extremely overbought (high reversal probability).
        # @return [Boolean] true if RSI is above 80
        def extremely_overbought?
          overbought?(EXTREME_OVERBOUGHT_THRESHOLD)
        end

        # Check if RSI is in neutral range.
        # @return [Boolean] true if RSI is between 40-60
        def neutral?
          return false unless current_value
          current_value.between?(NEUTRAL_LOWER, NEUTRAL_UPPER)
        end

        # Check if RSI is recovering from oversold levels.
        # @return [Boolean] true if recently moved from oversold to neutral+
        def recovering_from_oversold?
          return false if values.length < 3

          current = current_value
          previous = values[-2].value
          older = values[-3].value

          # Was oversold, now improving
          older < OVERSOLD_THRESHOLD &&
            previous < OVERSOLD_THRESHOLD &&
            current > previous &&
            current >= OVERSOLD_THRESHOLD
        end

        # Check if RSI is failing from overbought levels.
        # @return [Boolean] true if recently moved from overbought to neutral-
        def failing_from_overbought?
          return false if values.length < 3

          current = current_value
          previous = values[-2].value
          older = values[-3].value

          # Was overbought, now declining
          older > OVERBOUGHT_THRESHOLD &&
            previous > OVERBOUGHT_THRESHOLD &&
            current < previous &&
            current <= OVERBOUGHT_THRESHOLD
        end

        # Get RSI momentum direction.
        # @return [Symbol] :rising, :falling, or :sideways
        def momentum_direction
          return :sideways if values.length < 3

          recent_change = current_value - values[-3].value

          if recent_change > 2.0
            :rising
          elsif recent_change < -2.0
            :falling
          else
            :sideways
          end
        end

        # Calculate RSI momentum strength (rate of change).
        # @param periods [Integer] Number of periods for momentum calculation
        # @return [Float] Rate of RSI change per period
        def momentum_strength(periods = 3)
          return 0.0 if values.length < periods + 1

          current = current_value
          previous = values[-periods - 1].value

          (current - previous) / periods
        end

        # Check if RSI shows bullish divergence with price.
        # This would need price data to be passed in for full analysis.
        # @param price_highs [Array] Array of recent price high points
        # @return [Boolean] true if RSI highs are rising while price highs may be falling
        def bullish_divergence?(price_highs = [])
          return false if values.length < 6 || price_highs.length < 2

          # Find RSI highs in recent data
          rsi_highs = find_local_highs
          return false if rsi_highs.length < 2

          # Compare recent RSI highs - should be rising for bullish divergence
          latest_rsi_high = rsi_highs.last[:value]
          previous_rsi_high = rsi_highs[-2][:value]

          latest_rsi_high > previous_rsi_high
        end

        # Check if RSI shows bearish divergence with price.
        # @param price_highs [Array] Array of recent price high points
        # @return [Boolean] true if RSI highs are falling while price highs may be rising
        def bearish_divergence?(price_highs = [])
          return false if values.length < 6 || price_highs.length < 2

          # Find RSI highs in recent data
          rsi_highs = find_local_highs
          return false if rsi_highs.length < 2

          # Compare recent RSI highs - should be falling for bearish divergence
          latest_rsi_high = rsi_highs.last[:value]
          previous_rsi_high = rsi_highs[-2][:value]

          latest_rsi_high < previous_rsi_high
        end

        # Get RSI signal classification.
        # @return [String] Signal classification
        def signal_classification
          return "insufficient_data" unless current_value

          case current_value
          when 0..EXTREME_OVERSOLD_THRESHOLD
            "extremely_oversold"
          when EXTREME_OVERSOLD_THRESHOLD..OVERSOLD_THRESHOLD
            "oversold"
          when OVERSOLD_THRESHOLD..NEUTRAL_LOWER
            "weak"
          when NEUTRAL_LOWER..NEUTRAL_UPPER
            "neutral"
          when NEUTRAL_UPPER..OVERBOUGHT_THRESHOLD
            "strong"
          when OVERBOUGHT_THRESHOLD..EXTREME_OVERBOUGHT_THRESHOLD
            "overbought"
          else
            "extremely_overbought"
          end
        end

        # Generate trading signal based on RSI conditions.
        # @return [Hash] Signal with type, strength, and confidence
        def trading_signal
          return {type: :none, strength: :none, confidence: :low} unless current_value

          signal = {
            type: :hold,
            strength: :weak,
            confidence: :medium,
            reason: signal_classification
          }

          case signal_classification
          when "extremely_oversold"
            signal.merge!(type: :buy, strength: :strong, confidence: :high)
          when "oversold"
            signal.merge!(type: :buy, strength: :moderate, confidence: :medium)
          when "extremely_overbought"
            signal.merge!(type: :sell, strength: :strong, confidence: :high)
          when "overbought"
            signal.merge!(type: :sell, strength: :moderate, confidence: :medium)
          end

          # Adjust based on momentum
          case momentum_direction
          when :rising
            signal[:confidence] = :high if signal[:type] == :buy
          when :falling
            signal[:confidence] = :high if signal[:type] == :sell
          end

          signal
        end

        # Get RSI value at specific timestamp.
        # @param timestamp [Integer, String] The timestamp to lookup
        # @return [Float, nil] RSI value at that time
        def value_at(timestamp)
          value_point = values.find { |v| v.timestamp == timestamp }
          value_point&.value
        end

        # Get the date range covered by this RSI data.
        # @return [Hash] Hash with :start and :end timestamps
        def date_range
          return {} if values.empty?

          {
            start: values.first.timestamp,
            end: values.last.timestamp
          }
        end

        # Calculate average RSI over the entire dataset.
        # @return [Float] Mean RSI value
        def average_value
          return 0.0 if values.empty?

          rsi_values = values.map(&:value)
          rsi_values.sum / rsi_values.length
        end

        # Count periods spent in different RSI ranges.
        # @return [Hash] Count of periods in each range
        def range_distribution
          return {} if values.empty?

          distribution = {
            extremely_oversold: 0,
            oversold: 0,
            weak: 0,
            neutral: 0,
            strong: 0,
            overbought: 0,
            extremely_overbought: 0
          }

          values.each do |value|
            case value.value
            when 0..EXTREME_OVERSOLD_THRESHOLD
              distribution[:extremely_oversold] += 1
            when EXTREME_OVERSOLD_THRESHOLD..OVERSOLD_THRESHOLD
              distribution[:oversold] += 1
            when OVERSOLD_THRESHOLD..NEUTRAL_LOWER
              distribution[:weak] += 1
            when NEUTRAL_LOWER..NEUTRAL_UPPER
              distribution[:neutral] += 1
            when NEUTRAL_UPPER..OVERBOUGHT_THRESHOLD
              distribution[:strong] += 1
            when OVERBOUGHT_THRESHOLD..EXTREME_OVERBOUGHT_THRESHOLD
              distribution[:overbought] += 1
            else
              distribution[:extremely_overbought] += 1
            end
          end

          distribution
        end

        # Create RSI object from API response data.
        #
        # @param ticker [String] Stock ticker symbol
        # @param json [Hash] Raw API response
        # @return [RSI] Transformed RSI object
        # @api private
        def self.from_api(ticker, json)
          data = JSON.parse(json.is_a?(String) ? json : json.to_json)
          results = data["results"] || {}

          # Extract values and convert timestamps
          api_values = results["values"] || []
          rsi_values = api_values.map do |value_data|
            timestamp = value_data["timestamp"]
            # Convert millisecond timestamp to Time object
            time_obj = timestamp.is_a?(Integer) ? Time.at(timestamp / 1000.0) : timestamp
            {
              timestamp: time_obj,
              value: value_data["value"].to_f
            }
          end

          # Determine window and timespan from request or use defaults
          window = 14 # Would be passed from the API call context
          timespan = "day" # Would be passed from the API call context

          new(
            ticker: ticker.upcase,
            window: window,
            timespan: timespan,
            values: rsi_values
          )
        end

        private

        # Find local highs in RSI data for divergence analysis.
        # @return [Array<Hash>] Array of local highs with index and value
        def find_local_highs
          return [] if values.length < 5

          highs = []

          # Look for peaks (value higher than neighbors)
          (2...values.length - 2).each do |i|
            current = values[i].value
            before = values[i - 1].value
            after = values[i + 1].value

            if current > before && current > after && current > 50 # Only consider meaningful highs
              highs << {
                index: i,
                value: current,
                timestamp: values[i].timestamp
              }
            end
          end

          highs
        end

        # Find local lows in RSI data for divergence analysis.
        # @return [Array<Hash>] Array of local lows with index and value
        def find_local_lows
          return [] if values.length < 5

          lows = []

          # Look for troughs (value lower than neighbors)
          (2...values.length - 2).each do |i|
            current = values[i].value
            before = values[i - 1].value
            after = values[i + 1].value

            if current < before && current < after && current < 50 # Only consider meaningful lows
              lows << {
                index: i,
                value: current,
                timestamp: values[i].timestamp
              }
            end
          end

          lows
        end
      end
    end
  end
end
