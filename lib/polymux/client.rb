require "faraday"

module Polymux
  class Client
    def initialize(config = Config.new)
      @_config = config
    end

    def exchanges
      Api::Exchanges.new(self)
    end

    def markets
      Api::Markets.new(self)
    end

    def options
      Api::Options.new(self)
    end
    
    def http
      @_http ||= Faraday.new(url: @_config.base_url) do |faraday|
        faraday.request :json
        faraday.response :json, content_type: /\bjson$/
        faraday.adapter Faraday.default_adapter
        faraday.headers["Authorization"] = "Bearer #{@_config.api_key}"
      end
    end

    class PolymuxRestHandler
      def initialize(client)
        @_client = client
      end

      private

      attr_reader :_client
    end
  end
end
