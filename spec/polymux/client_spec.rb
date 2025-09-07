# frozen_string_literal: true

require "spec_helper"

RSpec.describe Polymux::Client do
  let(:config) { Polymux::Config.new(api_key: "test_key_123", base_url: "https://api.polygon.io") }
  let(:client) { described_class.new(config) }

  describe "initialization" do
    context "with provided config" do
      it "accepts a configuration object" do
        expect { described_class.new(config) }.not_to raise_error
      end

      it "stores the configuration internally" do
        expect(client.instance_variable_get(:@_config)).to eq(config)
      end
    end

    context "with default config" do
      it "creates a default configuration when none provided" do
        default_client = described_class.new

        expect(default_client.instance_variable_get(:@_config)).to be_a(Polymux::Config)
      end
    end
  end

  describe "#websocket" do
    it "returns a Websocket instance configured with the same config" do
      websocket = client.websocket

      expect(websocket).to be_a(Polymux::Websocket)
      expect(websocket.instance_variable_get(:@_config)).to eq(config)
    end

    it "creates a new Websocket instance on each call" do
      websocket1 = client.websocket
      websocket2 = client.websocket

      expect(websocket1).not_to be(websocket2)
      expect(websocket1).to be_a(Polymux::Websocket)
      expect(websocket2).to be_a(Polymux::Websocket)
    end
  end

  describe "#exchanges" do
    it "returns an Exchanges API handler" do
      exchanges = client.exchanges

      expect(exchanges).to be_a(Polymux::Api::Exchanges)
    end

    it "passes the client instance to the Exchanges handler" do
      exchanges = client.exchanges

      expect(exchanges.send(:_client)).to eq(client)
    end

    it "creates a new Exchanges instance on each call" do
      exchanges1 = client.exchanges
      exchanges2 = client.exchanges

      expect(exchanges1).not_to be(exchanges2)
    end
  end

  describe "#markets" do
    it "returns a Markets API handler" do
      markets = client.markets

      expect(markets).to be_a(Polymux::Api::Markets)
    end

    it "passes the client instance to the Markets handler" do
      markets = client.markets

      expect(markets.send(:_client)).to eq(client)
    end

    it "creates a new Markets instance on each call" do
      markets1 = client.markets
      markets2 = client.markets

      expect(markets1).not_to be(markets2)
    end
  end

  describe "#options" do
    it "returns an Options API handler" do
      options = client.options

      expect(options).to be_a(Polymux::Api::Options)
    end

    it "passes the client instance to the Options handler" do
      options = client.options

      expect(options.send(:_client)).to eq(client)
    end

    it "creates a new Options instance on each call" do
      options1 = client.options
      options2 = client.options

      expect(options1).not_to be(options2)
    end
  end

  describe "#http" do
    let(:http_client) { client.http }

    it "returns a Faraday connection" do
      expect(http_client).to be_a(Faraday::Connection)
    end

    it "configures the base URL from config" do
      expect(http_client.url_prefix.to_s).to eq("https://api.polygon.io/")
    end

    it "sets up JSON request and response handling" do
      expect(http_client.builder.handlers).to include(Faraday::Request::Json)
      expect(http_client.builder.handlers).to include(Faraday::Response::Json)
    end

    it "includes the API key in authorization header" do
      expect(http_client.headers["Authorization"]).to eq("Bearer test_key_123")
    end

    it "memoizes the HTTP client instance" do
      expect(client.http).to be(client.http)
    end

    context "with different configurations" do
      let(:custom_config) { Polymux::Config.new(api_key: "custom_key", base_url: "https://custom.api") }
      let(:custom_client) { described_class.new(custom_config) }

      it "uses custom base URL" do
        expect(custom_client.http.url_prefix.to_s).to eq("https://custom.api/")
      end

      it "uses custom API key in authorization header" do
        expect(custom_client.http.headers["Authorization"]).to eq("Bearer custom_key")
      end
    end
  end

  describe "::PolymuxRestHandler" do
    let(:handler) { described_class::PolymuxRestHandler.new(client) }

    describe "initialization" do
      it "accepts a client instance" do
        expect { described_class::PolymuxRestHandler.new(client) }.not_to raise_error
      end

      it "stores the client instance internally" do
        expect(handler.send(:_client)).to eq(client)
      end
    end

    describe "private methods" do
      it "provides access to client through _client method" do
        expect(handler.send(:_client)).to eq(client)
      end

      it "allows subclasses to access HTTP client through parent client" do
        expect(handler.send(:_client).http).to be_a(Faraday::Connection)
      end
    end
  end
end
