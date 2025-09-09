# frozen_string_literal: true

require "spec_helper"

RSpec.describe Polymux::Api::Exchanges do
  let(:config) { Polymux::Config.new(api_key: "test_key_123", base_url: "https://api.polygon.io") }
  let(:client) { Polymux::Client.new(config) }
  let(:exchanges_api) { described_class.new(client) }

  describe "inheritance" do
    it "inherits from PolymuxRestHandler" do
      expect(described_class.superclass).to eq(Polymux::Client::PolymuxRestHandler)
    end

    it "has access to the parent client" do
      expect(exchanges_api.send(:_client)).to eq(client)
    end
  end

  describe "#list" do
    before do
      stub_request(:get, "https://api.polygon.io/v3/reference/exchanges")
        .with(headers: {"Authorization" => "Bearer test_key_123"})
        .to_return(
          status: 200,
          body: load_fixture("exchanges"),
          headers: {"Content-Type" => "application/json"}
        )
    end

    it "makes GET request to exchanges endpoint" do
      exchanges_api.list

      expect(a_request(:get, "https://api.polygon.io/v3/reference/exchanges"))
        .to have_been_made.once
    end

    it "returns an array of Exchange objects" do
      exchanges = exchanges_api.list

      expect(exchanges).to be_an(Array)
      expect(exchanges.length).to eq(3)
      expect(exchanges).to all(be_a(described_class::Exchange))
    end

    it "transforms API data correctly" do
      exchanges = exchanges_api.list
      nyse_exchange = exchanges.find { |e| e.name == "New York Stock Exchange" }

      expect(nyse_exchange.name).to eq("New York Stock Exchange")
      expect(nyse_exchange.mic).to eq("XNYS")
      expect(nyse_exchange.operating_mic).to eq("XNYS")
      expect(nyse_exchange.asset_class).to eq("stocks")
      expect(nyse_exchange.url).to eq("https://www.nyse.com")
    end

    it "includes different asset classes" do
      exchanges = exchanges_api.list
      asset_classes = exchanges.map(&:asset_class)

      expect(asset_classes).to include("stocks", "options")
    end
  end

  describe "::Exchange" do
    let(:exchange_data) do
      {
        name: "Chicago Board Options Exchange",
        mic: "XCBO",
        operating_mic: "XCBO",
        asset_class: "options",
        url: "https://www.cboe.com"
      }
    end
    let(:exchange) { described_class::Exchange.new(exchange_data) }

    describe "initialization" do
      it "accepts exchange data hash" do
        exchange_instance = described_class::Exchange.new(exchange_data)
        expect(exchange_instance).to be_a(described_class::Exchange)
        expect(exchange_instance.name).to eq("Chicago Board Options Exchange")
      end

      it "transforms keys to symbols" do
        expect(exchange.name).to eq("Chicago Board Options Exchange")
        expect(exchange.mic).to eq("XCBO")
        expect(exchange.operating_mic).to eq("XCBO")
        expect(exchange.asset_class).to eq("options")
        expect(exchange.url).to eq("https://www.cboe.com")
      end
    end

    describe "required attributes" do
      it "requires name attribute" do
        expect(exchange.name).to eq("Chicago Board Options Exchange")
      end

      it "requires asset_class attribute" do
        expect(exchange.asset_class).to eq("options")
      end
    end

    describe "optional attributes" do
      it "allows optional mic attribute" do
        exchange_without_mic = described_class::Exchange.new(
          name: "Test Exchange",
          asset_class: "stocks"
        )

        expect(exchange_without_mic.mic).to be_nil
        expect(exchange_without_mic.operating_mic).to be_nil
        expect(exchange_without_mic.url).to be_nil
      end
    end

    describe "#stocks?" do
      it "returns true when asset_class is stocks" do
        stocks_exchange = described_class::Exchange.new(
          name: "NYSE",
          asset_class: "stocks"
        )

        expect(stocks_exchange.stocks?).to be true
      end

      it "returns false when asset_class is not stocks" do
        expect(exchange.stocks?).to be false
      end
    end

    describe "#options?" do
      it "returns true when asset_class is options" do
        expect(exchange.options?).to be true
      end

      it "returns false when asset_class is not options" do
        stocks_exchange = described_class::Exchange.new(
          name: "NYSE",
          asset_class: "stocks"
        )

        expect(stocks_exchange.options?).to be false
      end
    end

    describe "#futures?" do
      it "returns true when asset_class is futures" do
        futures_exchange = described_class::Exchange.new(
          name: "CME",
          asset_class: "futures"
        )

        expect(futures_exchange.futures?).to be true
      end

      it "returns false when asset_class is not futures" do
        expect(exchange.futures?).to be false
      end
    end

    describe "#forex?" do
      it "returns true when asset_class is fx" do
        forex_exchange = described_class::Exchange.new(
          name: "FXCM",
          asset_class: "fx"
        )

        expect(forex_exchange.forex?).to be true
      end

      it "returns false when asset_class is not fx" do
        expect(exchange.forex?).to be false
      end
    end

    describe "comprehensive asset class testing" do
      let(:test_cases) do
        [
          {asset_class: "stocks", method: :stocks?, expected: true},
          {asset_class: "options", method: :options?, expected: true},
          {asset_class: "futures", method: :futures?, expected: true},
          {asset_class: "fx", method: :forex?, expected: true}
        ]
      end

      it "correctly identifies each asset class" do
        test_cases.each do |test_case|
          exchange = described_class::Exchange.new(
            name: "Test Exchange",
            asset_class: test_case[:asset_class]
          )

          expect(exchange.send(test_case[:method])).to eq(test_case[:expected])

          # Verify other methods return false
          other_methods = [:stocks?, :options?, :futures?, :forex?] - [test_case[:method]]
          other_methods.each do |method|
            expect(exchange.send(method)).to be false
          end
        end
      end
    end

    context "with nullable attributes" do
      let(:minimal_exchange) do
        described_class::Exchange.new(
          name: "Minimal Exchange",
          asset_class: "stocks"
        )
      end

      it "handles nil values for optional attributes" do
        expect(minimal_exchange.mic).to be_nil
        expect(minimal_exchange.operating_mic).to be_nil
        expect(minimal_exchange.url).to be_nil
      end

      it "still functions correctly with minimal data" do
        expect(minimal_exchange.name).to eq("Minimal Exchange")
        expect(minimal_exchange.asset_class).to eq("stocks")
        expect(minimal_exchange.stocks?).to be true
      end
    end
  end
end
