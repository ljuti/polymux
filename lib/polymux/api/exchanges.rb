require "polymux/client"
require "dry/struct"

module Polymux
  module Api
    # API client for exchange information and listings.
    #
    # Provides access to exchange data including names, Market Identifier Codes (MICs),
    # and asset class information. Each exchange is represented by an Exchange struct
    # with methods for determining what types of assets are traded.
    #
    # @example List all exchanges
    #   client = Polymux::Client.new
    #   exchanges = client.exchanges.list
    #
    #   puts "Total exchanges: #{exchanges.length}"
    #   options_exchanges = exchanges.select(&:options?)
    #   puts "Options exchanges: #{options_exchanges.length}"
    #
    # @see Exchange Exchange data structure
    class Exchanges < Polymux::Client::PolymuxRestHandler
      # Represents a financial exchange with asset class and identification information.
      #
      # Each exchange has identifying information including name and MIC codes,
      # plus categorization by the primary asset classes traded on that exchange.
      # The struct provides convenience methods for checking asset class support.
      #
      # @example Check exchange capabilities
      #   exchange = exchanges.find { |e| e.name.include?("NASDAQ") }
      #
      #   if exchange.options?
      #     puts "#{exchange.name} trades options contracts"
      #     puts "MIC: #{exchange.mic}"
      #   end
      class Exchange < Dry::Struct
        transform_keys(&:to_sym)

        # Human-readable name of the exchange
        # @return [String] Exchange name (e.g., "NASDAQ")
        attribute :name, Types::String

        # Market Identifier Code - ISO standard exchange identifier
        # @return [String, nil] Primary MIC code (e.g., "XNGS" for NASDAQ)
        attribute? :mic, Types::String | Types::Nil

        # Operating MIC - identifies the specific operating entity
        # @return [String, nil] Operating MIC code if different from primary MIC
        attribute? :operating_mic, Types::String | Types::Nil

        # Primary asset class traded on this exchange
        # @return [String] Asset class ("stocks", "options", "futures", "fx")
        attribute :asset_class, Types::String

        # Website URL for the exchange
        # @return [String, nil] Exchange website URL if available
        attribute? :url, Types::String | Types::Nil

        # Check if this exchange primarily trades stocks.
        # @return [Boolean] true if asset_class is "stocks"
        def stocks?
          asset_class == "stocks"
        end

        # Check if this exchange primarily trades options.
        # @return [Boolean] true if asset_class is "options"
        def options?
          asset_class == "options"
        end

        # Check if this exchange primarily trades futures.
        # @return [Boolean] true if asset_class is "futures"
        def futures?
          asset_class == "futures"
        end

        # Check if this exchange primarily trades forex.
        # @return [Boolean] true if asset_class is "fx"
        def forex?
          asset_class == "fx"
        end
      end

      # Retrieve a list of all supported exchanges.
      #
      # Returns information about all exchanges supported by the Polygon.io API,
      # including their names, MIC codes, and primary asset classes. This is
      # useful for understanding market coverage and for filtering data by exchange.
      #
      # @return [Array<Exchange>] Array of all supported exchanges
      # @raise [Polymux::Api::Error] if the API request fails
      #
      # @example Find options exchanges
      #   exchanges = client.exchanges.list
      #   options_exchanges = exchanges.select(&:options?)
      #
      #   options_exchanges.each do |exchange|
      #     puts "#{exchange.name} (#{exchange.mic})"
      #   end
      #
      # @example Group exchanges by asset class
      #   by_asset_class = exchanges.group_by(&:asset_class)
      #   by_asset_class.each do |asset_class, exchanges|
      #     puts "#{asset_class}: #{exchanges.length} exchanges"
      #   end
      def list
        request = _client.http.get("/v3/reference/exchanges")
        Types::Array.of(Exchange).try(request.body.fetch("results", []))
      end
    end
  end
end
