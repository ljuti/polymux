# frozen_string_literal: true

require "spec_helper"

RSpec.describe Polymux::Api::Stocks::Ticker do
  let(:ticker_data) do
    {
      ticker: "AAPL",
      name: "Apple Inc.",
      market: "stocks",
      locale: "us",
      primary_exchange: "XNAS",
      type: "CS",
      active: true,
      currency_name: "usd",
      cik: "0000320193",
      composite_figi: "BBG000B9XRY4",
      share_class_figi: "BBG001S5N8V8",
      last_updated_utc: "2024-08-15T00:00:00Z"
    }
  end

  let(:ticker) { described_class.new(ticker_data) }

  describe "initialization" do
    it "creates a ticker with all attributes" do
      expect(ticker.ticker).to eq("AAPL")
      expect(ticker.name).to eq("Apple Inc.")
      expect(ticker.market).to eq("stocks")
      expect(ticker.locale).to eq("us")
      expect(ticker.primary_exchange).to eq("XNAS")
      expect(ticker.type).to eq("CS")
      expect(ticker.active).to be true
      expect(ticker.currency_name).to eq("usd")
      expect(ticker.cik).to eq("0000320193")
      expect(ticker.composite_figi).to eq("BBG000B9XRY4")
    end

    it "handles optional attributes" do
      minimal_ticker = described_class.new(ticker: "TEST")
      expect(minimal_ticker.ticker).to eq("TEST")
      expect(minimal_ticker.name).to be_nil
      expect(minimal_ticker.market).to be_nil
    end
  end

  describe "type checking methods" do
    describe "#common_stock?" do
      it "returns true for CS type" do
        expect(ticker.common_stock?).to be true
      end

      it "returns false for non-CS type" do
        pfd_ticker = described_class.new(ticker: "TEST", type: "PFD")
        expect(pfd_ticker.common_stock?).to be false
      end
    end

    describe "#preferred_stock?" do
      it "returns true for PFD type" do
        pfd_ticker = described_class.new(ticker: "TEST", type: "PFD")
        expect(pfd_ticker.preferred_stock?).to be true
      end

      it "returns false for CS type" do
        expect(ticker.preferred_stock?).to be false
      end
    end

    describe "#active?" do
      it "returns true when active is true" do
        expect(ticker.active?).to be true
      end

      it "returns false when active is false" do
        inactive_ticker = described_class.new(ticker: "TEST", active: false)
        expect(inactive_ticker.active?).to be false
      end

      it "returns false when active is nil" do
        nil_ticker = described_class.new(ticker: "TEST", active: nil)
        expect(nil_ticker.active?).to be false
      end
    end

    describe "#otc?" do
      it "returns true for otc market" do
        otc_ticker = described_class.new(ticker: "TEST", market: "otc")
        expect(otc_ticker.otc?).to be true
      end

      it "returns false for stocks market" do
        expect(ticker.otc?).to be false
      end
    end
  end

  describe ".from_api" do
    let(:api_data) do
      {
        "ticker" => "AAPL",
        "name" => "Apple Inc.",
        "market" => "stocks",
        "type" => "CS",
        "active" => true
      }
    end

    it "creates ticker from API data" do
      ticker = described_class.from_api(api_data)

      expect(ticker).to be_a(described_class)
      expect(ticker.ticker).to eq("AAPL")
      expect(ticker.name).to eq("Apple Inc.")
      expect(ticker.market).to eq("stocks")
      expect(ticker.type).to eq("CS")
      expect(ticker.active).to be true
    end
  end
end
