# frozen_string_literal: true

require "spec_helper"

RSpec.describe Polymux::Api::Options::Trade do
  let(:trade_data) do
    {
      ticker: "O:AAPL240315C00150000",
      timestamp: 1678901234000000000,
      datetime: DateTime.new(2023, 3, 15, 14, 30, 34),
      price: 3.25,
      size: 5
    }
  end

  let(:trade) { described_class.new(trade_data) }

  describe "initialization" do
    it "accepts trade data hash" do
      trade_instance = described_class.new(trade_data)
      expect(trade_instance).to be_a(described_class)
      expect(trade_instance.ticker).to eq("O:AAPL240315C00150000")
    end

    it "transforms keys to symbols" do
      expect(trade.ticker).to eq("O:AAPL240315C00150000")
      expect(trade.timestamp).to eq(1678901234000000000)
      expect(trade.datetime).to eq(DateTime.new(2023, 3, 15, 14, 30, 34))
      expect(trade.price).to eq(3.25)
      expect(trade.size).to eq(5)
    end
  end

  describe "required attributes" do
    it "requires all trade attributes to be present" do
      expect(trade.ticker).to be_a(String)
      expect(trade.timestamp).to be_an(Integer)
      expect(trade.datetime).to be_a(DateTime)
      expect(trade.price).to be_a(Numeric)
      expect(trade.size).to be_a(Numeric)
    end
  end

  describe "#total_price" do
    it "calculates price multiplied by size" do
      expect(trade.total_price).to eq(16.25) # 3.25 * 5
    end

    it "rounds to 2 decimal places" do
      trade_with_precise = described_class.new(
        trade_data.merge(price: 3.256789, size: 3)
      )

      expect(trade_with_precise.total_price).to eq(9.77) # 3.256789 * 3 = 9.770367, rounded to 9.77
    end

    context "with different price and size combinations" do
      let(:test_cases) do
        [
          {price: 1.50, size: 10, expected: 15.00},
          {price: 2.333, size: 3, expected: 7.00}, # 6.999 rounds to 7.00
          {price: 0.05, size: 100, expected: 5.00},
          {price: 10.0, size: 1, expected: 10.00}
        ]
      end

      it "calculates correctly for various combinations" do
        test_cases.each do |test_case|
          trade = described_class.new(
            trade_data.merge(price: test_case[:price], size: test_case[:size])
          )

          expect(trade.total_price).to eq(test_case[:expected])
        end
      end
    end
  end

  describe "#total_value" do
    it "calculates price × size × 100 (contract multiplier)" do
      expect(trade.total_value).to eq(1625.00) # 3.25 * 5 * 100
    end

    it "rounds to 2 decimal places" do
      trade_with_precise = described_class.new(
        trade_data.merge(price: 3.256789, size: 3)
      )

      expect(trade_with_precise.total_value).to eq(977.04) # 3.256789 * 3 * 100 = 977.0367, rounded to 977.04
    end

    context "with different price and size combinations" do
      let(:test_cases) do
        [
          {price: 1.50, size: 10, expected: 1500.00},
          {price: 2.333, size: 3, expected: 699.90},
          {price: 0.05, size: 100, expected: 500.00},
          {price: 10.0, size: 1, expected: 1000.00}
        ]
      end

      it "calculates correctly for various combinations" do
        test_cases.each do |test_case|
          trade = described_class.new(
            trade_data.merge(price: test_case[:price], size: test_case[:size])
          )

          expect(trade.total_value).to eq(test_case[:expected])
        end
      end
    end
  end

  describe ".from_api" do
    let(:ticker) { "O:AAPL240315C00150000" }
    let(:raw_api_data) do
      {
        "conditions" => [200],
        "price" => 3.25,
        "sip_timestamp" => 1678901234000000000,
        "size" => 5,
        "timeframe" => "REALTIME"
      }
    end

    it "creates Trade object from raw API data" do
      trade = described_class.from_api(ticker, raw_api_data)

      expect(trade).to be_a(described_class)
      expect(trade.ticker).to eq(ticker)
      expect(trade.price).to eq(3.25)
      expect(trade.size).to eq(5)
    end

    it "uses the trade transformer" do
      expect(Polymux::Api::Transformers).to receive(:trade).with(raw_api_data).and_call_original

      described_class.from_api(ticker, raw_api_data)
    end

    it "adds ticker to transformed data" do
      allow(Polymux::Api::Transformers).to receive(:trade).and_return({
        timestamp: 1678901234000000000,
        datetime: DateTime.new(2023, 3, 15, 14, 30, 34),
        price: 3.25,
        size: 5
      })

      trade = described_class.from_api(ticker, raw_api_data)
      expect(trade.ticker).to eq(ticker)
    end
  end

  describe "numeric types handling" do
    context "with integer values" do
      let(:integer_trade) do
        described_class.new(
          trade_data.merge(price: 3, size: 5)
        )
      end

      it "handles integer price and size" do
        expect(integer_trade.price).to eq(3)
        expect(integer_trade.size).to eq(5)
        expect(integer_trade.total_price).to eq(15.00)
        expect(integer_trade.total_value).to eq(1500.00)
      end
    end

    context "with float values" do
      let(:float_trade) do
        described_class.new(
          trade_data.merge(price: 3.75, size: 2.5)
        )
      end

      it "handles float price and size" do
        expect(float_trade.price).to eq(3.75)
        expect(float_trade.size).to eq(2.5)
        expect(float_trade.total_price).to eq(9.38) # 3.75 * 2.5
        expect(float_trade.total_value).to eq(937.50) # 3.75 * 2.5 * 100
      end
    end
  end

  describe "calculation edge cases" do
    context "with zero values" do
      let(:zero_price_trade) do
        described_class.new(trade_data.merge(price: 0, size: 10))
      end

      let(:zero_size_trade) do
        described_class.new(trade_data.merge(price: 5.0, size: 0))
      end

      it "handles zero price correctly" do
        expect(zero_price_trade.total_price).to eq(0.00)
        expect(zero_price_trade.total_value).to eq(0.00)
      end

      it "handles zero size correctly" do
        expect(zero_size_trade.total_price).to eq(0.00)
        expect(zero_size_trade.total_value).to eq(0.00)
      end
    end

    context "with very small values" do
      let(:small_trade) do
        described_class.new(trade_data.merge(price: 0.01, size: 1))
      end

      it "handles small values correctly" do
        expect(small_trade.total_price).to eq(0.01)
        expect(small_trade.total_value).to eq(1.00)
      end
    end

    context "with very large values" do
      let(:large_trade) do
        described_class.new(trade_data.merge(price: 1000.50, size: 100))
      end

      it "handles large values correctly" do
        expect(large_trade.total_price).to eq(100050.00)
        expect(large_trade.total_value).to eq(10005000.00)
      end
    end
  end

  describe "data structure inheritance" do
    it "inherits from Dry::Struct" do
      expect(described_class.superclass).to eq(Dry::Struct)
    end

    it "is immutable" do
      expect { trade.price = 5.0 }.to raise_error(NoMethodError)
    end
  end
end
