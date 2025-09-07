require "active_support/core_ext/hash/keys"
require "polymux/client"
require "polymux/api/transformers"
require "dry/struct"

module Polymux
  module Api
    class Options < Polymux::Client::PolymuxRestHandler      
      def contracts(ticker = nil, options = {})
        options = options.dup
        options[:underlying_ticker] = ticker if ticker.is_a?(String)
        request = _client.http.get("/v3/reference/options/contracts", options)
        request.body.fetch("results", []).map do |contract_json|
          Contract.from_api(contract_json)
        end
      end

      def for_ticker(underlying_ticker, options = {})
        contracts(underlying_ticker, options)
      end

      def snapshot(contract, options = {})
        raise ArgumentError, "A Contract object must be provided" unless contract.is_a?(Contract)

        _client.http.get("/v3/snapshot/options/#{contract.underlying_ticker}/#{contract.ticker}", options).tap do |response|
          raise Polymux::Api::Error, "Failed to fetch snapshot for #{ticker}" unless response.success?
          return Snapshot.from_api(response.body.fetch("results"))
        end
      end

      def chain(underlying_ticker, options = {})
        raise ArgumentError, "Underlying ticker must be a string" unless underlying_ticker.is_a?(String)
        _client.http.get("/v3/snapshot/options/#{underlying_ticker}", options).tap do |response|
          raise Polymux::Api::Error, "Failed to fetch options chain for #{underlying_ticker}" unless response.success?

          return response.body.fetch("results", []).map do |chain_json|
            Snapshot.from_api(chain_json)
          end
        end
      end

      def trades(contract, options = {})
        raise ArgumentError, "Contract must be a ticker or a Contract object" unless contract.is_a?(String) || contract.is_a?(Contract)
        ticker = contract.is_a?(Contract) ? contract.ticker : contract
        
        _client.http.get("/v3/trades/#{ticker}", options).tap do |response|
          raise Polymux::Api::Error, "Failed to fetch trades for #{ticker}" unless response.success?

          return response.body.fetch("results", []).map do |trade_json|
            Trade.from_api(ticker, trade_json)
          end
        end
      end

      def quotes(contract, options = {})
        raise ArgumentError, "Contract must be a ticker or a Contract object" unless contract.is_a?(String) || contract.is_a?(Contract)
        ticker = contract.is_a?(Contract) ? contract.ticker : contract
        
        _client.http.get("/v3/quotes/#{ticker}", options).tap do |response|
          raise Polymux::Api::Error, "Failed to fetch quotes for #{ticker}" unless response.success?
          return response.body.fetch("results", []).map do |quote_json|
            Quote.from_api(ticker, quote_json)
          end
        end
      end

      def daily_summary(contract, date)
        raise ArgumentError, "Contract must be a string or a contract object must be provided" unless contract.is_a?(String) || contract.is_a?(Contract)
        raise ArgumentError, "Date must be a String in YYYY-MM-DD format" unless date.is_a?(String) && date.match?(/^\d{4}-\d{2}-\d{2}$/)

        ticker = contract.is_a?(Contract) ? contract.ticker : contract

        _client.http.get("/v1/open-close/#{ticker}/#{date}").tap do |response|
          raise Polymux::Api::Error, "Failed to fetch daily summary for #{ticker} on #{date}" unless response.success?
          return DailySummary.try(response.body.fetch("results", {}))
        end
      end

      def previous_day(contract)
        raise ArgumentError, "Contract must be a ticker or a Contract object" unless contract.is_a?(String) || contract.is_a?(Contract)
        ticker = contract.is_a?(Contract) ? contract.ticker : contract

        _client.http.get("/v2/aggs/ticker/#{ticker}/prev").tap do |response|
          raise Polymux::Api::Error, "Failed to fetch previous day summary for #{ticker}" unless response.success?
          raise Polymux::Options::NoPreviousDataFound, "No previous day data found for #{ticker}" if response.body.fetch("results", []).empty?

          return PreviousDay.from_api(response.body.fetch("results", []).first)
        end
      end
    end
  end
end
