# frozen_string_literal: true

require "spec_helper"

RSpec.describe Polymux::Api::Stocks::Trade do
  let(:trade_data) do
    {
      ticker: "AAPL",
      timestamp: "2024-01-15T15:30:25.123456789Z",
      price: 174.49,
      size: 100,
      exchange: 1,
      conditions: [14, 37],
      participant_timestamp: 1705328425123456789,
      id: "12345",
      tape: "A",
      trf_id: 1,
      trf_timestamp: "2024-01-15T15:30:25.200000000Z"
    }
  end

  let(:trade) { described_class.new(trade_data) }

  describe "initialization" do
    it "creates a trade with all attributes" do
      expect(trade.ticker).to eq("AAPL")
      expect(trade.timestamp).to eq("2024-01-15T15:30:25.123456789Z")
      expect(trade.price).to eq(174.49)
      expect(trade.size).to eq(100)
      expect(trade.exchange).to eq(1)
      expect(trade.conditions).to eq([14, 37])
      expect(trade.participant_timestamp).to eq(1705328425123456789)
      expect(trade.id).to eq("12345")
      expect(trade.tape).to eq("A")
      expect(trade.trf_id).to eq(1)
      expect(trade.trf_timestamp).to eq("2024-01-15T15:30:25.200000000Z")
    end

    it "handles optional attributes" do
      minimal_trade = described_class.new(ticker: "TEST")
      expect(minimal_trade.ticker).to eq("TEST")
      expect(minimal_trade.timestamp).to be_nil
      expect(minimal_trade.price).to be_nil
      expect(minimal_trade.size).to be_nil
    end

    it "is instance of Polymux::Api::Stocks::Trade" do
      expect(trade).to be_instance_of(Polymux::Api::Stocks::Trade)
    end

    it "inherits from Dry::Struct" do
      expect(trade).to be_a(Dry::Struct)
    end
  end

  describe "#total_value" do
    context "when both price and size are present" do
      it "calculates total trade value correctly" do
        expect(trade.total_value).to eq(17449.0) # 174.49 * 100
      end

      it "handles decimal prices accurately" do
        decimal_trade = described_class.new(ticker: "TEST", price: 123.456, size: 50)
        expect(decimal_trade.total_value).to eq(6172.8) # 123.456 * 50
      end

      it "handles integer prices" do
        integer_trade = described_class.new(ticker: "TEST", price: 100, size: 25)
        expect(integer_trade.total_value).to eq(2500) # 100 * 25
      end

      it "handles zero price" do
        zero_price_trade = described_class.new(ticker: "TEST", price: 0, size: 100)
        expect(zero_price_trade.total_value).to eq(0)
      end

      it "handles zero size" do
        zero_size_trade = described_class.new(ticker: "TEST", price: 100.0, size: 0)
        expect(zero_size_trade.total_value).to eq(0.0)
      end
    end

    context "when price is nil" do
      let(:no_price_trade) { described_class.new(ticker: "TEST", size: 100) }

      it "returns nil" do
        expect(no_price_trade.total_value).to be_nil
      end
    end

    context "when size is nil" do
      let(:no_size_trade) { described_class.new(ticker: "TEST", price: 174.49) }

      it "returns nil" do
        expect(no_size_trade.total_value).to be_nil
      end
    end

    context "when both price and size are nil" do
      let(:no_data_trade) { described_class.new(ticker: "TEST") }

      it "returns nil" do
        expect(no_data_trade.total_value).to be_nil
      end
    end
  end

  describe "#block_trade?" do
    context "when size is >= 10,000" do
      it "returns true for exactly 10,000 shares" do
        block_trade = described_class.new(ticker: "TEST", size: 10_000)
        expect(block_trade.block_trade?).to be true
      end

      it "returns true for more than 10,000 shares" do
        large_block_trade = described_class.new(ticker: "TEST", size: 50_000)
        expect(large_block_trade.block_trade?).to be true
      end

      it "returns true for very large trades" do
        huge_trade = described_class.new(ticker: "TEST", size: 1_000_000)
        expect(huge_trade.block_trade?).to be true
      end
    end

    context "when size is < 10,000" do
      it "returns false for 9,999 shares" do
        almost_block_trade = described_class.new(ticker: "TEST", size: 9_999)
        expect(almost_block_trade.block_trade?).to be false
      end

      it "returns false for small trades" do
        small_trade = described_class.new(ticker: "TEST", size: 100)
        expect(small_trade.block_trade?).to be false
      end

      it "returns false for single share trades" do
        tiny_trade = described_class.new(ticker: "TEST", size: 1)
        expect(tiny_trade.block_trade?).to be false
      end

      it "returns false for zero size" do
        zero_trade = described_class.new(ticker: "TEST", size: 0)
        expect(zero_trade.block_trade?).to be false
      end
    end

    context "when size is nil" do
      let(:no_size_trade) { described_class.new(ticker: "TEST") }

      it "returns false" do
        expect(no_size_trade.block_trade?).to be false
      end
    end
  end

  describe "#regular_hours?" do
    context "with valid timestamps during regular hours" do
      it "returns true for 9:30 AM ET" do
        morning_trade = described_class.new(ticker: "TEST", timestamp: "2024-01-15T14:30:00Z") # 9:30 AM ET
        expect(morning_trade.regular_hours?).to be true
      end

      it "returns true for 4:00 PM ET" do
        closing_trade = described_class.new(ticker: "TEST", timestamp: "2024-01-15T21:00:00Z") # 4:00 PM ET
        expect(closing_trade.regular_hours?).to be true
      end

      it "returns true for mid-day trades" do
        midday_trade = described_class.new(ticker: "TEST", timestamp: "2024-01-15T17:30:00Z") # 12:30 PM ET
        expect(midday_trade.regular_hours?).to be true
      end
    end

    context "with timestamps outside regular hours" do
      it "returns false for pre-market (before 9:30 AM ET)" do
        premarket_trade = described_class.new(ticker: "TEST", timestamp: "2024-01-15T14:00:00Z") # 9:00 AM ET
        expect(premarket_trade.regular_hours?).to be false
      end

      it "returns false for after-hours (after 4:00 PM ET)" do
        afterhours_trade = described_class.new(ticker: "TEST", timestamp: "2024-01-15T21:30:00Z") # 4:30 PM ET
        expect(afterhours_trade.regular_hours?).to be false
      end

      it "returns false for late evening trades" do
        evening_trade = described_class.new(ticker: "TEST", timestamp: "2024-01-15T02:00:00Z") # 9:00 PM ET (previous day)
        expect(evening_trade.regular_hours?).to be false
      end

      # Critical boundary mutations - these kill mutants that change 930 to 929/931
      it "returns false for 9:29 AM ET (one minute before market open)" do
        pre_open_trade = described_class.new(ticker: "TEST", timestamp: "2024-01-15T14:29:00Z") # 9:29 AM ET
        expect(pre_open_trade.regular_hours?).to be false
      end

      # Critical boundary mutations - these kill mutants that change 1600 to 1599/1601  
      it "returns false for 4:01 PM ET (one minute after market close)" do
        post_close_trade = described_class.new(ticker: "TEST", timestamp: "2024-01-15T21:01:00Z") # 4:01 PM ET
        expect(post_close_trade.regular_hours?).to be false
      end

      # Edge case: exactly at boundaries with seconds/milliseconds
      it "returns false for 9:29:59 AM ET (one second before market open)" do
        pre_open_seconds_trade = described_class.new(ticker: "TEST", timestamp: "2024-01-15T14:29:59Z") # 9:29:59 AM ET
        expect(pre_open_seconds_trade.regular_hours?).to be false
      end

      it "returns false for 4:01:00 PM ET (one minute after market close)" do
        post_close_minute_trade = described_class.new(ticker: "TEST", timestamp: "2024-01-15T21:01:00Z") # 4:01:00 PM ET
        expect(post_close_minute_trade.regular_hours?).to be false
      end
    end

    context "with edge cases" do
      it "returns false when timestamp is nil" do
        no_timestamp_trade = described_class.new(ticker: "TEST")
        expect(no_timestamp_trade.regular_hours?).to be false
      end

      it "returns false when timestamp is invalid" do
        invalid_timestamp_trade = described_class.new(ticker: "TEST", timestamp: "invalid")
        expect(invalid_timestamp_trade.regular_hours?).to be false
      end

      it "returns false when timestamp is empty string" do
        empty_timestamp_trade = described_class.new(ticker: "TEST", timestamp: "")
        expect(empty_timestamp_trade.regular_hours?).to be false
      end

      # Guard clause mutation tests - these kill mutants that delete the timestamp check
      it "immediately returns false for nil timestamp without executing time parsing" do
        no_timestamp_trade = described_class.new(ticker: "TEST")
        
        # This should not attempt to parse nil - if guard clause is deleted, this would fail
        expect { no_timestamp_trade.regular_hours? }.not_to raise_error
        expect(no_timestamp_trade.regular_hours?).to be false
      end

      # Return statement vs expression mutation tests
      it "ensures early return behavior is preserved for invalid timestamps" do
        # Tests that guard clauses with 'return false' actually return, not just evaluate false
        invalid_timestamp_trade = described_class.new(ticker: "TEST", timestamp: nil)
        
        result = invalid_timestamp_trade.regular_hours?
        expect(result).to eq(false)  # Must be exactly false, not just falsy
        expect(result).to be_a(FalseClass)  # Ensure it's actually false, not nil
      end

      # Control flow mutation - ensure method doesn't continue execution after guard
      it "handles parse error gracefully and returns false as boolean" do
        parse_error_trade = described_class.new(ticker: "TEST", timestamp: "not-a-date")
        
        result = parse_error_trade.regular_hours?
        expect(result).to be_a(FalseClass)  # Must return false, not nil or other falsy value
        expect(result).to eq(false)
      end
    end
  end

  describe "#extended_hours?" do
    it "returns opposite of regular_hours?" do
      regular_trade = described_class.new(ticker: "TEST", timestamp: "2024-01-15T17:30:00Z") # Regular hours
      extended_trade = described_class.new(ticker: "TEST", timestamp: "2024-01-15T21:30:00Z") # Extended hours

      expect(regular_trade.extended_hours?).to be false
      expect(extended_trade.extended_hours?).to be true
    end

    it "returns true when regular_hours? returns false" do
      no_timestamp_trade = described_class.new(ticker: "TEST")
      expect(no_timestamp_trade.extended_hours?).to be true
    end
  end

  describe "#exchange_name" do
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
      it "returns #{expected_name} for exchange ID #{exchange_id}" do
        trade = described_class.new(ticker: "TEST", exchange: exchange_id)
        expect(trade.exchange_name).to eq(expected_name)
      end
    end

    context "with unknown exchange IDs" do
      it "returns unknown format for unrecognized numeric exchange ID" do
        unknown_trade = described_class.new(ticker: "TEST", exchange: 999)
        expect(unknown_trade.exchange_name).to eq("Unknown (999)")
      end

      it "returns unknown format for zero exchange ID" do
        zero_trade = described_class.new(ticker: "TEST", exchange: 0)
        expect(zero_trade.exchange_name).to eq("Unknown (0)")
      end

      it "returns unknown format for negative exchange ID" do
        negative_trade = described_class.new(ticker: "TEST", exchange: -1)
        expect(negative_trade.exchange_name).to eq("Unknown (-1)")
      end
    end

    context "with string exchange IDs" do
      it "converts string exchange ID to integer" do
        string_trade = described_class.new(ticker: "TEST", exchange: "1")
        expect(string_trade.exchange_name).to eq("NYSE")
      end

      it "handles non-numeric string exchange ID" do
        non_numeric_trade = described_class.new(ticker: "TEST", exchange: "NYSE")
        expect(non_numeric_trade.exchange_name).to eq("Unknown (NYSE)")
      end

      # String to integer conversion mutation tests
      it "handles string exchange IDs for all known exchanges" do
        [
          ["1", "NYSE"], ["2", "NASDAQ"], ["3", "NYSE MKT"], ["4", "NYSE Arca"],
          ["5", "BATS"], ["6", "IEX"], ["11", "NASDAQ OMX BX"], ["12", "NASDAQ OMX PSX"]
        ].each do |string_id, expected_name|
          trade = described_class.new(ticker: "TEST", exchange: string_id)
          expect(trade.exchange_name).to eq(expected_name)
        end
      end

      # Type coercion mutation tests - ensures .to_i is applied on string values
      it "handles string representations of floats by integer conversion" do
        string_float_trade = described_class.new(ticker: "TEST", exchange: "1.9")
        expect(string_float_trade.exchange_name).to eq("NYSE")  # Should convert "1.9".to_i = 1
        
        string_float_trade_2 = described_class.new(ticker: "TEST", exchange: "2.8")
        expect(string_float_trade_2.exchange_name).to eq("NASDAQ")  # Should convert "2.8".to_i = 2
      end
    end

    context "when exchange is nil" do
      let(:no_exchange_trade) { described_class.new(ticker: "TEST") }

      it "returns unknown format with nil" do
        expect(no_exchange_trade.exchange_name).to eq("Unknown ()")
      end

      # Nil handling mutation test - ensures .to_i called on nil returns 0
      it "handles nil exchange through to_i conversion" do
        expect(no_exchange_trade.exchange_name).to eq("Unknown ()")
        # Verify that nil.to_i becomes 0, which matches case 0 behavior
        expect(nil.to_i).to eq(0)
      end
    end

    context "case statement mutation tests" do
      # These tests kill mutants that change case when values (1->0, 1->2, etc.)
      it "distinguishes between adjacent exchange IDs" do
        # Tests that when 1 isn't mutated to when 0 or when 2
        nyse_trade = described_class.new(ticker: "TEST", exchange: 1)
        nasdaq_trade = described_class.new(ticker: "TEST", exchange: 2)
        unknown_trade = described_class.new(ticker: "TEST", exchange: 0)
        
        expect(nyse_trade.exchange_name).to eq("NYSE")
        expect(nasdaq_trade.exchange_name).to eq("NASDAQ")
        expect(unknown_trade.exchange_name).to eq("Unknown (0)")
        
        # Verify they're all different
        expect(nyse_trade.exchange_name).not_to eq(nasdaq_trade.exchange_name)
        expect(nyse_trade.exchange_name).not_to eq(unknown_trade.exchange_name)
      end

      # Tests case statement boundary mutations around higher values
      it "distinguishes between NASDAQ family exchanges" do
        bx_trade = described_class.new(ticker: "TEST", exchange: 11)  # NASDAQ OMX BX
        psx_trade = described_class.new(ticker: "TEST", exchange: 12) # NASDAQ OMX PSX
        unknown_10 = described_class.new(ticker: "TEST", exchange: 10)
        unknown_13 = described_class.new(ticker: "TEST", exchange: 13)
        
        expect(bx_trade.exchange_name).to eq("NASDAQ OMX BX")
        expect(psx_trade.exchange_name).to eq("NASDAQ OMX PSX")
        expect(unknown_10.exchange_name).to eq("Unknown (10)")
        expect(unknown_13.exchange_name).to eq("Unknown (13)")
      end

      # Default case mutation test
      it "handles unmapped exchange IDs with unknown format" do
        large_unknown = described_class.new(ticker: "TEST", exchange: 999)
        negative_unknown = described_class.new(ticker: "TEST", exchange: -5)
        
        expect(large_unknown.exchange_name).to eq("Unknown (999)")
        expect(negative_unknown.exchange_name).to eq("Unknown (-5)")
        
        # Ensure format includes the original exchange value
        expect(large_unknown.exchange_name).to include("999")
        expect(negative_unknown.exchange_name).to include("-5")
      end
    end
  end

  describe "#formatted_timestamp" do
    context "with valid timestamps" do
      it "formats ISO timestamp correctly" do
        iso_trade = described_class.new(ticker: "TEST", timestamp: "2024-01-15T15:30:25Z")
        expect(iso_trade.formatted_timestamp).to eq("2024-01-15 15:30:25")
      end

      it "formats timestamp with milliseconds" do
        ms_trade = described_class.new(ticker: "TEST", timestamp: "2024-01-15T15:30:25.123Z")
        expect(ms_trade.formatted_timestamp).to eq("2024-01-15 15:30:25")
      end

      it "formats timestamp with nanoseconds" do
        ns_trade = described_class.new(ticker: "TEST", timestamp: "2024-01-15T15:30:25.123456789Z")
        expect(ns_trade.formatted_timestamp).to eq("2024-01-15 15:30:25")
      end
    end

    context "with invalid timestamps" do
      it "returns timestamp as string for invalid format" do
        invalid_trade = described_class.new(ticker: "TEST", timestamp: "invalid-timestamp")
        expect(invalid_trade.formatted_timestamp).to eq("invalid-timestamp")
      end

      it "returns timestamp as string for partial format" do
        partial_trade = described_class.new(ticker: "TEST", timestamp: "2024-01-15")
        expect(partial_trade.formatted_timestamp).to eq("2024-01-15 00:00:00")
      end
    end

    context "when timestamp is nil" do
      let(:no_timestamp_trade) { described_class.new(ticker: "TEST") }

      it "returns 'N/A'" do
        expect(no_timestamp_trade.formatted_timestamp).to eq("N/A")
      end
    end

    context "when timestamp is empty string" do
      let(:empty_timestamp_trade) { described_class.new(ticker: "TEST", timestamp: "") }

      it "returns 'N/A'" do
        expect(empty_timestamp_trade.formatted_timestamp).to eq("N/A")
      end

      # Guard clause mutation tests for empty string handling
      it "handles whitespace-only timestamps" do
        whitespace_trade = described_class.new(ticker: "TEST", timestamp: "   ")
        expect(whitespace_trade.formatted_timestamp).to eq("N/A")
      end

      it "handles tab and newline timestamps" do
        tab_trade = described_class.new(ticker: "TEST", timestamp: "\t")
        newline_trade = described_class.new(ticker: "TEST", timestamp: "\n")
        
        expect(tab_trade.formatted_timestamp).to eq("N/A")
        expect(newline_trade.formatted_timestamp).to eq("N/A")
      end
    end

    context "string strip mutation tests" do
      # These kill mutants that remove .strip call or change .empty? check
      it "strips whitespace before checking emptiness" do
        padded_empty_trade = described_class.new(ticker: "TEST", timestamp: "  ")
        expect(padded_empty_trade.formatted_timestamp).to eq("N/A")
        
        # Verify that " ".strip.empty? is true
        expect("  ".strip.empty?).to be true
      end

      it "handles mixed whitespace around valid timestamps" do
        padded_valid_trade = described_class.new(ticker: "TEST", timestamp: "  2024-01-15T15:30:25Z  ")
        expect(padded_valid_trade.formatted_timestamp).to eq("2024-01-15 15:30:25")
      end
    end

    context "error handling mutation tests" do
      # Tests for rescue clause mutations - ArgumentError, TypeError
      it "handles Time.parse ArgumentError specifically" do
        arg_error_trade = described_class.new(ticker: "TEST", timestamp: "not-a-date-at-all")
        
        # Should catch ArgumentError and return timestamp as string
        result = arg_error_trade.formatted_timestamp
        expect(result).to eq("not-a-date-at-all")
        expect(result).to be_a(String)
      end

      it "handles Time.parse TypeError specifically" do
        # Create scenario that would cause TypeError in Time.parse by using integer
        type_error_trade = described_class.new(ticker: "TEST", timestamp: 99999999)  # Large integer that won't parse as date
        
        result = type_error_trade.formatted_timestamp
        expect(result).to eq("99999999")  # Should call .to_s on the timestamp in rescue block
        expect(result).to be_a(String)
      end

      # Rescue clause mutation - ensures both ArgumentError AND TypeError are caught
      it "rescues both ArgumentError and TypeError, not just one" do
        # Mock Time.parse to raise each exception type
        allow(Time).to receive(:parse).and_raise(ArgumentError.new("test error"))
        arg_test_trade = described_class.new(ticker: "TEST", timestamp: "test")
        expect(arg_test_trade.formatted_timestamp).to eq("test")
        
        allow(Time).to receive(:parse).and_raise(TypeError.new("test error"))
        type_test_trade = described_class.new(ticker: "TEST", timestamp: "test2")  
        expect(type_test_trade.formatted_timestamp).to eq("test2")
        
        # Reset the mock
        allow(Time).to receive(:parse).and_call_original
      end
    end

    context "return value mutation tests" do
      # Tests that fallback returns timestamp.to_s, not just timestamp
      it "ensures fallback returns string version of timestamp" do
        # Test with integer timestamp that can't be parsed
        int_timestamp_trade = described_class.new(ticker: "TEST", timestamp: 1705328425)
        result = int_timestamp_trade.formatted_timestamp
        
        expect(result).to be_a(String)
        expect(result).to eq("1705328425")
      end

      it "calls to_s on timestamp in rescue block" do
        # Verify that .to_s is called on the original timestamp value using invalid string
        invalid_format_trade = described_class.new(ticker: "TEST", timestamp: "not-parseable")
        result = invalid_format_trade.formatted_timestamp
        
        expect(result).to eq("not-parseable")
        expect(result).to be_a(String)
      end
    end
  end

  describe ".from_api" do
    let(:api_data) do
      {
        "sip_timestamp" => 1705328425123456789,
        "p" => 174.49,
        "s" => 100,
        "x" => 1,
        "c" => [14, 37],
        "participant_timestamp" => 1705328425123456789,
        "i" => "12345",
        "y" => "A",
        "f" => 1,
        "q" => 1705328425200000000
      }
    end

    it "creates Trade object from API response" do
      trade = described_class.from_api("AAPL", api_data)

      expect(trade).to be_a(described_class)
      expect(trade.ticker).to eq("AAPL")
      # The transformer will handle the field mapping
    end

    context "with minimal API data" do
      let(:minimal_api_data) { {"p" => 100.0, "s" => 50} }

      it "creates Trade with ticker from method parameter" do
        trade = described_class.from_api("TEST", minimal_api_data)
        expect(trade.ticker).to eq("TEST")
      end
    end

    context "with null/nil optional fields" do
      let(:data_with_nils) do
        {
          "p" => 174.49,
          "s" => 100,
          "x" => nil,
          "c" => nil,
          "participant_timestamp" => nil,
          "i" => nil,
          "y" => nil,
          "f" => nil,
          "q" => nil
        }
      end

      it "handles nil values in optional fields" do
        trade = described_class.from_api("TEST", data_with_nils)
        expect(trade.ticker).to eq("TEST")
      end
    end

    it "calls Api::Transformers.stock_trade for data transformation" do
      expect(Polymux::Api::Transformers).to receive(:stock_trade).with("AAPL", api_data).and_call_original
      described_class.from_api("AAPL", api_data)
    end
  end

  # Comprehensive attribute validation tests
  describe "attribute validation" do
    it "requires ticker attribute" do
      expect { described_class.new }.to raise_error(Dry::Struct::Error)
    end

    it "accepts string ticker" do
      trade = described_class.new(ticker: "AAPL")
      expect(trade.ticker).to eq("AAPL")
    end

    it "rejects non-string ticker" do
      expect { described_class.new(ticker: 123) }.to raise_error(Dry::Struct::Error)
      expect { described_class.new(ticker: nil) }.to raise_error(Dry::Struct::Error)
      expect { described_class.new(ticker: []) }.to raise_error(Dry::Struct::Error)
      expect { described_class.new(ticker: {}) }.to raise_error(Dry::Struct::Error)
      expect { described_class.new(ticker: true) }.to raise_error(Dry::Struct::Error)
    end

    context "optional attributes" do
      let(:trade) { described_class.new(ticker: "TEST") }

      it "allows nil for optional timestamp attributes" do
        expect(trade.timestamp).to be_nil
        expect(trade.participant_timestamp).to be_nil
        expect(trade.trf_timestamp).to be_nil
      end

      it "allows nil for optional numeric attributes" do
        expect(trade.price).to be_nil
        expect(trade.size).to be_nil
        expect(trade.exchange).to be_nil
        expect(trade.trf_id).to be_nil
      end

      it "allows nil for optional string attributes" do
        expect(trade.id).to be_nil
        expect(trade.tape).to be_nil
      end

      it "allows nil for optional array attribute" do
        expect(trade.conditions).to be_nil
      end

      it "accepts valid values for all optional attributes" do
        full_trade = described_class.new(
          ticker: "TEST",
          timestamp: "2024-01-15T15:30:25Z",
          price: 100.50,
          size: 200,
          exchange: 1,
          conditions: [14, 37],
          participant_timestamp: 1705328425123456789,
          id: "trade123",
          tape: "A",
          trf_id: 1,
          trf_timestamp: "2024-01-15T15:30:26Z"
        )

        expect(full_trade.timestamp).to eq("2024-01-15T15:30:25Z")
        expect(full_trade.price).to eq(100.50)
        expect(full_trade.size).to eq(200)
        expect(full_trade.exchange).to eq(1)
        expect(full_trade.conditions).to eq([14, 37])
        expect(full_trade.participant_timestamp).to eq(1705328425123456789)
        expect(full_trade.id).to eq("trade123")
        expect(full_trade.tape).to eq("A")
        expect(full_trade.trf_id).to eq(1)
        expect(full_trade.trf_timestamp).to eq("2024-01-15T15:30:26Z")
      end
    end

    context "type constraints" do
      it "accepts integer price" do
        trade = described_class.new(ticker: "TEST", price: 100)
        expect(trade.price).to eq(100)
      end

      it "accepts float price" do
        trade = described_class.new(ticker: "TEST", price: 100.50)
        expect(trade.price).to eq(100.50)
      end

      it "accepts integer size" do
        trade = described_class.new(ticker: "TEST", size: 100)
        expect(trade.size).to eq(100)
      end

      it "accepts integer exchange" do
        trade = described_class.new(ticker: "TEST", exchange: 1)
        expect(trade.exchange).to eq(1)
      end

      it "accepts string exchange" do
        trade = described_class.new(ticker: "TEST", exchange: "NYSE")
        expect(trade.exchange).to eq("NYSE")
      end

      it "accepts array of integers for conditions" do
        trade = described_class.new(ticker: "TEST", conditions: [14, 37, 41])
        expect(trade.conditions).to eq([14, 37, 41])
      end

      it "accepts integer participant_timestamp" do
        trade = described_class.new(ticker: "TEST", participant_timestamp: 1705328425123456789)
        expect(trade.participant_timestamp).to eq(1705328425123456789)
      end

      it "accepts string participant_timestamp" do
        trade = described_class.new(ticker: "TEST", participant_timestamp: "1705328425123456789")
        expect(trade.participant_timestamp).to eq("1705328425123456789")
      end
    end
  end

  # Immutability and structural tests
  describe "immutability" do
    let(:trade) { described_class.new(ticker: "AAPL", price: 174.49, size: 100) }

    it "does not allow attribute modification" do
      expect { trade.ticker = "MSFT" }.to raise_error(NoMethodError)
      expect { trade.price = 200.0 }.to raise_error(NoMethodError)
      expect { trade.size = 200 }.to raise_error(NoMethodError)
    end

    it "is immutable (Dry::Struct behavior)" do
      expect(trade).to be_a(Dry::Struct)
    end
  end

  # Key transformation tests
  describe "key transformation" do
    it "transforms string keys to symbols" do
      data = {"ticker" => "AAPL", "price" => 174.49, "size" => 100}
      trade = described_class.new(data)

      expect(trade.ticker).to eq("AAPL")
      expect(trade.price).to eq(174.49)
      expect(trade.size).to eq(100)
    end

    it "accepts symbol keys directly" do
      data = {ticker: "AAPL", price: 174.49, size: 100}
      trade = described_class.new(data)

      expect(trade.ticker).to eq("AAPL")
      expect(trade.price).to eq(174.49)
      expect(trade.size).to eq(100)
    end
  end

  # Edge cases and boundary tests
  describe "edge cases and boundaries" do
    context "boundary values for block_trade?" do
      it "handles exactly 10,000 shares as boundary" do
        boundary_trade = described_class.new(ticker: "TEST", size: 10_000)
        expect(boundary_trade.block_trade?).to be true

        below_boundary_trade = described_class.new(ticker: "TEST", size: 9_999)
        expect(below_boundary_trade.block_trade?).to be false
      end
    end

    context "mathematical edge cases" do
      it "handles very large prices and sizes" do
        large_trade = described_class.new(ticker: "TEST", price: 999_999.99, size: 1_000_000)
        expect(large_trade.total_value).to eq(999_999_990_000.0)
      end

      it "handles very small prices" do
        small_price_trade = described_class.new(ticker: "TEST", price: 0.01, size: 1)
        expect(small_price_trade.total_value).to eq(0.01)
      end

      it "handles negative prices (if allowed by API)" do
        # Note: Negative prices are unusual but might occur in some edge cases
        negative_trade = described_class.new(ticker: "TEST", price: -1.0, size: 100)
        expect(negative_trade.total_value).to eq(-100.0)
      end
    end

    context "error handling in methods" do
      it "handles malformed timestamp gracefully in regular_hours?" do
        malformed_trade = described_class.new(ticker: "TEST", timestamp: "not-a-timestamp")
        expect(malformed_trade.regular_hours?).to be false
        expect(malformed_trade.extended_hours?).to be true
      end

      it "handles malformed timestamp gracefully in formatted_timestamp" do
        malformed_trade = described_class.new(ticker: "TEST", timestamp: "malformed")
        expect(malformed_trade.formatted_timestamp).to eq("malformed")
      end
    end
  end
end
