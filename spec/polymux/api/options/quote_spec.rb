# frozen_string_literal: true

require "spec_helper"

RSpec.describe Polymux::Api::Options::Quote do
  let(:quote_data) do
    {
      ticker: "O:AAPL240315C00150000",
      timestamp: 1678901234000000000,
      datetime: DateTime.new(2023, 3, 15, 14, 30, 34),
      ask_price: 3.30,
      bid_price: 3.20,
      ask_size: 25,
      bid_size: 30,
      sequence: 12345
    }
  end

  let(:quote) { described_class.new(quote_data) }

  describe "initialization" do
    it "accepts quote data hash" do
      quote_instance = described_class.new(quote_data)
      expect(quote_instance).to be_a(described_class)
      expect(quote_instance.ticker).to eq("O:AAPL240315C00150000")
    end

    it "transforms keys to symbols" do
      expect(quote.ticker).to eq("O:AAPL240315C00150000")
      expect(quote.timestamp).to eq(1678901234000000000)
      expect(quote.datetime).to eq(DateTime.new(2023, 3, 15, 14, 30, 34))
      expect(quote.ask_price).to eq(3.30)
      expect(quote.bid_price).to eq(3.20)
      expect(quote.ask_size).to eq(25)
      expect(quote.bid_size).to eq(30)
      expect(quote.sequence).to eq(12345)
    end
  end

  describe "required attributes" do
    it "requires all quote attributes to be present" do
      expect(quote.ticker).to be_a(String)
      expect(quote.timestamp).to be_an(Integer)
      expect(quote.datetime).to be_a(DateTime)
      expect(quote.ask_price).to be_a(Numeric)
      expect(quote.bid_price).to be_a(Numeric)
      expect(quote.ask_size).to be_an(Integer)
      expect(quote.bid_size).to be_an(Integer)
      expect(quote.sequence).to be_an(Integer)
    end
  end

  describe "#spread" do
    it "calculates ask price minus bid price" do
      expect(quote.spread).to eq(0.10) # 3.30 - 3.20
    end

    it "rounds to 4 decimal places" do
      precise_quote = described_class.new(
        quote_data.merge(ask_price: 3.256789, bid_price: 3.123456)
      )

      expect(precise_quote.spread).to eq(0.1333) # 0.133333 rounded to 4 decimals
    end

    context "with different price combinations" do
      let(:test_cases) do
        [
          {ask: 2.50, bid: 2.45, expected: 0.05},
          {ask: 10.0, bid: 9.5, expected: 0.50},
          {ask: 0.10, bid: 0.05, expected: 0.05},
          {ask: 1.0001, bid: 1.0000, expected: 0.0001}
        ]
      end

      it "calculates correctly for various price combinations" do
        test_cases.each do |test_case|
          quote = described_class.new(
            quote_data.merge(ask_price: test_case[:ask], bid_price: test_case[:bid])
          )

          expect(quote.spread).to eq(test_case[:expected])
        end
      end
    end
  end

  describe "#spread_percentage" do
    it "calculates spread as percentage of midpoint" do
      # midpoint: (3.30 + 3.20) / 2 = 3.25
      # spread: 0.10
      # percentage: (0.10 / 3.25) * 100 = 3.0769%
      expect(quote.spread_percentage).to eq(3.0769)
    end

    it "rounds to 4 decimal places" do
      # Test with values that create precise percentage
      test_quote = described_class.new(
        quote_data.merge(ask_price: 2.02, bid_price: 1.98)
      )
      # midpoint: 2.00, spread: 0.04, percentage: 2.0000%
      expect(test_quote.spread_percentage).to eq(2.0000)
    end

    context "when midpoint is zero" do
      let(:zero_midpoint_quote) do
        described_class.new(
          quote_data.merge(ask_price: 0, bid_price: 0)
        )
      end

      it "returns 0.0 to avoid division by zero" do
        expect(zero_midpoint_quote.spread_percentage).to eq(0.0)
      end
    end

    context "with different spread scenarios" do
      let(:test_cases) do
        [
          {ask: 2.05, bid: 1.95, expected: 5.0}, # 0.10 / 2.00 * 100 = 5%
          {ask: 1.01, bid: 0.99, expected: 2.0}, # 0.02 / 1.00 * 100 = 2%
          {ask: 10.05, bid: 9.95, expected: 1.0} # 0.10 / 10.00 * 100 = 1%
        ]
      end

      it "calculates correctly for various scenarios" do
        test_cases.each do |test_case|
          quote = described_class.new(
            quote_data.merge(ask_price: test_case[:ask], bid_price: test_case[:bid])
          )

          expect(quote.spread_percentage).to eq(test_case[:expected])
        end
      end
    end
  end

  describe "#midpoint" do
    it "calculates average of bid and ask prices" do
      expect(quote.midpoint).to eq(3.25) # (3.30 + 3.20) / 2
    end

    it "rounds to 4 decimal places" do
      precise_quote = described_class.new(
        quote_data.merge(ask_price: 3.333333, bid_price: 3.111111)
      )

      expect(precise_quote.midpoint).to eq(3.2222) # (3.333333 + 3.111111) / 2 = 3.222222, rounded to 3.2222
    end

    context "with different price combinations" do
      let(:test_cases) do
        [
          {ask: 2.50, bid: 2.00, expected: 2.25},
          {ask: 10.0, bid: 8.0, expected: 9.0},
          {ask: 0.10, bid: 0.06, expected: 0.08},
          {ask: 1.0, bid: 1.0, expected: 1.0}
        ]
      end

      it "calculates correctly for various price combinations" do
        test_cases.each do |test_case|
          quote = described_class.new(
            quote_data.merge(ask_price: test_case[:ask], bid_price: test_case[:bid])
          )

          expect(quote.midpoint).to eq(test_case[:expected])
        end
      end
    end
  end

  describe "#crossed?" do
    context "when bid price is greater than ask price" do
      let(:crossed_quote) do
        described_class.new(quote_data.merge(bid_price: 3.40, ask_price: 3.30))
      end

      it "returns true" do
        expect(crossed_quote.crossed?).to be true
      end
    end

    context "when bid price equals ask price" do
      let(:equal_quote) do
        described_class.new(quote_data.merge(bid_price: 3.25, ask_price: 3.25))
      end

      it "returns true" do
        expect(equal_quote.crossed?).to be true
      end
    end

    context "when bid price is less than ask price (normal)" do
      it "returns false" do
        expect(quote.crossed?).to be false
      end
    end
  end

  describe "#bid_notional" do
    it "calculates bid price × bid size × 100" do
      expect(quote.bid_notional).to eq(9600.00) # 3.20 * 30 * 100
    end

    it "rounds to 2 decimal places" do
      precise_quote = described_class.new(
        quote_data.merge(bid_price: 3.256789, bid_size: 33)
      )

      expect(precise_quote.bid_notional).to eq(10747.40) # 3.256789 * 33 * 100 = 10747.4037, rounded to 10747.40
    end

    context "with different combinations" do
      let(:test_cases) do
        [
          {bid_price: 1.50, bid_size: 10, expected: 1500.00},
          {bid_price: 0.05, bid_size: 100, expected: 500.00},
          {bid_price: 10.0, bid_size: 1, expected: 1000.00}
        ]
      end

      it "calculates correctly for various combinations" do
        test_cases.each do |test_case|
          quote = described_class.new(
            quote_data.merge(bid_price: test_case[:bid_price], bid_size: test_case[:bid_size])
          )

          expect(quote.bid_notional).to eq(test_case[:expected])
        end
      end
    end
  end

  describe "#ask_notional" do
    it "calculates ask price × ask size × 100" do
      expect(quote.ask_notional).to eq(8250.00) # 3.30 * 25 * 100
    end

    it "rounds to 2 decimal places" do
      precise_quote = described_class.new(
        quote_data.merge(ask_price: 3.256789, ask_size: 27)
      )

      expect(precise_quote.ask_notional).to eq(8793.33) # 3.256789 * 27 * 100 = 8793.3303, rounded to 8793.33
    end

    context "with different combinations" do
      let(:test_cases) do
        [
          {ask_price: 1.75, ask_size: 20, expected: 3500.00},
          {ask_price: 0.08, ask_size: 200, expected: 1600.00},
          {ask_price: 15.0, ask_size: 5, expected: 7500.00}
        ]
      end

      it "calculates correctly for various combinations" do
        test_cases.each do |test_case|
          quote = described_class.new(
            quote_data.merge(ask_price: test_case[:ask_price], ask_size: test_case[:ask_size])
          )

          expect(quote.ask_notional).to eq(test_case[:expected])
        end
      end
    end
  end

  describe ".from_api" do
    let(:ticker) { "O:AAPL240315C00150000" }
    let(:raw_api_data) do
      {
        "ask_price" => 3.30,
        "ask_size" => 25,
        "bid_price" => 3.20,
        "bid_size" => 30,
        "sip_timestamp" => 1678901234000000000,
        "sequence_number" => 12345,
        "timeframe" => "REALTIME"
      }
    end

    it "creates Quote object from raw API data" do
      quote = described_class.from_api(ticker, raw_api_data)

      expect(quote).to be_a(described_class)
      expect(quote.ticker).to eq(ticker)
      expect(quote.ask_price).to eq(3.30)
      expect(quote.bid_price).to eq(3.20)
      expect(quote.ask_size).to eq(25)
      expect(quote.bid_size).to eq(30)
    end

    it "uses the quote transformer" do
      expect(Polymux::Api::Transformers).to receive(:quote).with(raw_api_data).and_call_original

      described_class.from_api(ticker, raw_api_data)
    end

    it "adds ticker to transformed data" do
      allow(Polymux::Api::Transformers).to receive(:quote).and_return({
        timestamp: 1678901234000000000,
        datetime: DateTime.new(2023, 3, 15, 14, 30, 34),
        ask_price: 3.30,
        bid_price: 3.20,
        ask_size: 25,
        bid_size: 30,
        sequence: 12345
      })

      quote = described_class.from_api(ticker, raw_api_data)
      expect(quote.ticker).to eq(ticker)
    end
  end

  describe "edge cases and validations" do
    context "with zero sizes" do
      let(:zero_sizes_quote) do
        described_class.new(
          quote_data.merge(ask_size: 0, bid_size: 0)
        )
      end

      it "calculates notional values as zero" do
        expect(zero_sizes_quote.ask_notional).to eq(0.00)
        expect(zero_sizes_quote.bid_notional).to eq(0.00)
      end
    end

    context "with very wide spreads" do
      let(:wide_spread_quote) do
        described_class.new(
          quote_data.merge(ask_price: 5.00, bid_price: 1.00)
        )
      end

      it "handles wide spreads correctly" do
        expect(wide_spread_quote.spread).to eq(4.00)
        expect(wide_spread_quote.midpoint).to eq(3.00)
        expect(wide_spread_quote.spread_percentage).to eq(133.3333)
      end
    end
  end

  describe "data structure inheritance" do
    it "inherits from Dry::Struct" do
      expect(described_class.superclass).to eq(Dry::Struct)
    end

    it "is immutable" do
      expect { quote.ask_price = 5.0 }.to raise_error(NoMethodError)
    end
  end
end
