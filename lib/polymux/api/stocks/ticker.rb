require "dry/struct"
require "polymux/api/transformers"

module Polymux
  module Api
    class Stocks
      # Represents a stock ticker with basic identifying information.
      #
      # Contains essential information needed to identify a stock ticker
      # including symbol, name, market classification, and status. This
      # data structure provides the foundation for stock discovery and
      # reference operations.
      #
      # @example Basic ticker information
      #   tickers = client.stocks.tickers("AAPL")
      #   ticker = tickers.first
      #
      #   puts "Ticker: #{ticker.ticker}"
      #   puts "Name: #{ticker.name}"
      #   puts "Market: #{ticker.market}"
      #   puts "Active: #{ticker.active?}"
      class Ticker < Dry::Struct
        transform_keys(&:to_sym)

        # Stock ticker symbol
        # @return [String] The ticker symbol (e.g., "AAPL")
        attribute :ticker, Types::String

        # Company or security name
        # @return [String, nil] Full company name
        attribute? :name, Types::String | Types::Nil

        # Market classification
        # @return [String, nil] Market type ("stocks", "otc", etc.)
        attribute? :market, Types::String | Types::Nil

        # Locale classification
        # @return [String, nil] Geographic locale (e.g., "us")
        attribute? :locale, Types::String | Types::Nil

        # Primary exchange
        # @return [String, nil] Exchange where primarily traded
        attribute? :primary_exchange, Types::String | Types::Nil

        # Security type
        # @return [String, nil] Type of security ("CS" for common stock, etc.)
        attribute? :type, Types::String | Types::Nil

        # Whether the ticker is actively traded
        # @return [Boolean, nil] Active status
        attribute? :active, Types::Bool | Types::Nil

        # Currency denomination
        # @return [String, nil] Currency code (e.g., "USD")
        attribute? :currency_name, Types::String | Types::Nil

        # CUSIP identifier
        # @return [String, nil] CUSIP number if available
        attribute? :cusip, Types::String | Types::Nil

        # CIK identifier
        # @return [String, nil] SEC CIK identifier if available
        attribute? :cik, Types::String | Types::Nil

        # Composite FIGI identifier
        # @return [String, nil] FIGI identifier if available
        attribute? :composite_figi, Types::String | Types::Nil

        # Share class FIGI identifier
        # @return [String, nil] Share class FIGI if available
        attribute? :share_class_figi, Types::String | Types::Nil

        # Last updated timestamp
        # @return [String, nil] When ticker information was last updated
        attribute? :last_updated_utc, Types::String | Types::Nil

        # Check if this ticker represents common stock.
        # @return [Boolean] true if type is "CS"
        def common_stock?
          type == "CS"
        end

        # Check if this ticker represents preferred stock.
        # @return [Boolean] true if type is "PFD"
        def preferred_stock?
          type == "PFD"
        end

        # Check if this ticker is actively traded.
        # @return [Boolean] true if active is true
        def active?
          active == true
        end

        # Check if this ticker is traded on OTC markets.
        # @return [Boolean] true if market is "otc"
        def otc?
          market == "otc"
        end

        # Create Ticker object from API response data.
        #
        # @param json [Hash] Raw ticker data from API
        # @return [Ticker] Transformed ticker object
        # @api private
        def self.from_api(json)
          attrs = Api::Transformers.ticker(json)
          new(attrs)
        end
      end
    end
  end
end
