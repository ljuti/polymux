# frozen_string_literal: true

module Polymux
  module Api
    class Stocks
      # Shared module for timestamp formatting.
      #
      # Eliminates duplication of timestamp formatting logic across
      # data structures. Provides consistent timestamp display formatting
      # with robust error handling.
      #
      # @example Using in a data class
      #   class Trade < Dry::Struct
      #     include TimestampFormatting
      #
      #     def formatted_timestamp
      #       format_timestamp(timestamp)
      #     end
      #   end
      module TimestampFormatting
        # Formats timestamp for human-readable display.
        #
        # @param timestamp [String, Integer, nil] Timestamp to format
        # @return [String] Human-readable timestamp or "N/A" if invalid
        def format_timestamp(timestamp)
          return "N/A" unless timestamp
          return "N/A" if timestamp.to_s.strip.empty?

          begin
            Time.parse(timestamp.to_s).strftime("%Y-%m-%d %H:%M:%S")
          rescue ArgumentError, TypeError
            timestamp.to_s
          end
        end
      end
    end
  end
end
