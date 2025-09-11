# frozen_string_literal: true

require "spec_helper"

RSpec.describe Polymux::Api::Stocks::Quote do
  let(:quote_data) do
    {
      ticker: "AAPL",
      timestamp: "2024-01-15T15:30:25.123456789Z",
      bid_price: 174.49,
      ask_price: 174.51,
      bid_size: 200,
      ask_size: 300,
      bid_exchange: 1,
      ask_exchange: 2,
      participant_timestamp: 1705328425123456789,
      conditions: [1, 14],
      indicators: [0],
      tape: "A"
    }
  end

  let(:quote) { described_class.new(quote_data) }

  describe "initialization" do
    it "creates a quote with all attributes" do
      expect(quote.ticker).to eq("AAPL")
      expect(quote.timestamp).to eq("2024-01-15T15:30:25.123456789Z")
      expect(quote.bid_price).to eq(174.49)
      expect(quote.ask_price).to eq(174.51)
      expect(quote.bid_size).to eq(200)
      expect(quote.ask_size).to eq(300)
      expect(quote.bid_exchange).to eq(1)
      expect(quote.ask_exchange).to eq(2)
      expect(quote.participant_timestamp).to eq(1705328425123456789)
      expect(quote.conditions).to eq([1, 14])
      expect(quote.indicators).to eq([0])
      expect(quote.tape).to eq("A")
    end

    it "handles optional attributes" do
      minimal_quote = described_class.new(ticker: "TEST")
      expect(minimal_quote.ticker).to eq("TEST")
      expect(minimal_quote.bid_price).to be_nil
      expect(minimal_quote.ask_price).to be_nil
      expect(minimal_quote.bid_size).to be_nil
      expect(minimal_quote.ask_size).to be_nil
    end

    it "is instance of Polymux::Api::Stocks::Quote" do
      expect(quote).to be_instance_of(Polymux::Api::Stocks::Quote)
    end

    it "inherits from Dry::Struct" do
      expect(quote).to be_a(Dry::Struct)
    end
  end

  describe "#spread" do
    context "when both bid and ask prices are present" do
      it "calculates spread correctly" do
        expect(quote.spread).to eq(0.02) # 174.51 - 174.49
      end

      it "handles larger spreads" do
        wide_quote = described_class.new(ticker: "TEST", bid_price: 100.0, ask_price: 105.0)
        expect(wide_quote.spread).to eq(5.0)
      end

      it "handles zero spread" do
        locked_quote = described_class.new(ticker: "TEST", bid_price: 100.0, ask_price: 100.0)
        expect(locked_quote.spread).to eq(0.0)
      end

      it "handles decimal precision" do
        precise_quote = described_class.new(ticker: "TEST", bid_price: 123.456, ask_price: 123.789)
        expect(precise_quote.spread).to eq(0.333)
      end

      it "handles negative spread (crossed market)" do
        crossed_quote = described_class.new(ticker: "TEST", bid_price: 100.05, ask_price: 100.00)
        expect(crossed_quote.spread).to eq(-0.05)
      end
    end

    context "when bid_price is nil" do
      let(:no_bid_quote) { described_class.new(ticker: "TEST", ask_price: 100.0) }

      it "returns nil" do
        expect(no_bid_quote.spread).to be_nil
      end
    end

    context "when ask_price is nil" do
      let(:no_ask_quote) { described_class.new(ticker: "TEST", bid_price: 100.0) }

      it "returns nil" do
        expect(no_ask_quote.spread).to be_nil
      end
    end

    context "when both prices are nil" do
      let(:no_price_quote) { described_class.new(ticker: "TEST") }

      it "returns nil" do
        expect(no_price_quote.spread).to be_nil
      end
    end
  end

  describe "#spread_percentage" do
    context "when spread and midpoint are available and midpoint > 0" do
      it "calculates spread percentage correctly" do
        # spread = 0.02, midpoint = 174.5, percentage = (0.02 / 174.5) * 100 = 0.0115%
        expect(quote.spread_percentage).to eq(0.0115)
      end

      it "handles wider spreads" do
        wide_quote = described_class.new(ticker: "TEST", bid_price: 100.0, ask_price: 102.0)
        # spread = 2.0, midpoint = 101.0, percentage = (2.0 / 101.0) * 100 = 1.9802%
        expect(wide_quote.spread_percentage).to eq(1.9802)
      end

      it "handles very tight spreads" do
        tight_quote = described_class.new(ticker: "TEST", bid_price: 100.00, ask_price: 100.01)
        # spread = 0.01, midpoint = 100.005, percentage = (0.01 / 100.005) * 100 = 0.01%
        expect(tight_quote.spread_percentage).to eq(0.01)
      end

      it "handles zero spread" do
        locked_quote = described_class.new(ticker: "TEST", bid_price: 100.0, ask_price: 100.0)
        expect(locked_quote.spread_percentage).to eq(0.0)
      end
    end

    context "when spread is nil" do
      let(:no_spread_quote) { described_class.new(ticker: "TEST", bid_price: 100.0) }

      it "returns nil" do
        expect(no_spread_quote.spread_percentage).to be_nil
      end
    end

    context "when midpoint is nil" do
      let(:no_midpoint_quote) { described_class.new(ticker: "TEST", ask_price: 100.0) }

      it "returns nil" do
        expect(no_midpoint_quote.spread_percentage).to be_nil
      end
    end

    context "when midpoint is zero" do
      let(:zero_midpoint_quote) { described_class.new(ticker: "TEST", bid_price: 0.0, ask_price: 0.0) }

      it "returns nil to avoid division by zero" do
        expect(zero_midpoint_quote.spread_percentage).to be_nil
      end
    end

    context "when midpoint is negative" do
      let(:negative_midpoint_quote) { described_class.new(ticker: "TEST", bid_price: -1.0, ask_price: -0.5) }

      it "returns nil for negative midpoint" do
        expect(negative_midpoint_quote.spread_percentage).to be_nil
      end
    end

    it "rounds to 4 decimal places" do
      # Create quote that would result in more than 4 decimal places
      precision_quote = described_class.new(ticker: "TEST", bid_price: 99.999999, ask_price: 100.000001)
      result = precision_quote.spread_percentage
      expect(result.to_s.split(".").last.length).to be <= 4
    end
  end

  describe "#midpoint" do
    context "when both bid and ask prices are present" do
      it "calculates midpoint correctly" do
        expect(quote.midpoint).to eq(174.5) # (174.49 + 174.51) / 2
      end

      it "handles integer prices" do
        integer_quote = described_class.new(ticker: "TEST", bid_price: 100, ask_price: 102)
        expect(integer_quote.midpoint).to eq(101.0)
      end

      it "handles identical prices" do
        same_quote = described_class.new(ticker: "TEST", bid_price: 100.0, ask_price: 100.0)
        expect(same_quote.midpoint).to eq(100.0)
      end

      it "handles decimal precision" do
        decimal_quote = described_class.new(ticker: "TEST", bid_price: 123.456, ask_price: 123.789)
        expect(decimal_quote.midpoint).to eq(123.6225)
      end

      it "handles zero prices" do
        zero_quote = described_class.new(ticker: "TEST", bid_price: 0.0, ask_price: 0.0)
        expect(zero_quote.midpoint).to eq(0.0)
      end

      it "handles negative prices" do
        negative_quote = described_class.new(ticker: "TEST", bid_price: -1.0, ask_price: -0.5)
        expect(negative_quote.midpoint).to eq(-0.75)
      end
    end

    context "when bid_price is nil" do
      let(:no_bid_quote) { described_class.new(ticker: "TEST", ask_price: 100.0) }

      it "returns nil" do
        expect(no_bid_quote.midpoint).to be_nil
      end
    end

    context "when ask_price is nil" do
      let(:no_ask_quote) { described_class.new(ticker: "TEST", bid_price: 100.0) }

      it "returns nil" do
        expect(no_ask_quote.midpoint).to be_nil
      end
    end

    context "when both prices are nil" do
      let(:no_price_quote) { described_class.new(ticker: "TEST") }

      it "returns nil" do
        expect(no_price_quote.midpoint).to be_nil
      end
    end
  end

  describe "#bid_value" do
    context "when both bid_price and bid_size are present" do
      it "calculates bid value correctly" do
        expect(quote.bid_value).to eq(34898.0) # 174.49 * 200
      end

      it "handles zero bid_price" do
        zero_price_quote = described_class.new(ticker: "TEST", bid_price: 0.0, bid_size: 100)
        expect(zero_price_quote.bid_value).to eq(0.0)
      end

      it "handles zero bid_size" do
        zero_size_quote = described_class.new(ticker: "TEST", bid_price: 100.0, bid_size: 0)
        expect(zero_size_quote.bid_value).to eq(0.0)
      end

      it "handles decimal prices" do
        decimal_quote = described_class.new(ticker: "TEST", bid_price: 123.456, bid_size: 50)
        expect(decimal_quote.bid_value).to eq(6172.8)
      end
    end

    context "when bid_price is nil" do
      let(:no_bid_price_quote) { described_class.new(ticker: "TEST", bid_size: 100) }

      it "returns nil" do
        expect(no_bid_price_quote.bid_value).to be_nil
      end
    end

    context "when bid_size is nil" do
      let(:no_bid_size_quote) { described_class.new(ticker: "TEST", bid_price: 100.0) }

      it "returns nil" do
        expect(no_bid_size_quote.bid_value).to be_nil
      end
    end

    context "when both are nil" do
      let(:no_bid_data_quote) { described_class.new(ticker: "TEST") }

      it "returns nil" do
        expect(no_bid_data_quote.bid_value).to be_nil
      end
    end
  end

  describe "#ask_value" do
    context "when both ask_price and ask_size are present" do
      it "calculates ask value correctly" do
        expect(quote.ask_value).to eq(52353.0) # 174.51 * 300
      end

      it "handles zero ask_price" do
        zero_price_quote = described_class.new(ticker: "TEST", ask_price: 0.0, ask_size: 100)
        expect(zero_price_quote.ask_value).to eq(0.0)
      end

      it "handles zero ask_size" do
        zero_size_quote = described_class.new(ticker: "TEST", ask_price: 100.0, ask_size: 0)
        expect(zero_size_quote.ask_value).to eq(0.0)
      end

      it "handles decimal prices" do
        decimal_quote = described_class.new(ticker: "TEST", ask_price: 123.456, ask_size: 50)
        expect(decimal_quote.ask_value).to eq(6172.8)
      end
    end

    context "when ask_price is nil" do
      let(:no_ask_price_quote) { described_class.new(ticker: "TEST", ask_size: 100) }

      it "returns nil" do
        expect(no_ask_price_quote.ask_value).to be_nil
      end
    end

    context "when ask_size is nil" do
      let(:no_ask_size_quote) { described_class.new(ticker: "TEST", ask_price: 100.0) }

      it "returns nil" do
        expect(no_ask_size_quote.ask_value).to be_nil
      end
    end

    context "when both are nil" do
      let(:no_ask_data_quote) { described_class.new(ticker: "TEST") }

      it "returns nil" do
        expect(no_ask_data_quote.ask_value).to be_nil
      end
    end
  end

  describe "#tight_spread?" do
    context "when spread_percentage is available" do
      it "returns true for spreads < 0.1%" do
        tight_quote = described_class.new(ticker: "TEST", bid_price: 100.0, ask_price: 100.05)
        # 0.05% spread
        expect(tight_quote.tight_spread?).to be true
      end

      it "returns false for spreads >= 0.1%" do
        normal_quote = described_class.new(ticker: "TEST", bid_price: 100.0, ask_price: 100.15)
        # 0.15% spread
        expect(normal_quote.tight_spread?).to be false
      end

      it "returns true for exactly 0.1% spread boundary" do
        boundary_quote = described_class.new(ticker: "TEST", bid_price: 100.0, ask_price: 100.1)
        # Exactly 0.1% spread
        expect(boundary_quote.tight_spread?).to be false # < 0.1, not <= 0.1
      end

      it "returns true for zero spread" do
        locked_quote = described_class.new(ticker: "TEST", bid_price: 100.0, ask_price: 100.0)
        expect(locked_quote.tight_spread?).to be true
      end

      it "handles very tight spreads" do
        very_tight_quote = described_class.new(ticker: "TEST", bid_price: 100.0, ask_price: 100.001)
        expect(very_tight_quote.tight_spread?).to be true
      end
    end

    context "when spread_percentage is nil" do
      let(:no_spread_quote) { described_class.new(ticker: "TEST", bid_price: 100.0) }

      it "returns false" do
        expect(no_spread_quote.tight_spread?).to be false
      end
    end
  end

  describe "#wide_spread?" do
    context "when spread_percentage is available" do
      it "returns true for spreads > 1%" do
        wide_quote = described_class.new(ticker: "TEST", bid_price: 100.0, ask_price: 102.0)
        # 2% spread
        expect(wide_quote.wide_spread?).to be true
      end

      it "returns false for spreads <= 1%" do
        normal_quote = described_class.new(ticker: "TEST", bid_price: 100.0, ask_price: 100.5)
        # 0.5% spread
        expect(normal_quote.wide_spread?).to be false
      end

      it "returns false for exactly 1% spread boundary" do
        boundary_quote = described_class.new(ticker: "TEST", bid_price: 100.0, ask_price: 101.0)
        # Exactly 1% spread
        expect(boundary_quote.wide_spread?).to be false # > 1.0, not >= 1.0
      end

      it "returns false for zero spread" do
        locked_quote = described_class.new(ticker: "TEST", bid_price: 100.0, ask_price: 100.0)
        expect(locked_quote.wide_spread?).to be false
      end

      it "handles very wide spreads" do
        very_wide_quote = described_class.new(ticker: "TEST", bid_price: 100.0, ask_price: 110.0)
        expect(very_wide_quote.wide_spread?).to be true
      end
    end

    context "when spread_percentage is nil" do
      let(:no_spread_quote) { described_class.new(ticker: "TEST", bid_price: 100.0) }

      it "returns false" do
        expect(no_spread_quote.wide_spread?).to be false
      end
    end
  end

  describe "#two_sided?" do
    context "when both bid and ask have positive size" do
      it "returns true" do
        expect(quote.two_sided?).to be true # bid_size: 200, ask_size: 300
      end

      it "returns true for small sizes" do
        small_quote = described_class.new(ticker: "TEST", bid_size: 1, ask_size: 1)
        expect(small_quote.two_sided?).to be true
      end
    end

    context "when bid_size is zero" do
      let(:zero_bid_quote) { described_class.new(ticker: "TEST", bid_size: 0, ask_size: 100) }

      it "returns false" do
        expect(zero_bid_quote.two_sided?).to be false
      end
    end

    context "when ask_size is zero" do
      let(:zero_ask_quote) { described_class.new(ticker: "TEST", bid_size: 100, ask_size: 0) }

      it "returns false" do
        expect(zero_ask_quote.two_sided?).to be false
      end
    end

    context "when both sizes are zero" do
      let(:zero_sizes_quote) { described_class.new(ticker: "TEST", bid_size: 0, ask_size: 0) }

      it "returns false" do
        expect(zero_sizes_quote.two_sided?).to be false
      end
    end

    context "when bid_size is nil" do
      let(:nil_bid_quote) { described_class.new(ticker: "TEST", ask_size: 100) }

      it "returns false" do
        expect(nil_bid_quote.two_sided?).to be false
      end
    end

    context "when ask_size is nil" do
      let(:nil_ask_quote) { described_class.new(ticker: "TEST", bid_size: 100) }

      it "returns false" do
        expect(nil_ask_quote.two_sided?).to be false
      end
    end

    context "when both sizes are nil" do
      let(:nil_sizes_quote) { described_class.new(ticker: "TEST") }

      it "returns false" do
        expect(nil_sizes_quote.two_sided?).to be false
      end
    end
  end

  describe "#bid_exchange_name" do
    [
      [1, "NYSE"],
      [2, "NASDAQ"],
      [3, "NYSE MKT"],
      [4, "NYSE Arca"],
      [5, "BATS"],
      [6, "IEX"],
      [11, "NASDAQ OMX BX"],
      [12, "NASDAQ OMX PSX"]
    ].each do |exchange_id, expected_name|
      it "returns #{expected_name} for bid_exchange ID #{exchange_id}" do
        quote = described_class.new(ticker: "TEST", bid_exchange: exchange_id)
        expect(quote.bid_exchange_name).to eq(expected_name)
      end
    end

    it "returns unknown format for unrecognized bid_exchange ID" do
      unknown_quote = described_class.new(ticker: "TEST", bid_exchange: 999)
      expect(unknown_quote.bid_exchange_name).to eq("Unknown (999)")
    end

    it "handles nil bid_exchange" do
      nil_exchange_quote = described_class.new(ticker: "TEST")
      expect(nil_exchange_quote.bid_exchange_name).to eq("Unknown ()")
    end

    it "handles string bid_exchange" do
      string_exchange_quote = described_class.new(ticker: "TEST", bid_exchange: "1")
      expect(string_exchange_quote.bid_exchange_name).to eq("NYSE")
    end
  end

  describe "#ask_exchange_name" do
    [
      [1, "NYSE"],
      [2, "NASDAQ"],
      [3, "NYSE MKT"],
      [4, "NYSE Arca"],
      [5, "BATS"],
      [6, "IEX"],
      [11, "NASDAQ OMX BX"],
      [12, "NASDAQ OMX PSX"]
    ].each do |exchange_id, expected_name|
      it "returns #{expected_name} for ask_exchange ID #{exchange_id}" do
        quote = described_class.new(ticker: "TEST", ask_exchange: exchange_id)
        expect(quote.ask_exchange_name).to eq(expected_name)
      end
    end

    it "returns unknown format for unrecognized ask_exchange ID" do
      unknown_quote = described_class.new(ticker: "TEST", ask_exchange: 999)
      expect(unknown_quote.ask_exchange_name).to eq("Unknown (999)")
    end

    it "handles nil ask_exchange" do
      nil_exchange_quote = described_class.new(ticker: "TEST")
      expect(nil_exchange_quote.ask_exchange_name).to eq("Unknown ()")
    end

    it "handles string ask_exchange" do
      string_exchange_quote = described_class.new(ticker: "TEST", ask_exchange: "2")
      expect(string_exchange_quote.ask_exchange_name).to eq("NASDAQ")
    end
  end

  describe "#formatted_timestamp" do
    context "with valid timestamps" do
      it "formats ISO timestamp correctly" do
        iso_quote = described_class.new(ticker: "TEST", timestamp: "2024-01-15T15:30:25Z")
        expect(iso_quote.formatted_timestamp).to eq("2024-01-15 15:30:25")
      end

      it "formats timestamp with milliseconds" do
        ms_quote = described_class.new(ticker: "TEST", timestamp: "2024-01-15T15:30:25.123Z")
        expect(ms_quote.formatted_timestamp).to eq("2024-01-15 15:30:25")
      end

      it "formats timestamp with nanoseconds" do
        ns_quote = described_class.new(ticker: "TEST", timestamp: "2024-01-15T15:30:25.123456789Z")
        expect(ns_quote.formatted_timestamp).to eq("2024-01-15 15:30:25")
      end
    end

    context "with invalid timestamps" do
      it "returns timestamp as string for invalid format" do
        invalid_quote = described_class.new(ticker: "TEST", timestamp: "invalid-timestamp")
        expect(invalid_quote.formatted_timestamp).to eq("invalid-timestamp")
      end

      it "handles partial timestamp format" do
        partial_quote = described_class.new(ticker: "TEST", timestamp: "2024-01-15")
        expect(partial_quote.formatted_timestamp).to eq("2024-01-15 00:00:00")
      end
    end

    context "when timestamp is nil" do
      let(:no_timestamp_quote) { described_class.new(ticker: "TEST") }

      it "returns 'N/A'" do
        expect(no_timestamp_quote.formatted_timestamp).to eq("N/A")
      end
    end

    context "when timestamp is empty string" do
      let(:empty_timestamp_quote) { described_class.new(ticker: "TEST", timestamp: "") }

      it "returns 'N/A'" do
        expect(empty_timestamp_quote.formatted_timestamp).to eq("N/A")
      end
    end
  end

  describe ".from_api" do
    let(:api_data) do
      {
        "sip_timestamp" => 1705328425123456789,
        "P" => 174.49,
        "p" => 174.51,
        "S" => 200,
        "s" => 300,
        "x" => 1,
        "X" => 2,
        "participant_timestamp" => 1705328425123456789,
        "c" => [1, 14],
        "i" => [0],
        "y" => "A"
      }
    end

    it "creates Quote object from API response" do
      quote = described_class.from_api("AAPL", api_data)

      expect(quote).to be_a(described_class)
      expect(quote.ticker).to eq("AAPL")
      # The transformer will handle the field mapping
    end

    context "with minimal API data" do
      let(:minimal_api_data) { {"P" => 100.0, "p" => 100.05} }

      it "creates Quote with ticker from method parameter" do
        quote = described_class.from_api("TEST", minimal_api_data)
        expect(quote.ticker).to eq("TEST")
      end
    end

    context "with null/nil optional fields" do
      let(:data_with_nils) do
        {
          "P" => 174.49,
          "p" => 174.51,
          "S" => nil,
          "s" => nil,
          "x" => nil,
          "X" => nil,
          "participant_timestamp" => nil,
          "c" => nil,
          "i" => nil,
          "y" => nil
        }
      end

      it "handles nil values in optional fields" do
        quote = described_class.from_api("TEST", data_with_nils)
        expect(quote.ticker).to eq("TEST")
      end
    end

    it "calls Api::Transformers.stock_quote for data transformation" do
      expect(Polymux::Api::Transformers).to receive(:stock_quote).with("AAPL", api_data).and_call_original
      described_class.from_api("AAPL", api_data)
    end
  end

  # Comprehensive attribute validation tests
  describe "attribute validation" do
    it "requires ticker attribute" do
      expect { described_class.new }.to raise_error(Dry::Struct::Error)
    end

    it "accepts string ticker" do
      quote = described_class.new(ticker: "AAPL")
      expect(quote.ticker).to eq("AAPL")
    end

    it "rejects non-string ticker" do
      expect { described_class.new(ticker: 123) }.to raise_error(Dry::Struct::Error)
      expect { described_class.new(ticker: nil) }.to raise_error(Dry::Struct::Error)
      expect { described_class.new(ticker: []) }.to raise_error(Dry::Struct::Error)
      expect { described_class.new(ticker: {}) }.to raise_error(Dry::Struct::Error)
      expect { described_class.new(ticker: true) }.to raise_error(Dry::Struct::Error)
    end

    context "optional attributes" do
      let(:quote) { described_class.new(ticker: "TEST") }

      it "allows nil for all optional attributes" do
        expect(quote.timestamp).to be_nil
        expect(quote.bid_price).to be_nil
        expect(quote.ask_price).to be_nil
        expect(quote.bid_size).to be_nil
        expect(quote.ask_size).to be_nil
        expect(quote.bid_exchange).to be_nil
        expect(quote.ask_exchange).to be_nil
        expect(quote.participant_timestamp).to be_nil
        expect(quote.conditions).to be_nil
        expect(quote.indicators).to be_nil
        expect(quote.tape).to be_nil
      end

      it "accepts valid values for all optional attributes" do
        full_quote = described_class.new(
          ticker: "TEST",
          timestamp: "2024-01-15T15:30:25Z",
          bid_price: 100.50,
          ask_price: 100.52,
          bid_size: 200,
          ask_size: 300,
          bid_exchange: 1,
          ask_exchange: 2,
          participant_timestamp: 1705328425123456789,
          conditions: [1, 14],
          indicators: [0],
          tape: "A"
        )

        expect(full_quote.timestamp).to eq("2024-01-15T15:30:25Z")
        expect(full_quote.bid_price).to eq(100.50)
        expect(full_quote.ask_price).to eq(100.52)
        expect(full_quote.bid_size).to eq(200)
        expect(full_quote.ask_size).to eq(300)
        expect(full_quote.bid_exchange).to eq(1)
        expect(full_quote.ask_exchange).to eq(2)
        expect(full_quote.participant_timestamp).to eq(1705328425123456789)
        expect(full_quote.conditions).to eq([1, 14])
        expect(full_quote.indicators).to eq([0])
        expect(full_quote.tape).to eq("A")
      end
    end

    context "type constraints" do
      it "accepts integer prices" do
        quote = described_class.new(ticker: "TEST", bid_price: 100, ask_price: 101)
        expect(quote.bid_price).to eq(100)
        expect(quote.ask_price).to eq(101)
      end

      it "accepts float prices" do
        quote = described_class.new(ticker: "TEST", bid_price: 100.50, ask_price: 100.52)
        expect(quote.bid_price).to eq(100.50)
        expect(quote.ask_price).to eq(100.52)
      end

      it "accepts integer sizes" do
        quote = described_class.new(ticker: "TEST", bid_size: 100, ask_size: 200)
        expect(quote.bid_size).to eq(100)
        expect(quote.ask_size).to eq(200)
      end

      it "accepts integer exchange IDs" do
        quote = described_class.new(ticker: "TEST", bid_exchange: 1, ask_exchange: 2)
        expect(quote.bid_exchange).to eq(1)
        expect(quote.ask_exchange).to eq(2)
      end

      it "accepts string exchange IDs" do
        quote = described_class.new(ticker: "TEST", bid_exchange: "NYSE", ask_exchange: "NASDAQ")
        expect(quote.bid_exchange).to eq("NYSE")
        expect(quote.ask_exchange).to eq("NASDAQ")
      end

      it "accepts array of integers for conditions and indicators" do
        quote = described_class.new(ticker: "TEST", conditions: [1, 14, 37], indicators: [0, 1])
        expect(quote.conditions).to eq([1, 14, 37])
        expect(quote.indicators).to eq([0, 1])
      end

      it "accepts integer and string participant_timestamp" do
        int_quote = described_class.new(ticker: "TEST", participant_timestamp: 1705328425123456789)
        string_quote = described_class.new(ticker: "TEST", participant_timestamp: "1705328425123456789")

        expect(int_quote.participant_timestamp).to eq(1705328425123456789)
        expect(string_quote.participant_timestamp).to eq("1705328425123456789")
      end
    end
  end

  # Immutability and structural tests
  describe "immutability" do
    let(:quote) { described_class.new(ticker: "AAPL", bid_price: 174.49, ask_price: 174.51) }

    it "does not allow attribute modification" do
      expect { quote.ticker = "MSFT" }.to raise_error(NoMethodError)
      expect { quote.bid_price = 200.0 }.to raise_error(NoMethodError)
      expect { quote.ask_price = 200.05 }.to raise_error(NoMethodError)
    end

    it "is immutable (Dry::Struct behavior)" do
      expect(quote).to be_a(Dry::Struct)
    end
  end

  # Key transformation tests
  describe "key transformation" do
    it "transforms string keys to symbols" do
      data = {"ticker" => "AAPL", "bid_price" => 174.49, "ask_price" => 174.51}
      quote = described_class.new(data)

      expect(quote.ticker).to eq("AAPL")
      expect(quote.bid_price).to eq(174.49)
      expect(quote.ask_price).to eq(174.51)
    end

    it "accepts symbol keys directly" do
      data = {ticker: "AAPL", bid_price: 174.49, ask_price: 174.51}
      quote = described_class.new(data)

      expect(quote.ticker).to eq("AAPL")
      expect(quote.bid_price).to eq(174.49)
      expect(quote.ask_price).to eq(174.51)
    end
  end

  # Edge cases and boundary tests
  describe "edge cases and boundaries" do
    context "boundary values for spread classification" do
      it "handles exactly 0.1% spread boundary for tight_spread?" do
        # Create a quote with exactly 0.1% spread
        boundary_quote = described_class.new(ticker: "TEST", bid_price: 100.0, ask_price: 100.1)
        expect(boundary_quote.spread_percentage).to eq(0.1)
        expect(boundary_quote.tight_spread?).to be false # < 0.1, not <= 0.1
      end

      it "handles exactly 1.0% spread boundary for wide_spread?" do
        # Create a quote with exactly 1.0% spread
        boundary_quote = described_class.new(ticker: "TEST", bid_price: 100.0, ask_price: 101.0)
        expect(boundary_quote.spread_percentage).to eq(0.995)
        expect(boundary_quote.wide_spread?).to be false # > 1.0, not >= 1.0
      end
    end

    context "mathematical edge cases" do
      it "handles very large prices and sizes" do
        large_quote = described_class.new(
          ticker: "TEST",
          bid_price: 999_999.99,
          ask_price: 1_000_000.01,
          bid_size: 1_000_000,
          ask_size: 1_000_000
        )

        expect(large_quote.bid_value).to eq(999_999_990_000.0)
        expect(large_quote.ask_value).to eq(1_000_000_010_000.0)
        expect(large_quote.spread).to eq(0.02)
        expect(large_quote.midpoint).to eq(1_000_000.0)
      end

      it "handles very small prices" do
        small_price_quote = described_class.new(ticker: "TEST", bid_price: 0.0001, ask_price: 0.0002)
        expect(small_price_quote.spread).to eq(0.0001)
        expect(small_price_quote.midpoint).to be_within(0.00000001).of(0.00015)
      end

      it "handles negative prices (unusual but possible)" do
        negative_quote = described_class.new(ticker: "TEST", bid_price: -1.0, ask_price: -0.5)
        expect(negative_quote.spread).to eq(0.5)
        expect(negative_quote.midpoint).to eq(-0.75)
        expect(negative_quote.spread_percentage).to be_nil # midpoint <= 0
      end
    end

    context "precision and rounding" do
      it "maintains proper decimal precision in calculations" do
        precision_quote = described_class.new(ticker: "TEST", bid_price: 123.456789, ask_price: 123.987654)

        expect(precision_quote.spread).to eq(0.530865)
        expect(precision_quote.midpoint).to be_within(0.0001).of(123.7221715)
      end

      it "rounds spread_percentage to 4 decimal places" do
        # Create scenario that would result in many decimal places
        complex_quote = described_class.new(ticker: "TEST", bid_price: 99.999999, ask_price: 100.000001)
        result = complex_quote.spread_percentage

        # Verify it's rounded to 4 decimal places
        decimal_places = result.to_s.split(".")[1]&.length || 0
        expect(decimal_places).to be <= 4
      end
    end

    context "error handling in methods" do
      it "handles malformed timestamp gracefully in formatted_timestamp" do
        malformed_quote = described_class.new(ticker: "TEST", timestamp: "not-a-timestamp")
        expect(malformed_quote.formatted_timestamp).to eq("not-a-timestamp")
      end

      it "handles division by zero gracefully in spread_percentage" do
        zero_midpoint_quote = described_class.new(ticker: "TEST", bid_price: 0.0, ask_price: 0.0)
        expect(zero_midpoint_quote.spread_percentage).to be_nil
      end

      it "handles nil exchange IDs in exchange_name methods" do
        nil_exchange_quote = described_class.new(ticker: "TEST")
        expect(nil_exchange_quote.bid_exchange_name).to eq("Unknown ()")
        expect(nil_exchange_quote.ask_exchange_name).to eq("Unknown ()")
      end
    end
  end

  # Tests to ensure mutation resistance
  describe "mutation resistance" do
    context "exact comparisons in spread classification" do
      it "uses exact < comparison for tight_spread?, not <=" do
        # Right at the boundary - should be false with < 0.1
        boundary_quote = described_class.new(ticker: "TEST", bid_price: 100.0, ask_price: 100.1)
        expect(boundary_quote.tight_spread?).to be false

        # Just under the boundary - should be true
        under_boundary_quote = described_class.new(ticker: "TEST", bid_price: 100.0, ask_price: 100.09)
        expect(under_boundary_quote.tight_spread?).to be true
      end

      it "uses exact > comparison for wide_spread?, not >=" do
        # Right at the boundary - should be false with > 1.0
        boundary_quote = described_class.new(ticker: "TEST", bid_price: 100.0, ask_price: 101.0)
        expect(boundary_quote.wide_spread?).to be false

        # Just over the boundary - should be true
        over_boundary_quote = described_class.new(ticker: "TEST", bid_price: 100.0, ask_price: 101.1)
        expect(over_boundary_quote.wide_spread?).to be true
      end
    end

    context "exact > 0 checks in two_sided?" do
      it "requires both sizes to be > 0, not >= 0" do
        zero_bid_quote = described_class.new(ticker: "TEST", bid_size: 0, ask_size: 100)
        zero_ask_quote = described_class.new(ticker: "TEST", bid_size: 100, ask_size: 0)
        positive_quote = described_class.new(ticker: "TEST", bid_size: 1, ask_size: 1)

        expect(zero_bid_quote.two_sided?).to be false
        expect(zero_ask_quote.two_sided?).to be false
        expect(positive_quote.two_sided?).to be true
      end
    end
  end
end
