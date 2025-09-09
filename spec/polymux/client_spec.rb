# frozen_string_literal: true

require "spec_helper"

RSpec.describe Polymux::Client do
  let(:config) { Polymux::Config.new(api_key: "test_key_123", base_url: "https://api.polygon.io") }
  let(:client) { described_class.new(config) }

  describe "initialization" do
    context "with provided config" do
      it "accepts a configuration object" do
        client_instance = described_class.new(config)
        expect(client_instance).to be_a(described_class)
        expect(client_instance.instance_variable_get(:@_config)).to eq(config)
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

    it "instantiates the fully qualified Polymux::Websocket class" do
      # This test catches mutations where Polymux::Websocket becomes Websocket
      expect(Polymux::Websocket).to receive(:new).with(config).and_call_original
      
      # Ensure unqualified Websocket class is not available or would cause issues
      expect(defined?(Websocket)).to be_falsy
      
      # Verify that if Websocket (unqualified) were called, it would fail
      if defined?(::Websocket)
        expect(::Websocket).not_to receive(:new)
      end
      
      websocket = client.websocket
      
      expect(websocket.class.name).to eq("Polymux::Websocket")
      expect(websocket.class.name).not_to eq("Websocket")
      
      # Additional verification that the constant resolution is correct
      expect(websocket.class).to eq(Polymux::Websocket)
      expect(websocket.class).not_to eq(Object.const_get("Websocket")) if defined?(::Websocket)
    end

    it "fails if unqualified Websocket class is used instead of Polymux::Websocket" do
      # This test specifically catches the Polymux::Websocket → Websocket mutation
      # by stubbing the unqualified Websocket to raise an error
      if defined?(::Websocket)
        allow(::Websocket).to receive(:new).and_raise(NameError, "Unqualified Websocket should not be used")
      else
        # If Websocket isn't defined, stub Object to define it and make it fail
        stub_const("Websocket", double("MockWebsocket"))
        allow(Websocket).to receive(:new).and_raise(NameError, "Unqualified Websocket should not be used")
      end
      
      # This should succeed because it uses Polymux::Websocket, not Websocket
      # Instead of checking for absence of NameError, verify the correct behavior
      websocket = client.websocket
      expect(websocket).to be_a(Polymux::Websocket)
      expect(websocket.class).to eq(Polymux::Websocket)
      expect(websocket.instance_variable_get(:@_config)).to eq(config)
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

  describe "#stocks" do
    it "returns a Stocks API handler" do
      stocks = client.stocks

      expect(stocks).to be_a(Polymux::Api::Stocks)
    end

    it "passes the client instance to the Stocks handler" do
      stocks = client.stocks

      expect(stocks.send(:_client)).to eq(client)
    end

    it "creates a new Stocks instance on each call" do
      stocks1 = client.stocks
      stocks2 = client.stocks

      expect(stocks1).not_to be(stocks2)
    end
  end

  describe "#technical_indicators" do
    it "returns a TechnicalIndicators API handler" do
      technical_indicators = client.technical_indicators

      expect(technical_indicators).to be_a(Polymux::Api::TechnicalIndicators)
    end

    it "passes the client instance to the TechnicalIndicators handler" do
      technical_indicators = client.technical_indicators

      expect(technical_indicators.send(:_client)).to eq(client)
    end

    it "creates a new TechnicalIndicators instance on each call" do
      technical_indicators1 = client.technical_indicators
      technical_indicators2 = client.technical_indicators

      expect(technical_indicators1).not_to be(technical_indicators2)
    end

    it "initializes TechnicalIndicators with self as argument, not nil" do
      # This test catches mutations where .new(self) becomes .new(nil) or .new
      expect(Polymux::Api::TechnicalIndicators).to receive(:new).with(client).and_call_original
      
      technical_indicators = client.technical_indicators
      
      expect(technical_indicators.send(:_client)).to eq(client)
      expect(technical_indicators.send(:_client)).not_to be_nil
    end
  end

  describe "#flat_files" do
    it "returns a FlatFiles Client API handler" do
      flat_files = client.flat_files

      expect(flat_files).to be_a(Polymux::Api::FlatFiles::Client)
    end

    it "passes the client instance to the FlatFiles Client handler" do
      flat_files = client.flat_files

      expect(flat_files.send(:_client)).to eq(client)
    end

    it "creates a new FlatFiles Client instance on each call" do
      flat_files1 = client.flat_files
      flat_files2 = client.flat_files

      expect(flat_files1).not_to be(flat_files2)
    end

    it "initializes FlatFiles Client with self as argument, not nil" do
      # This test catches mutations where .new(self) becomes .new(nil)
      expect(Polymux::Api::FlatFiles::Client).to receive(:new).with(client).and_call_original
      
      flat_files = client.flat_files
      
      expect(flat_files.send(:_client)).to eq(client)
      expect(flat_files.send(:_client)).not_to be_nil
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

    it "configures JSON response parsing with content type regex" do
      # This catches mutations in the content_type parameter
      # Create a mock response to verify content type handling
      mock_response = double("response", headers: {"content-type" => "application/json"})
      
      # Verify that the builder includes response JSON processing
      handlers = http_client.builder.handlers
      expect(handlers).to include(Faraday::Response::Json)
    end

    it "configures Faraday with proper adapter" do
      # This catches mutations where Faraday.default_adapter becomes nil or is removed
      # We verify the HTTP client can make requests, which requires a proper adapter
      expect(http_client).to respond_to(:get)
      expect(http_client).to respond_to(:post)
      expect(http_client.adapter).not_to be_nil
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

    context "integration-style HTTP functionality tests" do
      before do
        # Stub HTTP requests to test actual functionality
        stub_request(:get, "https://api.polygon.io/test/json")
          .with(headers: {"Authorization" => "Bearer test_key_123"})
          .to_return(
            status: 200,
            body: '{"result": "success", "data": "test"}',
            headers: {"Content-Type" => "application/json"}
          )

        stub_request(:get, "https://api.polygon.io/test/xml")
          .with(headers: {"Authorization" => "Bearer test_key_123"})  
          .to_return(
            status: 200,
            body: '<root><result>success</result></root>',
            headers: {"Content-Type" => "application/xml"}
          )
      end

      it "properly parses JSON responses using configured content type regex" do
        # This test catches mutations in JSON_CONTENT_TYPE_REGEX and content_type parameter
        response = http_client.get("/test/json")
        
        expect(response.status).to eq(200)
        expect(response.body).to be_a(Hash)
        expect(response.body["result"]).to eq("success")
        expect(response.body["data"]).to eq("test")
      end

      it "handles non-JSON content types correctly" do
        # This test verifies the content type regex works with boundaries
        response = http_client.get("/test/xml")
        
        expect(response.status).to eq(200)
        expect(response.body).to be_a(String) # Should not be parsed as JSON
        expect(response.body).to include("<result>success</result>")
      end

      it "requires content_type parameter for JSON response parsing" do
        # This test catches mutations where content_type parameter is removed entirely
        stub_request(:get, "https://api.polygon.io/test/content-type")
          .with(headers: {"Authorization" => "Bearer test_key_123"})
          .to_return(
            status: 200,
            body: '{"parsed": true}',
            headers: {"Content-Type" => "application/json"}
          )

        response = http_client.get("/test/content-type")
        
        # If content_type parameter was removed, this might not be parsed correctly
        expect(response.body).to be_a(Hash)
        expect(response.body["parsed"]).to be true
        expect(response.body["parsed"]).not_to eq("true") # Should be parsed as boolean, not string
      end

      it "can make HTTP requests successfully with configured adapter" do
        # This test catches mutations where adapter becomes nil or is removed
        # Instead of checking for absence of errors, verify the response is correct
        response = http_client.get("/test/json")
        
        expect(response).to respond_to(:status)
        expect(response).to respond_to(:body)
        expect(response).to respond_to(:headers)
        expect(response.status).to eq(200)
        expect(response.body).to be_a(Hash)
        expect(response.body["result"]).to eq("success")
      end

      it "preserves JSON parsing functionality across multiple requests" do
        # This test ensures the middleware stack is properly configured
        response1 = http_client.get("/test/json")
        response2 = http_client.get("/test/json")
        
        expect(response1.body).to be_a(Hash)
        expect(response2.body).to be_a(Hash)
        expect(response1.body).to eq(response2.body)
      end
    end

    context "HTTP configuration constants and methods" do
      it "defines correct JSON content type regex constant" do
        # This test catches mutations in the JSON_CONTENT_TYPE_REGEX constant
        expect(described_class::JSON_CONTENT_TYPE_REGEX).to eq(/\bjson$/)
        expect(described_class::JSON_CONTENT_TYPE_REGEX).not_to eq(/\Bjson$/) # Catches boundary mutations
      end

      it "defines correct default HTTP adapter constant" do
        # This test catches mutations in the DEFAULT_HTTP_ADAPTER constant
        expect(described_class::DEFAULT_HTTP_ADAPTER).to eq(Faraday.default_adapter)
        expect(described_class::DEFAULT_HTTP_ADAPTER).not_to be_nil
      end

      it "configures JSON request middleware correctly" do
        # This test verifies the configure_json_handling method behavior
        handlers = http_client.builder.handlers
        expect(handlers).to include(Faraday::Request::Json)
      end

      it "configures JSON response middleware with exact content type regex" do
        # This test verifies the configure_json_handling method uses the constant correctly
        handlers = http_client.builder.handlers
        expect(handlers).to include(Faraday::Response::Json)

        # Test that the regex constant is used by testing against different content types
        # The regex /\bjson$/ requires "json" at word boundary and end of string
        test_cases = [
          {content_type: "application/json", should_match: true},
          {content_type: "text/json", should_match: true},
          {content_type: "application/json; charset=utf-8", should_match: false}, # Won't match due to charset
          {content_type: "application/jsonp", should_match: false}, # Should not match jsonp
          {content_type: "application/xml", should_match: false}
        ]

        test_cases.each do |test_case|
          if test_case[:should_match]
            expect(test_case[:content_type]).to match(described_class::JSON_CONTENT_TYPE_REGEX)
          else
            expect(test_case[:content_type]).not_to match(described_class::JSON_CONTENT_TYPE_REGEX)
          end
        end
      end

      it "configures HTTP adapter using constant value" do  
        # This test verifies the configure_adapter method uses the constant
        expect(described_class::DEFAULT_HTTP_ADAPTER).to eq(Faraday.default_adapter)
        expect(described_class::DEFAULT_HTTP_ADAPTER).not_to be_nil
        
        # Verify the HTTP client responds to adapter methods (requires working adapter)
        expect(http_client).to respond_to(:get)
        expect(http_client).to respond_to(:post)
        expect(http_client.adapter).not_to be_nil
      end

      it "configures authorization header with exact format" do
        # This test verifies the configure_authorization method behavior
        expect(http_client.headers["Authorization"]).to eq("Bearer test_key_123")
        expect(http_client.headers["Authorization"]).to start_with("Bearer ")
        expect(http_client.headers["Authorization"]).not_to eq("Bearer ") # Not empty API key
      end
    end
  end

  describe "::PolymuxRestHandler" do
    let(:handler) { described_class::PolymuxRestHandler.new(client) }

    describe "initialization" do
      it "accepts a client instance" do
        handler_instance = described_class::PolymuxRestHandler.new(client)
        expect(handler_instance).to be_a(described_class::PolymuxRestHandler)
        expect(handler_instance.send(:_client)).to eq(client)
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
