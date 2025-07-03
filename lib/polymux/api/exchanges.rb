require "polymux/client"
require "dry/struct"

module Polymux
  module Api
    class Exchanges < Polymux::Client::PolymuxRestHandler
      class Exchange < Dry::Struct
        transform_keys(&:to_sym)

        attribute :name, Types::String
        attribute? :mic, Types::String | Types::Nil
        attribute? :operating_mic, Types::String | Types::Nil
        attribute :asset_class, Types::String
        attribute? :url, Types::String | Types::Nil

        def stocks?
          asset_class == "stocks"
        end

        def options?
          asset_class == "options"
        end

        def futures?
          asset_class == "futures"
        end

        def forex?
          asset_class == "fx"
        end
      end

      def list
        request = _client.http.get("/v3/reference/exchanges")
        Types::Array.of(Exchange).try(request.body.fetch("results", []))
      end
    end
  end
end