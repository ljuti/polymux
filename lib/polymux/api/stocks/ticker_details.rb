require "dry/struct"
require "polymux/api/transformers"

module Polymux
  module Api
    class Stocks
      # Represents detailed information about a stock ticker.
      #
      # Contains comprehensive information about a stock including company
      # details, market data, financial metrics, and trading information.
      # This provides a complete overview of the security for analysis.
      #
      # @example Company analysis
      #   details = client.stocks.ticker_details("AAPL")
      #
      #   puts "Company: #{details.name}"
      #   puts "Description: #{details.description}"
      #   puts "Market cap: $#{details.market_cap}"
      #   puts "Sector: #{details.sic_description}"
      #   puts "Website: #{details.homepage_url}"
      class TickerDetails < Dry::Struct
        transform_keys(&:to_sym)

        # Stock ticker symbol
        # @return [String] The ticker symbol
        attribute :ticker, Types::String

        # Company name
        # @return [String, nil] Full company name
        attribute? :name, Types::String | Types::Nil

        # Market classification
        # @return [String, nil] Market type
        attribute? :market, Types::String | Types::Nil

        # Locale classification
        # @return [String, nil] Geographic locale
        attribute? :locale, Types::String | Types::Nil

        # Primary exchange
        # @return [String, nil] Primary trading exchange
        attribute? :primary_exchange, Types::String | Types::Nil

        # Security type
        # @return [String, nil] Type of security
        attribute? :type, Types::String | Types::Nil

        # Whether actively traded
        # @return [Boolean, nil] Active trading status
        attribute? :active, Types::Bool | Types::Nil

        # Currency denomination
        # @return [String, nil] Currency code (e.g., "USD")
        attribute? :currency_name, Types::String | Types::Nil

        # CUSIP identifier
        # @return [String, nil] CUSIP number
        attribute? :cusip, Types::String | Types::Nil

        # CIK identifier
        # @return [String, nil] SEC CIK identifier
        attribute? :cik, Types::String | Types::Nil

        # Composite FIGI
        # @return [String, nil] FIGI identifier
        attribute? :composite_figi, Types::String | Types::Nil

        # Share class FIGI
        # @return [String, nil] Share class FIGI
        attribute? :share_class_figi, Types::String | Types::Nil

        # Company description
        # @return [String, nil] Business description
        attribute? :description, Types::String | Types::Nil

        # Company website
        # @return [String, nil] Homepage URL
        attribute? :homepage_url, Types::String | Types::Nil

        # Total employees
        # @return [Integer, nil] Number of employees
        attribute? :total_employees, Types::Integer | Types::Nil

        # Listing date
        # @return [String, nil] Date first listed (YYYY-MM-DD)
        attribute? :list_date, Types::String | Types::Nil

        # Company logo URL
        # @return [String, nil] Logo image URL
        attribute? :icon_url, Types::String | Types::Nil

        # Outstanding shares
        # @return [Integer, Float, nil] Number of shares outstanding
        attribute? :share_class_shares_outstanding, Types::PolymuxNumber | Types::Nil

        # Weighted shares outstanding
        # @return [Integer, Float, nil] Weighted average shares outstanding
        attribute? :weighted_shares_outstanding, Types::PolymuxNumber | Types::Nil

        # Market capitalization
        # @return [Integer, Float, nil] Market cap in USD
        attribute? :market_cap, Types::PolymuxNumber | Types::Nil

        # Phone number
        # @return [String, nil] Company phone number
        attribute? :phone_number, Types::String | Types::Nil

        # Mailing address
        # @return [Hash, nil] Company address information
        attribute? :address, Types::Hash | Types::Nil

        # SIC code
        # @return [String, nil] Standard Industrial Classification code
        attribute? :sic_code, Types::String | Types::Nil

        # SIC description
        # @return [String, nil] Industry description
        attribute? :sic_description, Types::String | Types::Nil

        # Check if this is common stock.
        # @return [Boolean] true if type is "CS"
        def common_stock?
          type == "CS"
        end

        # Check if actively traded.
        # @return [Boolean] true if active
        def active?
          active == true
        end

        # Get formatted market cap.
        # @return [String] Human-readable market cap
        def formatted_market_cap
          return "N/A" unless market_cap

          if market_cap >= 1_000_000_000_000
            "$#{(market_cap / 1_000_000_000_000.0).round(2)}T"
          elsif market_cap >= 1_000_000_000
            "$#{(market_cap / 1_000_000_000.0).round(2)}B"
          elsif market_cap >= 1_000_000
            "$#{(market_cap / 1_000_000.0).round(2)}M"
          else
            "$#{market_cap}"
          end
        end

        # Get company address as formatted string.
        # @return [String, nil] Formatted address
        def formatted_address
          return nil unless address

          parts = []
          parts << address["address1"] if address["address1"]
          parts << address["city"] if address["city"]
          parts << address["state"] if address["state"]
          parts << address["postal_code"] if address["postal_code"]

          parts.empty? ? nil : parts.join(", ")
        end

        # Create TickerDetails object from API response data.
        #
        # @param json [Hash] Raw ticker details data from API
        # @return [TickerDetails] Transformed ticker details object
        # @api private
        def self.from_api(json)
          attrs = Api::Transformers.ticker_details(json)
          new(attrs)
        end
      end
    end
  end
end
