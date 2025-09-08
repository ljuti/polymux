# frozen_string_literal: true

require "dry/struct"
require_relative "../../types"

module Polymux
  module Api
    class TechnicalIndicators
      # Represents MACD (Moving Average Convergence Divergence) data with crossover analysis.
      #
      # MACD is a momentum and trend-following indicator that shows the relationship
      # between two moving averages. It consists of three components:
      # - MACD Line: Difference between fast EMA (12) and slow EMA (26)
      # - Signal Line: EMA of MACD line (typically 9 periods)
      # - Histogram: Difference between MACD line and signal line
      #
      # @example Basic MACD analysis
      #   macd = client.technical_indicators.macd("AAPL",
      #     short_window: 12, long_window: 26, signal_window: 9, timespan: "day"
      #   )
      #
      #   if macd.bullish_crossover?
      #     puts "MACD bullish crossover - potential uptrend"
      #   elsif macd.bearish_crossover?
      #     puts "MACD bearish crossover - potential downtrend"
      #   end
      #
      # @example Advanced momentum analysis
      #   macd = client.technical_indicators.macd("AAPL",
      #     short_window: 12, long_window: 26, signal_window: 9, timespan: "day"
      #   )
      #
      #   if macd.histogram_increasing?
      #     puts "Momentum strengthening - histogram expanding"
      #   end
      #
      #   if macd.above_zero? && macd.signal_strength == "strong"
      #     puts "Strong bullish momentum confirmed"
      #   end
      class MACD < Dry::Struct
        # Individual MACD value point with all three components
        class Value < Dry::Struct
          transform_keys(&:to_sym)

          # Timestamp of the MACD calculation
          # @return [String, Integer, Time, nil] When this MACD value was calculated
          attribute :timestamp, Types::String | Types::Integer | Types.Instance(Time) | Types::Nil

          # MACD line value (fast EMA - slow EMA)
          # @return [Float] The MACD line value
          attribute :value, Types::PolymuxNumber

          # Signal line value (EMA of MACD line)
          # @return [Float] The signal line value
          attribute :signal, Types::PolymuxNumber

          # Histogram value (MACD line - signal line)
          # @return [Float] The histogram value
          attribute :histogram, Types::PolymuxNumber
        end

        transform_keys(&:to_sym)

        # Stock ticker symbol
        # @return [String] The ticker this MACD belongs to
        attribute :ticker, Types::String

        # Fast EMA period (typically 12)
        # @return [Integer] Short window period
        attribute :short_window, Types::Integer

        # Slow EMA period (typically 26)
        # @return [Integer] Long window period
        attribute :long_window, Types::Integer

        # Signal line EMA period (typically 9)
        # @return [Integer] Signal window period
        attribute :signal_window, Types::Integer

        # Time period for each calculation
        # @return [String] Timespan (day, hour, minute, etc.)
        attribute :timespan, Types::String

        # Array of MACD values over time
        # @return [Array<Value>] Historical MACD values
        attribute :values, Types::Array.of(Value)

        # Get the most recent MACD values.
        # @return [Value, nil] Latest MACD value with all components
        def current
          values.last
        end

        # Get the most recent MACD line value.
        # @return [Float, nil] Latest MACD line value
        def current_value
          current&.value
        end

        # Get the most recent signal line value.
        # @return [Float, nil] Latest signal line value
        def current_signal
          current&.signal
        end

        # Get the most recent histogram value.
        # @return [Float, nil] Latest histogram value
        def current_histogram
          current&.histogram
        end

        # Check if MACD recently had a bullish crossover.
        # @return [Boolean] true if MACD line crossed above signal line
        def bullish_crossover?
          return false if values.length < 2

          current_macd = current_value
          current_sig = current_signal
          previous_macd = values[-2].value
          previous_sig = values[-2].signal

          # Cross above: was below or equal, now above
          previous_macd <= previous_sig && current_macd > current_sig
        end

        # Check if MACD recently had a bearish crossover.
        # @return [Boolean] true if MACD line crossed below signal line
        def bearish_crossover?
          return false if values.length < 2

          current_macd = current_value
          current_sig = current_signal
          previous_macd = values[-2].value
          previous_sig = values[-2].signal

          # Cross below: was above or equal, now below
          previous_macd >= previous_sig && current_macd < current_sig
        end

        # Check if MACD is currently above zero line.
        # @return [Boolean] true if MACD line is positive
        def above_zero?
          return false unless current_value
          current_value > 0
        end

        # Check if MACD is currently below zero line.
        # @return [Boolean] true if MACD line is negative
        def below_zero?
          return false unless current_value
          current_value < 0
        end

        # Check if histogram is increasing (momentum strengthening).
        # @return [Boolean] true if histogram is expanding
        def histogram_increasing?
          return false if values.length < 3

          current_hist = current_histogram
          previous_hist = values[-2].histogram
          older_hist = values[-3].histogram

          # Histogram should be consistently increasing
          current_hist > previous_hist && previous_hist > older_hist
        end

        # Check if histogram is decreasing (momentum weakening).
        # @return [Boolean] true if histogram is contracting
        def histogram_decreasing?
          return false if values.length < 3

          current_hist = current_histogram
          previous_hist = values[-2].histogram
          older_hist = values[-3].histogram

          # Histogram should be consistently decreasing
          current_hist < previous_hist && previous_hist < older_hist
        end

        # Get the current trend direction based on MACD position.
        # @return [Symbol] :bullish, :bearish, or :neutral
        def trend_direction
          return :neutral unless current_value && current_signal

          if above_zero? && current_value > current_signal
            :bullish
          elsif below_zero? && current_value < current_signal
            :bearish
          else
            :neutral
          end
        end

        # Calculate momentum strength based on histogram and crossovers.
        # @return [String] Momentum strength classification
        def signal_strength
          return "none" unless current_histogram

          histogram_abs = current_histogram.abs
          has_crossover = bullish_crossover? || bearish_crossover?

          strength_score = histogram_abs
          strength_score *= 2 if has_crossover # Crossovers are significant
          strength_score *= 1.5 if histogram_increasing? # Increasing momentum

          case strength_score
          when 0..0.3
            "weak"
          when 0.3..0.8
            "moderate"
          when 0.8..1.5
            "strong"
          else
            "very_strong"
          end
        end

        # Check if MACD shows convergence (lines getting closer).
        # @return [Boolean] true if MACD and signal lines are converging
        def converging?
          return false if values.length < 3

          current_diff = (current_value - current_signal).abs
          previous_diff = (values[-2].value - values[-2].signal).abs
          older_diff = (values[-3].value - values[-3].signal).abs

          current_diff < previous_diff && previous_diff < older_diff
        end

        # Check if MACD shows divergence (lines getting further apart).
        # @return [Boolean] true if MACD and signal lines are diverging
        def diverging?
          return false if values.length < 3

          current_diff = (current_value - current_signal).abs
          previous_diff = (values[-2].value - values[-2].signal).abs
          older_diff = (values[-3].value - values[-3].signal).abs

          current_diff > previous_diff && previous_diff > older_diff
        end

        # Generate comprehensive MACD trading signal.
        # @return [Hash] Signal analysis with type, strength, and confidence
        def trading_signal
          return {type: :none, strength: :none, confidence: :low} unless current

          signal = {
            type: :hold,
            strength: signal_strength.to_sym,
            confidence: :medium,
            components: {
              macd_line: current_value,
              signal_line: current_signal,
              histogram: current_histogram
            }
          }

          # Determine signal type based on crossovers
          if bullish_crossover?
            signal.merge!(
              type: :buy,
              confidence: :high,
              reason: "bullish_crossover"
            )
          elsif bearish_crossover?
            signal.merge!(
              type: :sell,
              confidence: :high,
              reason: "bearish_crossover"
            )
          else
            # Determine based on current position and momentum
            case trend_direction
            when :bullish
              if histogram_increasing?
                signal.merge!(type: :buy, reason: "bullish_momentum_increasing")
              else
                signal.merge!(type: :hold, reason: "bullish_but_weakening")
              end
            when :bearish
              if histogram_decreasing? && current_histogram < 0
                signal.merge!(type: :sell, reason: "bearish_momentum_increasing")
              else
                signal.merge!(type: :hold, reason: "bearish_but_weakening")
              end
            end
          end

          # Adjust confidence based on additional factors
          if signal[:strength] == :very_strong
            signal[:confidence] = :high
          elsif signal[:strength] == :weak
            signal[:confidence] = :low
          end

          signal
        end

        # Calculate zero line crossings (trend changes).
        # @return [Array<Hash>] Array of zero line crossings with timestamps
        def zero_line_crossings
          return [] if values.length < 2

          crossings = []

          values.each_cons(2).with_index do |(prev, curr), index|
            # Bullish zero line cross (below to above)
            if prev.value <= 0 && curr.value > 0
              crossings << {
                timestamp: curr.timestamp,
                type: :bullish_zero_cross,
                from: prev.value,
                to: curr.value
              }
            # Bearish zero line cross (above to below)
            elsif prev.value >= 0 && curr.value < 0
              crossings << {
                timestamp: curr.timestamp,
                type: :bearish_zero_cross,
                from: prev.value,
                to: curr.value
              }
            end
          end

          crossings
        end

        # Get MACD value at specific timestamp.
        # @param timestamp [Integer, String] The timestamp to lookup
        # @return [Value, nil] MACD value at that time
        def value_at(timestamp)
          values.find { |v| v.timestamp == timestamp }
        end

        # Get the date range covered by this MACD data.
        # @return [Hash] Hash with :start and :end timestamps
        def date_range
          return {} if values.empty?

          {
            start: values.first.timestamp,
            end: values.last.timestamp
          }
        end

        # Calculate average MACD line value over the dataset.
        # @return [Float] Mean MACD line value
        def average_macd
          return 0.0 if values.empty?

          macd_values = values.map(&:value)
          macd_values.sum / macd_values.length
        end

        # Calculate average histogram value over the dataset.
        # @return [Float] Mean histogram value
        def average_histogram
          return 0.0 if values.empty?

          histogram_values = values.map(&:histogram)
          histogram_values.sum / histogram_values.length
        end

        # Analyze histogram patterns for momentum insights.
        # @return [Hash] Histogram analysis
        def histogram_analysis
          return {} if values.length < 5

          recent_histograms = values.last(5).map(&:histogram)

          {
            current: current_histogram,
            trend: histogram_trend(recent_histograms),
            strength: histogram_strength_category(current_histogram),
            consistency: histogram_consistency(recent_histograms)
          }
        end

        # Create MACD object from API response data.
        #
        # @param ticker [String] Stock ticker symbol
        # @param json [Hash] Raw API response
        # @return [MACD] Transformed MACD object
        # @api private
        def self.from_api(ticker, json)
          data = JSON.parse(json.is_a?(String) ? json : json.to_json)
          results = data["results"] || {}

          # Extract values and convert timestamps
          api_values = results["values"] || []
          macd_values = api_values.map do |value_data|
            timestamp = value_data["timestamp"]
            # Convert millisecond timestamp to Time object
            time_obj = timestamp.is_a?(Integer) ? Time.at(timestamp / 1000.0) : timestamp
            {
              timestamp: time_obj,
              value: value_data["value"].to_f,
              signal: value_data["signal"].to_f,
              histogram: value_data["histogram"].to_f
            }
          end

          # Default MACD parameters
          short_window = 12
          long_window = 26
          signal_window = 9
          timespan = "day"

          new(
            ticker: ticker.upcase,
            short_window: short_window,
            long_window: long_window,
            signal_window: signal_window,
            timespan: timespan,
            values: macd_values
          )
        end

        private

        # Determine histogram trend direction.
        # @param histograms [Array<Float>] Recent histogram values
        # @return [Symbol] :increasing, :decreasing, or :stable
        def histogram_trend(histograms)
          return :stable if histograms.length < 3

          increases = 0
          decreases = 0

          histograms.each_cons(2) do |prev, curr|
            if curr > prev
              increases += 1
            elsif curr < prev
              decreases += 1
            end
          end

          if increases > decreases
            :increasing
          elsif decreases > increases
            :decreasing
          else
            :stable
          end
        end

        # Categorize histogram strength.
        # @param histogram [Float] Histogram value
        # @return [Symbol] :weak, :moderate, :strong, or :very_strong
        def histogram_strength_category(histogram)
          return :none unless histogram

          abs_histogram = histogram.abs

          case abs_histogram
          when 0..0.2
            :weak
          when 0.2..0.5
            :moderate
          when 0.5..1.0
            :strong
          else
            :very_strong
          end
        end

        # Calculate histogram consistency (lower values = more consistent).
        # @param histograms [Array<Float>] Recent histogram values
        # @return [Float] Standard deviation of histogram values
        def histogram_consistency(histograms)
          return 0.0 if histograms.length < 2

          mean = histograms.sum / histograms.length
          variance = histograms.map { |h| (h - mean)**2 }.sum / histograms.length

          Math.sqrt(variance).round(4)
        end
      end
    end
  end
end
