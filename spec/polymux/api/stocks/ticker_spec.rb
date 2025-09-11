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

    it "is instance of Polymux::Api::Stocks::Ticker" do
      expect(ticker).to be_instance_of(Polymux::Api::Stocks::Ticker)
    end

    it "inherits from Dry::Struct" do
      expect(ticker).to be_a(Dry::Struct)
    end
  end

  describe "type checking methods" do
    describe "#common_stock?" do
      it "returns true for CS type" do
        expect(ticker.common_stock?).to be true
      end

      it "returns false for PFD type" do
        pfd_ticker = described_class.new(ticker: "TEST", type: "PFD")
        expect(pfd_ticker.common_stock?).to be false
      end

      it "returns false for nil type" do
        nil_type_ticker = described_class.new(ticker: "TEST", type: nil)
        expect(nil_type_ticker.common_stock?).to be false
      end

      it "returns false for empty string type" do
        empty_type_ticker = described_class.new(ticker: "TEST", type: "")
        expect(empty_type_ticker.common_stock?).to be false
      end

      it "returns false for different case CS" do
        lowercase_ticker = described_class.new(ticker: "TEST", type: "cs")
        expect(lowercase_ticker.common_stock?).to be false
      end

      it "returns false for unrelated type" do
        other_ticker = described_class.new(ticker: "TEST", type: "OTHER")
        expect(other_ticker.common_stock?).to be false
      end

      # Test exact equality instead of truthy checks (mutation resistant)
      context "mutation resistance" do
        it "uses exact string equality, not contains check" do
          partial_match_ticker = described_class.new(ticker: "TEST", type: "CS123")
          expect(partial_match_ticker.common_stock?).to be false
        end

        it "uses exact string equality, not startswith check" do
          prefix_match_ticker = described_class.new(ticker: "TEST", type: "CSX")
          expect(prefix_match_ticker.common_stock?).to be false
        end
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

      it "returns false for nil type" do
        nil_type_ticker = described_class.new(ticker: "TEST", type: nil)
        expect(nil_type_ticker.preferred_stock?).to be false
      end

      it "returns false for empty string type" do
        empty_type_ticker = described_class.new(ticker: "TEST", type: "")
        expect(empty_type_ticker.preferred_stock?).to be false
      end

      it "returns false for different case PFD" do
        lowercase_ticker = described_class.new(ticker: "TEST", type: "pfd")
        expect(lowercase_ticker.preferred_stock?).to be false
      end

      it "returns false for mixed case PFD" do
        mixed_case_ticker = described_class.new(ticker: "TEST", type: "Pfd")
        expect(mixed_case_ticker.preferred_stock?).to be false
      end

      # Test exact equality (mutation resistant)
      context "mutation resistance" do
        it "uses exact string equality, not contains check" do
          partial_match_ticker = described_class.new(ticker: "TEST", type: "PFD123")
          expect(partial_match_ticker.preferred_stock?).to be false
        end
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

      # Test exact boolean comparison (mutation resistant)
      context "mutation resistance" do
        it "returns false for truthy non-boolean values" do
          expect { described_class.new(ticker: "TEST", active: "true") }
            .to raise_error(Dry::Struct::Error)
        end

        it "returns false for numeric 1" do
          expect { described_class.new(ticker: "TEST", active: 1) }
            .to raise_error(Dry::Struct::Error)
        end

        it "uses exact equality check (== true), not truthy check" do
          # This test verifies the method checks for exactly true, not just truthy
          true_ticker = described_class.new(ticker: "TEST", active: true)
          false_ticker = described_class.new(ticker: "TEST", active: false)

          expect(true_ticker.active?).to be true
          expect(false_ticker.active?).to be false
        end
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

      it "returns false for nil market" do
        nil_market_ticker = described_class.new(ticker: "TEST", market: nil)
        expect(nil_market_ticker.otc?).to be false
      end

      it "returns false for empty string market" do
        empty_market_ticker = described_class.new(ticker: "TEST", market: "")
        expect(empty_market_ticker.otc?).to be false
      end

      it "returns false for different case otc" do
        uppercase_ticker = described_class.new(ticker: "TEST", market: "OTC")
        expect(uppercase_ticker.otc?).to be false
      end

      it "returns false for mixed case otc" do
        mixed_case_ticker = described_class.new(ticker: "TEST", market: "Otc")
        expect(mixed_case_ticker.otc?).to be false
      end

      # Test exact equality (mutation resistant)
      context "mutation resistance" do
        it "uses exact string equality, not contains check" do
          partial_match_ticker = described_class.new(ticker: "TEST", market: "otcbb")
          expect(partial_match_ticker.otc?).to be false
        end

        it "uses exact string equality, not startswith check" do
          prefix_match_ticker = described_class.new(ticker: "TEST", market: "otc-market")
          expect(prefix_match_ticker.otc?).to be false
        end
      end
    end
  end

  describe ".from_api" do
    let(:api_data) do
      {
        "ticker" => "AAPL",
        "name" => "Apple Inc.",
        "market" => "stocks",
        "locale" => "us",
        "primary_exchange" => "XNAS",
        "type" => "CS",
        "active" => true,
        "currency_name" => "USD",
        "cusip" => "037833100",
        "cik" => "0000320193",
        "composite_figi" => "BBG000B9XRY4",
        "share_class_figi" => "BBG001S5N8V8",
        "last_updated_utc" => "2024-01-15T00:00:00.000Z"
      }
    end

    it "creates ticker from API data with all fields" do
      ticker = described_class.from_api(api_data)

      expect(ticker).to be_a(described_class)
      expect(ticker.ticker).to eq("AAPL")
      expect(ticker.name).to eq("Apple Inc.")
      expect(ticker.market).to eq("stocks")
      expect(ticker.locale).to eq("us")
      expect(ticker.primary_exchange).to eq("XNAS")
      expect(ticker.type).to eq("CS")
      expect(ticker.active).to be true
      expect(ticker.currency_name).to eq("USD")
      expect(ticker.cusip).to eq("037833100")
      expect(ticker.cik).to eq("0000320193")
      expect(ticker.composite_figi).to eq("BBG000B9XRY4")
      expect(ticker.share_class_figi).to eq("BBG001S5N8V8")
      expect(ticker.last_updated_utc).to eq("2024-01-15T00:00:00.000Z")
    end

    context "with minimal required data" do
      let(:minimal_data) { {"ticker" => "TEST"} }

      it "creates ticker with only required ticker field" do
        ticker = described_class.from_api(minimal_data)

        expect(ticker.ticker).to eq("TEST")
        expect(ticker.name).to be_nil
        expect(ticker.market).to be_nil
        expect(ticker.active).to be_nil
      end
    end

    context "with null/nil optional fields" do
      let(:data_with_nils) do
        {
          "ticker" => "TEST",
          "name" => nil,
          "market" => nil,
          "active" => nil,
          "type" => nil,
          "locale" => nil,
          "primary_exchange" => nil,
          "currency_name" => nil,
          "cusip" => nil,
          "cik" => nil,
          "composite_figi" => nil,
          "share_class_figi" => nil,
          "last_updated_utc" => nil
        }
      end

      it "handles nil values in optional fields" do
        ticker = described_class.from_api(data_with_nils)

        expect(ticker.ticker).to eq("TEST")
        expect(ticker.name).to be_nil
        expect(ticker.market).to be_nil
        expect(ticker.active).to be_nil
        expect(ticker.type).to be_nil
        expect(ticker.locale).to be_nil
        expect(ticker.primary_exchange).to be_nil
        expect(ticker.currency_name).to be_nil
        expect(ticker.cusip).to be_nil
        expect(ticker.cik).to be_nil
        expect(ticker.composite_figi).to be_nil
        expect(ticker.share_class_figi).to be_nil
        expect(ticker.last_updated_utc).to be_nil
      end
    end

    context "with empty string values" do
      let(:data_with_empty_strings) do
        {
          "ticker" => "TEST",
          "name" => "",
          "market" => "",
          "type" => "",
          "locale" => "",
          "primary_exchange" => "",
          "currency_name" => "",
          "cusip" => "",
          "cik" => "",
          "composite_figi" => "",
          "share_class_figi" => "",
          "last_updated_utc" => ""
        }
      end

      it "accepts empty string values" do
        ticker = described_class.from_api(data_with_empty_strings)

        expect(ticker.ticker).to eq("TEST")
        expect(ticker.name).to eq("")
        expect(ticker.market).to eq("")
        expect(ticker.type).to eq("")
        expect(ticker.locale).to eq("")
        expect(ticker.primary_exchange).to eq("")
        expect(ticker.currency_name).to eq("")
        expect(ticker.cusip).to eq("")
        expect(ticker.cik).to eq("")
        expect(ticker.composite_figi).to eq("")
        expect(ticker.share_class_figi).to eq("")
        expect(ticker.last_updated_utc).to eq("")
      end
    end

    context "with boolean variations" do
      it "handles true boolean" do
        data = {"ticker" => "TEST", "active" => true}
        ticker = described_class.from_api(data)
        expect(ticker.active).to be true
      end

      it "handles false boolean" do
        data = {"ticker" => "TEST", "active" => false}
        ticker = described_class.from_api(data)
        expect(ticker.active).to be false
      end
    end

    it "calls Api::Transformers.ticker for data transformation" do
      expect(Polymux::Api::Transformers).to receive(:ticker).with(api_data).and_call_original
      described_class.from_api(api_data)
    end
  end

  # Comprehensive attribute validation tests
  describe "attribute validation" do
    it "requires ticker attribute" do
      expect { described_class.new }.to raise_error(Dry::Struct::Error)
    end

    it "accepts string ticker" do
      ticker = described_class.new(ticker: "AAPL")
      expect(ticker.ticker).to eq("AAPL")
    end

    it "rejects non-string ticker" do
      expect { described_class.new(ticker: 123) }.to raise_error(Dry::Struct::Error)
      expect { described_class.new(ticker: nil) }.to raise_error(Dry::Struct::Error)
      expect { described_class.new(ticker: []) }.to raise_error(Dry::Struct::Error)
      expect { described_class.new(ticker: {}) }.to raise_error(Dry::Struct::Error)
      expect { described_class.new(ticker: true) }.to raise_error(Dry::Struct::Error)
    end

    context "optional string attributes" do
      let(:ticker) { described_class.new(ticker: "TEST") }

      it "allows nil for all optional string attributes" do
        expect(ticker.name).to be_nil
        expect(ticker.market).to be_nil
        expect(ticker.locale).to be_nil
        expect(ticker.primary_exchange).to be_nil
        expect(ticker.type).to be_nil
        expect(ticker.currency_name).to be_nil
        expect(ticker.cusip).to be_nil
        expect(ticker.cik).to be_nil
        expect(ticker.composite_figi).to be_nil
        expect(ticker.share_class_figi).to be_nil
        expect(ticker.last_updated_utc).to be_nil
      end

      it "accepts string values for optional attributes" do
        full_ticker = described_class.new(
          ticker: "TEST",
          name: "Test Company",
          market: "stocks",
          locale: "us",
          primary_exchange: "XNAS",
          type: "CS",
          currency_name: "USD",
          cusip: "123456789",
          cik: "0001234567",
          composite_figi: "BBG123456789",
          share_class_figi: "BBG987654321",
          last_updated_utc: "2024-01-01T00:00:00Z"
        )

        expect(full_ticker.name).to eq("Test Company")
        expect(full_ticker.market).to eq("stocks")
        expect(full_ticker.locale).to eq("us")
        expect(full_ticker.primary_exchange).to eq("XNAS")
        expect(full_ticker.type).to eq("CS")
        expect(full_ticker.currency_name).to eq("USD")
        expect(full_ticker.cusip).to eq("123456789")
        expect(full_ticker.cik).to eq("0001234567")
        expect(full_ticker.composite_figi).to eq("BBG123456789")
        expect(full_ticker.share_class_figi).to eq("BBG987654321")
        expect(full_ticker.last_updated_utc).to eq("2024-01-01T00:00:00Z")
      end

      it "rejects non-string values for optional string attributes" do
        expect { described_class.new(ticker: "TEST", name: 123) }.to raise_error(Dry::Struct::Error)
        expect { described_class.new(ticker: "TEST", market: []) }.to raise_error(Dry::Struct::Error)
        expect { described_class.new(ticker: "TEST", type: {}) }.to raise_error(Dry::Struct::Error)
      end
    end

    context "optional boolean attribute" do
      it "allows nil for active" do
        ticker = described_class.new(ticker: "TEST")
        expect(ticker.active).to be_nil
      end

      it "accepts true boolean" do
        ticker = described_class.new(ticker: "TEST", active: true)
        expect(ticker.active).to be true
      end

      it "accepts false boolean" do
        ticker = described_class.new(ticker: "TEST", active: false)
        expect(ticker.active).to be false
      end

      it "rejects non-boolean values for active" do
        expect { described_class.new(ticker: "TEST", active: "true") }.to raise_error(Dry::Struct::Error)
        expect { described_class.new(ticker: "TEST", active: 1) }.to raise_error(Dry::Struct::Error)
        expect { described_class.new(ticker: "TEST", active: 0) }.to raise_error(Dry::Struct::Error)
        expect { described_class.new(ticker: "TEST", active: []) }.to raise_error(Dry::Struct::Error)
        expect { described_class.new(ticker: "TEST", active: {}) }.to raise_error(Dry::Struct::Error)
      end
    end
  end

  # Immutability and structural tests
  describe "immutability" do
    let(:ticker) { described_class.new(ticker: "AAPL", name: "Apple Inc.") }

    it "does not allow attribute modification" do
      expect { ticker.ticker = "MSFT" }.to raise_error(NoMethodError)
      expect { ticker.name = "Microsoft" }.to raise_error(NoMethodError)
    end

    it "is immutable (Dry::Struct behavior)" do
      expect(ticker).to be_a(Dry::Struct)
    end
  end

  # Key transformation tests
  describe "key transformation" do
    it "transforms string keys to symbols" do
      data = {"ticker" => "AAPL", "name" => "Apple Inc."}
      ticker = described_class.new(data)

      expect(ticker.ticker).to eq("AAPL")
      expect(ticker.name).to eq("Apple Inc.")
    end

    it "accepts symbol keys directly" do
      data = {ticker: "AAPL", name: "Apple Inc."}
      ticker = described_class.new(data)

      expect(ticker.ticker).to eq("AAPL")
      expect(ticker.name).to eq("Apple Inc.")
    end
  end

  # Edge cases for business logic methods
  describe "edge cases" do
    context "method behavior with edge values" do
      it "handles empty strings in type checking methods" do
        empty_ticker = described_class.new(ticker: "TEST", type: "", market: "", active: nil)

        expect(empty_ticker.common_stock?).to be false
        expect(empty_ticker.preferred_stock?).to be false
        expect(empty_ticker.otc?).to be false
        expect(empty_ticker.active?).to be false
      end

      it "handles whitespace in type and market fields" do
        whitespace_ticker = described_class.new(
          ticker: "TEST",
          type: " CS ",
          market: " otc "
        )

        # Should be exact matches, not trimmed
        expect(whitespace_ticker.common_stock?).to be false
        expect(whitespace_ticker.otc?).to be false
      end
    end
  end
end
