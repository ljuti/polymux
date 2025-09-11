require "dry/struct"

module Polymux
  module Api
    class Options
      # Represents option Greeks for risk analysis and hedging.
      #
      # Greeks measure the sensitivity of option prices to various market factors.
      # These metrics are essential for understanding option risk characteristics
      # and building hedged portfolios.
      #
      # @example Risk analysis using Greeks
      #   snapshot = client.options.snapshot(contract)
      #   greeks = snapshot.greeks
      #
      #   if greeks
      #     puts "Delta: #{greeks.delta} (price sensitivity to underlying)"
      #     puts "Gamma: #{greeks.gamma} (delta sensitivity)"
      #     puts "Theta: #{greeks.theta} (time decay per day)"
      #     puts "Vega: #{greeks.vega} (volatility sensitivity)"
      #
      #     puts "High gamma risk!" if greeks.high_gamma?
      #     puts "Significant time decay" if greeks.high_theta_decay?
      #   end
      class Greeks < Dry::Struct
        transform_keys(&:to_sym)

        # Delta: sensitivity to underlying price changes
        # @return [Integer, Float, nil] Change in option price per $1 change in underlying
        #   Ranges from 0 to 1 for calls, 0 to -1 for puts
        attribute? :delta, Types::PolymuxNumber | Types::Nil

        # Gamma: sensitivity of delta to underlying price changes
        # @return [Integer, Float, nil] Change in delta per $1 change in underlying
        #   Higher gamma means delta changes more rapidly
        attribute? :gamma, Types::PolymuxNumber | Types::Nil

        # Theta: time decay sensitivity
        # @return [Integer, Float, nil] Change in option price per day passing
        #   Usually negative (options lose value as expiration approaches)
        attribute? :theta, Types::PolymuxNumber | Types::Nil

        # Vega: sensitivity to volatility changes
        # @return [Integer, Float, nil] Change in option price per 1% change in implied volatility
        #   Higher vega means more sensitive to volatility changes
        attribute? :vega, Types::PolymuxNumber | Types::Nil

        # Check if this option has high gamma (>0.05).
        # High gamma indicates rapid changes in delta.
        # @return [Boolean] true if gamma is present and > 0.05
        def high_gamma?
          return false unless gamma
          gamma.abs > 0.05
        end

        # Check if this option has significant time decay (theta < -0.05).
        # @return [Boolean] true if theta indicates high daily decay
        def high_theta_decay?
          return false unless theta
          theta < -0.05
        end

        # Check if this option is highly sensitive to volatility (vega > 0.10).
        # @return [Boolean] true if vega indicates high volatility sensitivity
        def high_vega?
          return false unless vega
          vega.abs > 0.10
        end

        # Check if delta indicates this is likely a call option.
        # @return [Boolean] true if delta is positive (typical for calls)
        def call_like_delta?
          return false unless delta
          delta > 0
        end

        # Check if delta indicates this is likely a put option.
        # @return [Boolean] true if delta is negative (typical for puts)
        def put_like_delta?
          return false unless delta
          delta < 0
        end

        # Get absolute delta value (useful for hedging calculations).
        # @return [Float, nil] Absolute value of delta
        def abs_delta
          delta&.abs
        end
      end
    end
  end
end
