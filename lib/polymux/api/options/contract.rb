require "dry/struct"
require "polymux/api/transformers"

module Polymux
  module Api
    class Options
      # Represents an options contract with all identifying characteristics.
      #
      # Contains all the essential information needed to uniquely identify
      # an options contract including strike price, expiration date, contract type,
      # and the underlying asset. This data structure is immutable and provides
      # the foundation for all options-related operations.
      #
      # @example Analyze contract characteristics
      #   contracts = client.options.contracts("AAPL")
      #   contract = contracts.first
      #
      #   puts "Contract: #{contract.ticker}"
      #   puts "Underlying: #{contract.underlying_ticker}"
      #   puts "Type: #{contract.call? ? 'Call' : 'Put'}"
      #   puts "Strike: $#{contract.strike_price}"
      #   puts "Expires: #{contract.expiration_date}"
      #   puts "Multiplier: #{contract.shares_per_contract}"
      class Contract < Dry::Struct
        transform_keys(&:to_sym)

        # Classification of Financial Instrument (CFI) code
        # @return [String] Standardized instrument classification
        attribute :cfi, Types::String

        # Type of options contract
        # @return [String] Either "call" or "put"
        attribute :contract_type, Types::String

        # Exercise style of the option
        # @return [String] "american" (can exercise anytime) or "european" (exercise only at expiry)
        attribute :exercise_style, Types::String

        # Contract expiration date
        # @return [String] Date in YYYY-MM-DD format when contract expires
        attribute :expiration_date, Types::String

        # Primary exchange where this contract is listed
        # @return [String] Exchange identifier (e.g., "CBOE", "ISE")
        attribute :primary_exchange, Types::String

        # Strike price of the option
        # @return [Integer, Float] Price at which option can be exercised
        attribute :strike_price, Types::PolymuxNumber

        # Number of underlying shares per contract
        # @return [Integer] Contract multiplier (typically 100 for equity options)
        attribute :shares_per_contract, Types::Integer

        # Unique ticker symbol for this specific contract
        # @return [String] Full options ticker (e.g., "O:AAPL240315C00150000")
        attribute :ticker, Types::String

        # Ticker symbol of the underlying asset
        # @return [String] Underlying stock ticker (e.g., "AAPL")
        attribute :underlying_ticker, Types::String

        # Check if this is a call option.
        # @return [Boolean] true if contract_type is "call"
        def call?
          contract_type == "call"
        end

        # Check if this is a put option.
        # @return [Boolean] true if contract_type is "put"
        def put?
          contract_type == "put"
        end

        # Check if this is an American-style option (can exercise anytime).
        # @return [Boolean] true if exercise_style is "american"
        def american?
          exercise_style == "american"
        end

        # Check if this is a European-style option (exercise only at expiry).
        # @return [Boolean] true if exercise_style is "european"
        def european?
          exercise_style == "european"
        end

        # Get the contract's notional value (strike × multiplier).
        # @return [Numeric] Total value if exercised
        def notional_value
          strike_price * shares_per_contract
        end

        # Create Contract object from API response data.
        #
        # @param json [Hash] Raw contract data from API
        # @return [Contract] Transformed contract object
        # @api private
        def self.from_api(json)
          attrs = Api::Transformers.contract(json)
          new(attrs)
        end
      end
    end
  end
end
