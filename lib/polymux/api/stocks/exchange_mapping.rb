# frozen_string_literal: true

module Polymux
  module Api
    class Stocks
      # Shared module for exchange code to name mapping.
      #
      # Eliminates duplication of exchange name lookup logic across
      # Trade and Quote classes. Provides consistent exchange name
      # resolution with a single source of truth.
      #
      # @example Using in a data class
      #   class Trade < Dry::Struct
      #     include ExchangeMapping
      #
      #     def exchange_name
      #       map_exchange_code(exchange)
      #     end
      #   end
      module ExchangeMapping
        # Maps exchange codes to human-readable names.
        #
        # @param exchange_code [Integer, String, nil] Exchange identifier
        # @return [String] Human-readable exchange name
        def map_exchange_code(exchange_code)
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
