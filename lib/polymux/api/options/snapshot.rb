require "dry/struct"
require "polymux/api/transformers"
require "polymux/api/options/underlying_asset"

module Polymux
  module Api
    class Options
      # Represents a comprehensive market snapshot for an options contract.
      #
      # Contains current market data including last trade, last quote, daily bar,
      # implied volatility, Greeks, and underlying asset information. This provides
      # a complete real-time view of the contract's market state.
      #
      # @example Analyze market snapshot
      #   contracts = client.options.contracts("AAPL")
      #   snapshot = client.options.snapshot(contracts.first)
      #
      #   puts "Break-even price: $#{snapshot.break_even_price}"
      #   puts "Implied volatility: #{(snapshot.implied_volatility * 100).round(2)}%"
      #   puts "Open interest: #{snapshot.open_interest}"
      #
      #   if snapshot.last_trade
      #     puts "Last trade: #{snapshot.last_trade.size} @ $#{snapshot.last_trade.price}"
      #   end
      #
      #   if snapshot.greeks
      #     puts "Delta: #{snapshot.greeks.delta}"
      #     puts "Gamma: #{snapshot.greeks.gamma}"
      #   end
      class Snapshot < Dry::Struct
        transform_keys(&:to_sym)

        # Price at which the option position breaks even at expiration
        # @return [Float, nil] Break-even price for the option holder (nil if not available)
        attribute? :break_even_price, Types::Float.optional

        # Daily price and volume summary
        # @return [DailyBar, nil] OHLC and volume data for current trading day
        attribute? :daily_bar, DailyBar.optional

        # Current implied volatility of the option
        # @return [Float, nil] Implied volatility as decimal (0.25 = 25%)
        attribute? :implied_volatility, Types::Float.optional

        # Most recent bid/ask quote
        # @return [LastQuote, nil] Current market quote data
        attribute? :last_quote, LastQuote.optional

        # Most recent trade execution
        # @return [LastTrade, nil] Last trade price and size
        attribute? :last_trade, LastTrade.optional

        # Number of outstanding contracts
        # @return [Integer] Open interest (total contracts not yet closed)
        attribute :open_interest, Types::Integer

        # Information about the underlying stock
        # @return [UnderlyingAsset] Current underlying asset data
        attribute :underlying_asset, UnderlyingAsset

        # Option Greeks for risk analysis
        # @return [Greeks, nil] Delta, gamma, theta, vega values
        attribute? :greeks, Greeks.optional

        # Check if the option has recent trading activity.
        # @return [Boolean] true if last_trade data is present
        def actively_traded?
          !last_trade.nil?
        end

        # Check if there's current market liquidity.
        # @return [Boolean] true if last_quote data is present
        def liquid?
          !last_quote.nil?
        end

        # Get the current market price estimate.
        # Uses last trade price if available, otherwise midpoint of last quote.
        # @return [Float, nil] Best estimate of current market price
        def current_price
          return last_trade.price if last_trade
          return last_quote.midpoint if last_quote
          nil
        end

        # Calculate moneyness relative to underlying price.
        # @return [String] "ITM" (in-the-money), "OTM" (out-of-the-money), or "ATM" (at-the-money)
        def moneyness
          return "ATM" unless underlying_asset.price && break_even_price

          if (underlying_asset.price - break_even_price).abs < 0.01
            "ATM"
          elsif underlying_asset.price > break_even_price
            "ITM"
          else
            "OTM"
          end
        end

        # Create Snapshot object from API response data.
        #
        # @param json [Hash] Raw snapshot data from API
        # @return [Snapshot] Transformed snapshot object
        # @api private
        def self.from_api(json)
          attrs = Api::Transformers.snapshot(json.deep_symbolize_keys)
          new(attrs)
        end
      end
    end
  end
end
