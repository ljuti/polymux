require "active_support/core_ext/hash/keys"
require "polymux/client"
require "polymux/api/transformers"
require "dry/struct"

module Polymux
  module Api
    class Options < Polymux::Client::PolymuxRestHandler
      class Contract < Dry::Struct
        transform_keys(&:to_sym)

        attribute :cfi, Types::String
        attribute :contract_type, Types::String
        attribute :exercise_style, Types::String
        attribute :expiration_date, Types::String
        attribute :primary_exchange, Types::String
        attribute :strike_price, Types::Float | Types::Integer
        attribute :shares_per_contract, Types::Integer
        attribute :ticker, Types::String
        attribute :underlying_ticker, Types::String

        def self.from_api(json)
          attrs = Api::Transformers.contract(json)
          new(attrs)
        end
      end

      class UnderlyingAsset < Dry::Struct
        transform_keys(&:to_sym)

        attribute :ticker, Types::String
        attribute? :price, Types::Float | Types::Nil
        attribute? :value, Types::Float | Types::Nil
        attribute? :last_updated, Types::Integer | Types::Nil
        attribute? :timeframe, Types::String | Types::Nil
        attribute :change_to_break_even, Types::Float | Types::Integer

        def timestamp
          Time.at(Rational(last_updated, 1_000_000_000)).to_datetime if last_updated
        end

        def realtime?
          timeframe == "REAL-TIME"
        end

        def delayed?
          timeframe == "DELAYED"
        end
      end

      class LastQuote < Dry::Struct
        transform_keys(&:to_sym)

        attribute :ask, Types::PolymuxNumber
        attribute :ask_size, Types::PolymuxNumber
        attribute :bid, Types::PolymuxNumber
        attribute :bid_size, Types::PolymuxNumber
        attribute :midpoint, Types::PolymuxNumber
        attribute :last_updated, Types::Integer
        attribute? :timeframe, Types::String

        def timestamp
          Time.at(Rational(last_updated, 1_000_000_000)).to_datetime if last_updated
        end

        def realtime?
          timeframe == "REAL-TIME"
        end

        def delayed?
          timeframe == "DELAYED"
        end
      end

      class LastTrade < Dry::Struct
        transform_keys(&:to_sym)

        attribute :price, Types::PolymuxNumber
        attribute :size, Types::Integer
        attribute :sip_timestamp, Types::Integer
        attribute? :timeframe, Types::String

        def timestamp
          Time.at(Rational(sip_timestamp, 1_000_000_000)).to_datetime if sip_timestamp
        end

        def realtime?
          timeframe == "REAL-TIME"
        end

        def delayed?
          timeframe == "DELAYED"
        end
      end
      
      class DailyBar < Dry::Struct
        transform_keys(&:to_sym)

        attribute :open, Types::PolymuxNumber
        attribute :high, Types::PolymuxNumber
        attribute :low, Types::PolymuxNumber
        attribute :close, Types::PolymuxNumber
        attribute :volume, Types::PolymuxNumber
        attribute :vwap, Types::PolymuxNumber
        attribute :previous_close, Types::PolymuxNumber
        attribute :change, Types::PolymuxNumber
        attribute :change_percent, Types::PolymuxNumber
      end

      class Greeks < Dry::Struct
        transform_keys(&:to_sym)

        attribute? :delta, Types::Float | Types::Nil
        attribute? :gamma, Types::Float | Types::Nil
        attribute? :theta, Types::Float | Types::Nil
        attribute? :vega, Types::Float | Types::Nil
      end

      class Snapshot < Dry::Struct
        transform_keys(&:to_sym)

        attribute :break_even_price, Types::Float
        attribute? :daily_bar, DailyBar
        attribute? :implied_volatility, Types::Float
        attribute? :last_quote, LastQuote
        attribute? :last_trade, LastTrade
        attribute :open_interest, Types::Integer
        attribute :underlying_asset, UnderlyingAsset

        attribute? :greeks, Greeks

        def self.from_api(json)
          attrs = Api::Transformers.snapshot(json.deep_symbolize_keys)
          new(attrs)
        end
      end

      class Quote < Dry::Struct
        transform_keys(&:to_sym)

        attribute :ticker, Types::String
        attribute :timestamp, Types::Integer
        attribute :datetime, Types::DateTime
        attribute :ask_price, Types::PolymuxNumber
        attribute :bid_price, Types::PolymuxNumber
        attribute :ask_size, Types::Integer
        attribute :bid_size, Types::Integer
        attribute :sequence, Types::Integer

        def self.from_api(ticker, json)
          attrs = Api::Transformers.quote(json)
          attrs[:ticker] = ticker
          new(attrs)
        end
      end

      class Trade < Dry::Struct
        transform_keys(&:to_sym)

        attribute :ticker, Types::String
        attribute :timestamp, Types::Integer
        attribute :datetime, Types::DateTime
        attribute :price, Types::PolymuxNumber
        attribute :size, Types::PolymuxNumber

        def total_price
          (price * size).round(2)
        end
        
        def total_value
          (price * size * 100).round(2)
        end

        def self.from_api(ticker, json)
          attrs = Api::Transformers.trade(json)
          attrs[:ticker] = ticker
          new(attrs)
        end
      end

      class DailySummary < Dry::Struct
        transform_keys(&:to_sym)

        attribute :symbol, Types::String
        attribute :date, Types::String
        attribute :open, Types::PolymuxNumber
        attribute :high, Types::PolymuxNumber
        attribute :low, Types::PolymuxNumber
        attribute :close, Types::PolymuxNumber
        attribute :volume, Types::Integer
        attribute? :pre_market_open, Types::PolymuxNumber
        attribute? :after_hours_close, Types::PolymuxNumber
      end

      class PreviousDay < Dry::Struct
        transform_keys(&:to_sym)

        attribute :ticker, Types::String
        attribute :timestamp, Types::Integer
        attribute :open, Types::PolymuxNumber
        attribute :high, Types::PolymuxNumber
        attribute :low, Types::PolymuxNumber
        attribute :close, Types::PolymuxNumber
        attribute :volume, Types::Integer
        attribute :vwap, Types::PolymuxNumber

        def datetime
          Time.at(Rational(timestamp, 1000)).to_datetime if timestamp
        end

        def self.from_api(json)
          attrs = Api::Transformers.previous_day(json)
          new(attrs)
        end
      end
      
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
        raise ArgumentError, "Contract must be a ticker or a Contract object" unless contract.is_a?(Contract)

        request = _client.http.get("/v3/snapshot/options/#{contract.underlying_ticker}/#{contract.ticker}", options)
        raise Polymux::Error, "Failed to fetch snapshot for #{ticker}" unless request.success?

        Snapshot.from_api(request.body.fetch("results"))
      end

      def chain(underlying_ticker, options = {})
        raise ArgumentError, "Underlying ticker must be a string" unless underlying_ticker.is_a?(String)
        request = _client.http.get("/v3/snapshot/options/#{underlying_ticker}", options)
        raise Polymux::Error, "Failed to fetch options chain for #{underlying_ticker}" unless request.success?

        request.body.fetch("results", []).map do |chain_json|
          Snapshot.from_api(chain_json)
        end
      end

      def trades(contract, options = {})
        raise ArgumentError, "Contract must be a ticker or a Contract object" unless contract.is_a?(String) || contract.is_a?(Contract)
        ticker = contract.is_a?(Contract) ? contract.ticker : contract
        request = _client.http.get("/v3/trades/#{ticker}", options)
        raise Polymux::Error, "Failed to fetch trades for #{ticker}" unless request.success?

        request.body.fetch("results", []).map do |trade_json|
          Trade.from_api(ticker, trade_json)
        end
      end

      def quotes(contract, options = {})
        raise ArgumentError, "Contract must be a ticker or a Contract object" unless contract.is_a?(String) || contract.is_a?(Contract)
        ticker = contract.is_a?(Contract) ? contract.ticker : contract
        request = _client.http.get("/v3/quotes/#{ticker}", options)

        raise Polymux::Error, "Failed to fetch quotes for #{ticker}" unless request.success?
        request.body.fetch("results", []).map do |quote_json|
          Quote.from_api(ticker, quote_json)
        end
      end

      def daily_summary(contract, date)
        raise ArgumentError, "Contract must be a string or a contract object must be provided" unless contract.is_a?(String) || contract.is_a?(Contract)
        raise ArgumentError, "Date must be a String in YYYY-MM-DD format" unless date.is_a?(String) && date.match?(/^\d{4}-\d{2}-\d{2}$/)

        ticker = contract.is_a?(Contract) ? contract.ticker : contract

        request = _client.http.get("/v1/open-close/#{ticker}/#{date}")
        raise Polymux::Error, "Failed to fetch daily summary for #{ticker} on #{date}" unless request.success?

        DailySummary.try(request.body.fetch("results", {}))
      end

      def previous_day(contract)
        raise ArgumentError, "Contract must be a ticker or a Contract object" unless contract.is_a?(String) || contract.is_a?(Contract)
        ticker = contract.is_a?(Contract) ? contract.ticker : contract

        request = _client.http.get("/v2/aggs/ticker/#{ticker}/prev")
        raise Polymux::Error, "Failed to fetch previous day summary for #{ticker}" unless request.success?
        raise Polymux::Error, "No previous day data found for #{ticker}" if request.body.fetch("results", []).empty?

        PreviousDay.from_api(request.body.fetch("results", []).first)
      end
    end
  end
end
