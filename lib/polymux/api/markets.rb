require "polymux/client"

module Polymux
  module Api
    class Markets < Polymux::Client::PolymuxRestHandler
      class Holidays < Dry::Struct
        transform_keys(&:to_sym)

        attribute? :date, Types::String
        attribute? :exchange, Types::String
        attribute? :name, Types::String
        attribute? :open, Types::String
        attribute? :close, Types::String
        attribute? :status, Types::String

        def closed?
          status == "closed"
        end

        def early_close?
          status == "early-close"
        end
      end

      class Status < Dry::Struct
        transform_keys(&:to_sym)

        attribute? :after_hours, Types::Bool
        attribute? :pre_market, Types::Bool
        attribute? :status, Types::String
        attribute? :currencies, Types::Hash
        attribute? :exchanges, Types::Hash
        attribute? :indices, Types::Hash

        def closed?
          status == "closed"
        end

        def open?
          status != "closed"
        end

        def extended_hours?
          status == "extended-hours"
        end

        def self.from_api(json)
          attrs = Api::Transformers.market_status(json)
          new(attrs)
        end
      end

      def status
        request = _client.http.get("/v1/marketstatus/now")
        Status.from_api(request.body)
      end

      def holidays
        request = _client.http.get("/v1/marketstatus/upcoming")
        request.body.map do |holiday|
          Holidays.new(holiday)
        end
      end
    end
  end
end
