# frozen_string_literal: true

require "spec_helper"

RSpec.describe Polymux::Api::Stocks::Aggregate do
  let(:aggregate_data) do
    {
      ticker: "AAPL",
      open: 173.01,
      high: 180.00, # Adjusted so close is > 2% from high
      low: 165.00,  # Adjusted so close is > 2% from low
      close: 174.49,
      volume: 45678901,
      vwap: 174.25,
      timestamp: 1705363200000, # 2024-01-16 in milliseconds
      transactions: 123456
    }
  end

  let(:aggregate) { described_class.new(aggregate_data) }

  describe "initialization" do
    it "creates an aggregate with all attributes" do
      expect(aggregate.ticker).to eq("AAPL")
      expect(aggregate.open).to eq(173.01)
      expect(aggregate.high).to eq(180.00)
      expect(aggregate.low).to eq(165.00)
      expect(aggregate.close).to eq(174.49)
      expect(aggregate.volume).to eq(45678901)
      expect(aggregate.vwap).to eq(174.25)
      expect(aggregate.timestamp).to eq(1705363200000)
      expect(aggregate.transactions).to eq(123456)
    end

    it "handles optional attributes" do
      minimal_aggregate = described_class.new(ticker: "TEST")
      expect(minimal_aggregate.ticker).to eq("TEST")
      expect(minimal_aggregate.open).to be_nil
      expect(minimal_aggregate.high).to be_nil
      expect(minimal_aggregate.low).to be_nil
      expect(minimal_aggregate.close).to be_nil
      expect(minimal_aggregate.volume).to be_nil
      expect(minimal_aggregate.vwap).to be_nil
      expect(minimal_aggregate.timestamp).to be_nil
      expect(minimal_aggregate.transactions).to be_nil
    end

    it "is instance of Polymux::Api::Stocks::Aggregate" do
      expect(aggregate).to be_instance_of(Polymux::Api::Stocks::Aggregate)
    end

    it "inherits from Dry::Struct" do
      expect(aggregate).to be_a(Dry::Struct)
    end
  end

  describe "#green?" do
    context "when close > open" do
      it "returns true" do
        expect(aggregate.green?).to be true # 174.49 > 173.01
      end

      it "returns true for small gains" do
        small_gain = described_class.new(ticker: "TEST", open: 100.00, close: 100.01)
        expect(small_gain.green?).to be true
      end

      it "returns true for large gains" do
        large_gain = described_class.new(ticker: "TEST", open: 100.00, close: 150.00)
        expect(large_gain.green?).to be true
      end
    end

    context "when close < open" do
      it "returns false" do
        red_bar = described_class.new(ticker: "TEST", open: 175.00, close: 174.00)
        expect(red_bar.green?).to be false
      end
    end

    context "when close == open" do
      it "returns false" do
        doji_bar = described_class.new(ticker: "TEST", open: 174.00, close: 174.00)
        expect(doji_bar.green?).to be false
      end
    end

    context "when open is nil" do
      it "returns false" do
        no_open = described_class.new(ticker: "TEST", close: 174.49)
        expect(no_open.green?).to be false
      end
    end

    context "when close is nil" do
      it "returns false" do
        no_close = described_class.new(ticker: "TEST", open: 173.01)
        expect(no_close.green?).to be false
      end
    end

    context "when both are nil" do
      it "returns false" do
        no_data = described_class.new(ticker: "TEST")
        expect(no_data.green?).to be false
      end
    end
  end

  describe "#red?" do
    context "when close < open" do
      it "returns true" do
        red_bar = described_class.new(ticker: "TEST", open: 175.00, close: 174.00)
        expect(red_bar.red?).to be true
      end

      it "returns true for small losses" do
        small_loss = described_class.new(ticker: "TEST", open: 100.00, close: 99.99)
        expect(small_loss.red?).to be true
      end

      it "returns true for large losses" do
        large_loss = described_class.new(ticker: "TEST", open: 100.00, close: 50.00)
        expect(large_loss.red?).to be true
      end
    end

    context "when close > open" do
      it "returns false" do
        expect(aggregate.red?).to be false # 174.49 > 173.01
      end
    end

    context "when close == open" do
      it "returns false" do
        doji_bar = described_class.new(ticker: "TEST", open: 174.00, close: 174.00)
        expect(doji_bar.red?).to be false
      end
    end

    context "when open is nil" do
      it "returns false" do
        no_open = described_class.new(ticker: "TEST", close: 174.49)
        expect(no_open.red?).to be false
      end
    end

    context "when close is nil" do
      it "returns false" do
        no_close = described_class.new(ticker: "TEST", open: 173.01)
        expect(no_close.red?).to be false
      end
    end
  end

  describe "#doji?" do
    context "when close == open" do
      it "returns true" do
        doji_bar = described_class.new(ticker: "TEST", open: 174.00, close: 174.00)
        expect(doji_bar.doji?).to be true
      end

      it "returns true for zero prices" do
        zero_doji = described_class.new(ticker: "TEST", open: 0.0, close: 0.0)
        expect(zero_doji.doji?).to be true
      end
    end

    context "when close != open" do
      it "returns false for green bars" do
        expect(aggregate.doji?).to be false # 174.49 != 173.01
      end

      it "returns false for red bars" do
        red_bar = described_class.new(ticker: "TEST", open: 175.00, close: 174.00)
        expect(red_bar.doji?).to be false
      end
    end

    context "when data is missing" do
      it "returns false when open is nil" do
        no_open = described_class.new(ticker: "TEST", close: 174.49)
        expect(no_open.doji?).to be false
      end

      it "returns false when close is nil" do
        no_close = described_class.new(ticker: "TEST", open: 173.01)
        expect(no_close.doji?).to be false
      end
    end
  end

  describe "#body_size" do
    context "when both open and close are present" do
      it "calculates body size correctly for green bar" do
        expect(aggregate.body_size).to eq(1.48) # |174.49 - 173.01|
      end

      it "calculates body size correctly for red bar" do
        red_bar = described_class.new(ticker: "TEST", open: 175.00, close: 174.00)
        expect(red_bar.body_size).to eq(1.0) # |174.00 - 175.00|
      end

      it "returns zero for doji" do
        doji_bar = described_class.new(ticker: "TEST", open: 174.00, close: 174.00)
        expect(doji_bar.body_size).to eq(0.0)
      end

      it "handles decimal precision" do
        precise_bar = described_class.new(ticker: "TEST", open: 123.456, close: 123.789)
        expect(precise_bar.body_size).to eq(0.333)
      end
    end

    context "when data is missing" do
      it "returns nil when open is nil" do
        no_open = described_class.new(ticker: "TEST", close: 174.49)
        expect(no_open.body_size).to be_nil
      end

      it "returns nil when close is nil" do
        no_close = described_class.new(ticker: "TEST", open: 173.01)
        expect(no_close.body_size).to be_nil
      end
    end
  end

  describe "#range" do
    context "when both high and low are present" do
      it "calculates range correctly" do
        expect(aggregate.range).to eq(15.0) # 180.00 - 165.00
      end

      it "handles zero range" do
        flat_bar = described_class.new(ticker: "TEST", high: 100.0, low: 100.0)
        expect(flat_bar.range).to eq(0.0)
      end

      it "handles decimal precision" do
        precise_bar = described_class.new(ticker: "TEST", high: 123.789, low: 123.456)
        expect(precise_bar.range).to eq(0.333)
      end
    end

    context "when data is missing" do
      it "returns nil when high is nil" do
        no_high = described_class.new(ticker: "TEST", low: 172.30)
        expect(no_high.range).to be_nil
      end

      it "returns nil when low is nil" do
        no_low = described_class.new(ticker: "TEST", high: 175.50)
        expect(no_low.range).to be_nil
      end
    end
  end

  describe "#range_percent" do
    context "when range, open are present and open > 0" do
      it "calculates range percentage correctly" do
        # range = 15.0, open = 173.01, percentage = (15.0 / 173.01) * 100 = 8.6714%
        expected = (15.0 / 173.01 * 100).round(4)
        expect(aggregate.range_percent).to eq(expected)
      end

      it "handles large ranges" do
        volatile_bar = described_class.new(ticker: "TEST", open: 100.0, high: 120.0, low: 80.0)
        # range = 40.0, open = 100.0, percentage = 40.0%
        expect(volatile_bar.range_percent).to eq(40.0)
      end

      it "handles small ranges" do
        tight_bar = described_class.new(ticker: "TEST", open: 100.0, high: 100.1, low: 99.9)
        # range = 0.2, open = 100.0, percentage = 0.2%
        expect(tight_bar.range_percent).to eq(0.2)
      end

      it "rounds to 4 decimal places" do
        result = aggregate.range_percent
        decimal_places = result.to_s.split(".")[1]&.length || 0
        expect(decimal_places).to be <= 4
      end
    end

    context "when range is nil" do
      it "returns nil" do
        no_range = described_class.new(ticker: "TEST", open: 173.01, high: 175.50)
        expect(no_range.range_percent).to be_nil
      end
    end

    context "when open is nil" do
      it "returns nil" do
        no_open = described_class.new(ticker: "TEST", high: 175.50, low: 172.30)
        expect(no_open.range_percent).to be_nil
      end
    end

    context "when open is zero or negative" do
      it "returns nil for zero open" do
        zero_open = described_class.new(ticker: "TEST", open: 0.0, high: 10.0, low: -5.0)
        expect(zero_open.range_percent).to be_nil
      end

      it "returns nil for negative open" do
        negative_open = described_class.new(ticker: "TEST", open: -10.0, high: -5.0, low: -15.0)
        expect(negative_open.range_percent).to be_nil
      end
    end
  end

  describe "#upper_shadow" do
    context "when all OHLC prices are present" do
      it "calculates upper shadow correctly for green bar" do
        # body_top = max(173.01, 174.49) = 174.49
        # upper_shadow = 180.00 - 174.49 = 5.51
        expect(aggregate.upper_shadow).to eq(5.51)
      end

      it "calculates upper shadow correctly for red bar" do
        red_bar = described_class.new(ticker: "TEST", open: 175.00, high: 176.00, low: 174.00, close: 174.50)
        # body_top = max(175.00, 174.50) = 175.00
        # upper_shadow = 176.00 - 175.00 = 1.00
        expect(red_bar.upper_shadow).to eq(1.0)
      end

      it "returns zero when high equals body top" do
        no_upper_wick = described_class.new(ticker: "TEST", open: 100.0, high: 101.0, low: 99.0, close: 101.0)
        expect(no_upper_wick.upper_shadow).to eq(0.0)
      end

      it "handles doji bars" do
        doji = described_class.new(ticker: "TEST", open: 100.0, high: 101.0, low: 99.0, close: 100.0)
        expect(doji.upper_shadow).to eq(1.0) # 101.0 - 100.0
      end
    end

    context "when data is missing" do
      it "returns nil when high is nil" do
        no_high = described_class.new(ticker: "TEST", open: 173.01, close: 174.49)
        expect(no_high.upper_shadow).to be_nil
      end

      it "returns nil when open is nil" do
        no_open = described_class.new(ticker: "TEST", high: 175.50, close: 174.49)
        expect(no_open.upper_shadow).to be_nil
      end

      it "returns nil when close is nil" do
        no_close = described_class.new(ticker: "TEST", open: 173.01, high: 175.50)
        expect(no_close.upper_shadow).to be_nil
      end
    end
  end

  describe "#lower_shadow" do
    context "when all OHLC prices are present" do
      it "calculates lower shadow correctly for green bar" do
        # body_bottom = min(173.01, 174.49) = 173.01
        # lower_shadow = 173.01 - 165.00 = 8.01
        expect(aggregate.lower_shadow).to eq(8.01)
      end

      it "calculates lower shadow correctly for red bar" do
        red_bar = described_class.new(ticker: "TEST", open: 175.00, high: 176.00, low: 173.50, close: 174.00)
        # body_bottom = min(175.00, 174.00) = 174.00
        # lower_shadow = 174.00 - 173.50 = 0.50
        expect(red_bar.lower_shadow).to eq(0.5)
      end

      it "returns zero when low equals body bottom" do
        no_lower_wick = described_class.new(ticker: "TEST", open: 100.0, high: 101.0, low: 100.0, close: 101.0)
        expect(no_lower_wick.lower_shadow).to eq(0.0)
      end

      it "handles doji bars" do
        doji = described_class.new(ticker: "TEST", open: 100.0, high: 101.0, low: 99.0, close: 100.0)
        expect(doji.lower_shadow).to eq(1.0) # 100.0 - 99.0
      end
    end

    context "when data is missing" do
      it "returns nil when low is nil" do
        no_low = described_class.new(ticker: "TEST", open: 173.01, close: 174.49)
        expect(no_low.lower_shadow).to be_nil
      end

      it "returns nil when open is nil" do
        no_open = described_class.new(ticker: "TEST", low: 172.30, close: 174.49)
        expect(no_open.lower_shadow).to be_nil
      end

      it "returns nil when close is nil" do
        no_close = described_class.new(ticker: "TEST", open: 173.01, low: 172.30)
        expect(no_close.lower_shadow).to be_nil
      end
    end
  end

  describe "#change_percent" do
    context "when open, close are present and open > 0" do
      it "calculates change percentage correctly for green bar" do
        # change = (174.49 - 173.01) / 173.01 * 100 = 0.8559%
        expected = ((174.49 - 173.01) / 173.01 * 100).round(4)
        expect(aggregate.change_percent).to eq(expected)
      end

      it "calculates change percentage correctly for red bar" do
        red_bar = described_class.new(ticker: "TEST", open: 175.00, close: 174.00)
        # change = (174.00 - 175.00) / 175.00 * 100 = -0.5714%
        expected = ((174.00 - 175.00) / 175.00 * 100).round(4)
        expect(red_bar.change_percent).to eq(expected)
      end

      it "returns zero for doji" do
        doji = described_class.new(ticker: "TEST", open: 100.0, close: 100.0)
        expect(doji.change_percent).to eq(0.0)
      end

      it "rounds to 4 decimal places" do
        result = aggregate.change_percent
        decimal_places = result.to_s.split(".")[1]&.length || 0
        expect(decimal_places).to be <= 4
      end
    end

    context "when data is missing or invalid" do
      it "returns nil when open is nil" do
        no_open = described_class.new(ticker: "TEST", close: 174.49)
        expect(no_open.change_percent).to be_nil
      end

      it "returns nil when close is nil" do
        no_close = described_class.new(ticker: "TEST", open: 173.01)
        expect(no_close.change_percent).to be_nil
      end

      it "returns nil when open is zero" do
        zero_open = described_class.new(ticker: "TEST", open: 0.0, close: 10.0)
        expect(zero_open.change_percent).to be_nil
      end

      it "returns nil when open is negative" do
        negative_open = described_class.new(ticker: "TEST", open: -10.0, close: -5.0)
        expect(negative_open.change_percent).to be_nil
      end
    end
  end

  describe "#change_amount" do
    context "when both open and close are present" do
      it "calculates change amount correctly for green bar" do
        expect(aggregate.change_amount).to eq(1.48) # 174.49 - 173.01
      end

      it "calculates change amount correctly for red bar" do
        red_bar = described_class.new(ticker: "TEST", open: 175.00, close: 174.00)
        expect(red_bar.change_amount).to eq(-1.0) # 174.00 - 175.00
      end

      it "returns zero for doji" do
        doji = described_class.new(ticker: "TEST", open: 100.0, close: 100.0)
        expect(doji.change_amount).to eq(0.0)
      end

      it "handles decimal precision" do
        precise_bar = described_class.new(ticker: "TEST", open: 123.456, close: 123.789)
        expect(precise_bar.change_amount).to eq(0.333)
      end
    end

    context "when data is missing" do
      it "returns nil when open is nil" do
        no_open = described_class.new(ticker: "TEST", close: 174.49)
        expect(no_open.change_amount).to be_nil
      end

      it "returns nil when close is nil" do
        no_close = described_class.new(ticker: "TEST", open: 173.01)
        expect(no_close.change_amount).to be_nil
      end
    end
  end

  describe "#high_volume?" do
    context "when volume is present" do
      it "returns true for volume > 1,000,000" do
        expect(aggregate.high_volume?).to be true # 45,678,901 > 1,000,000
      end

      it "returns false for volume <= 1,000,000" do
        low_volume = described_class.new(ticker: "TEST", volume: 500_000)
        expect(low_volume.high_volume?).to be false
      end

      it "returns false for exactly 1,000,000" do
        exactly_threshold = described_class.new(ticker: "TEST", volume: 1_000_000)
        expect(exactly_threshold.high_volume?).to be false
      end

      it "returns true for just above threshold" do
        just_above = described_class.new(ticker: "TEST", volume: 1_000_001)
        expect(just_above.high_volume?).to be true
      end

      it "returns false for zero volume" do
        zero_volume = described_class.new(ticker: "TEST", volume: 0)
        expect(zero_volume.high_volume?).to be false
      end
    end

    context "when volume is nil" do
      it "returns false" do
        no_volume = described_class.new(ticker: "TEST")
        expect(no_volume.high_volume?).to be false
      end
    end
  end

  describe "#turnover_ratio" do
    context "when volume and shares_outstanding are valid" do
      it "calculates turnover ratio correctly" do
        shares_outstanding = 15_550_061_000 # Apple's approximate shares outstanding
        expected = (45_678_901.to_f / shares_outstanding * 100).round(4)
        expect(aggregate.turnover_ratio(shares_outstanding)).to eq(expected)
      end

      it "handles high turnover scenarios" do
        high_vol = described_class.new(ticker: "TEST", volume: 10_000_000)
        shares = 50_000_000
        expected = (10_000_000.to_f / 50_000_000 * 100).round(4)
        expect(high_vol.turnover_ratio(shares)).to eq(expected)
      end

      it "handles zero volume" do
        zero_vol = described_class.new(ticker: "TEST", volume: 0)
        expect(zero_vol.turnover_ratio(1_000_000)).to eq(0.0)
      end

      it "rounds to 4 decimal places" do
        result = aggregate.turnover_ratio(15_550_061_000)
        decimal_places = result.to_s.split(".")[1]&.length || 0
        expect(decimal_places).to be <= 4
      end
    end

    context "when data is missing or invalid" do
      it "returns nil when volume is nil" do
        no_volume = described_class.new(ticker: "TEST")
        expect(no_volume.turnover_ratio(1_000_000)).to be_nil
      end

      it "returns nil when shares_outstanding is nil" do
        expect(aggregate.turnover_ratio(nil)).to be_nil
      end

      it "returns nil when shares_outstanding is zero" do
        expect(aggregate.turnover_ratio(0)).to be_nil
      end

      it "returns nil when shares_outstanding is negative" do
        expect(aggregate.turnover_ratio(-1_000_000)).to be_nil
      end
    end
  end

  describe "#typical_price" do
    context "when high, low, and close are present" do
      it "calculates typical price correctly" do
        expected = (180.00 + 165.00 + 174.49) / 3.0
        expect(aggregate.typical_price).to eq(expected)
      end

      it "handles identical prices" do
        flat_bar = described_class.new(ticker: "TEST", high: 100.0, low: 100.0, close: 100.0)
        expect(flat_bar.typical_price).to eq(100.0)
      end

      it "handles decimal precision" do
        precise_bar = described_class.new(ticker: "TEST", high: 123.789, low: 123.456, close: 123.622)
        expected = (123.789 + 123.456 + 123.622) / 3.0
        expect(precise_bar.typical_price).to eq(expected)
      end
    end

    context "when data is missing" do
      it "returns nil when high is nil" do
        no_high = described_class.new(ticker: "TEST", low: 172.30, close: 174.49)
        expect(no_high.typical_price).to be_nil
      end

      it "returns nil when low is nil" do
        no_low = described_class.new(ticker: "TEST", high: 175.50, close: 174.49)
        expect(no_low.typical_price).to be_nil
      end

      it "returns nil when close is nil" do
        no_close = described_class.new(ticker: "TEST", high: 175.50, low: 172.30)
        expect(no_close.typical_price).to be_nil
      end
    end
  end

  describe "#vwap_above_close?" do
    context "when both vwap and close are present" do
      it "returns false when vwap <= close" do
        expect(aggregate.vwap_above_close?).to be false # 174.25 <= 174.49
      end

      it "returns true when vwap > close" do
        vwap_higher = described_class.new(ticker: "TEST", vwap: 175.0, close: 174.0)
        expect(vwap_higher.vwap_above_close?).to be true
      end

      it "returns false when vwap == close" do
        vwap_equal = described_class.new(ticker: "TEST", vwap: 174.0, close: 174.0)
        expect(vwap_equal.vwap_above_close?).to be false
      end
    end

    context "when data is missing" do
      it "returns nil when vwap is nil" do
        no_vwap = described_class.new(ticker: "TEST", close: 174.49)
        expect(no_vwap.vwap_above_close?).to be_nil
      end

      it "returns nil when close is nil" do
        no_close = described_class.new(ticker: "TEST", vwap: 174.25)
        expect(no_close.vwap_above_close?).to be_nil
      end
    end
  end

  describe "#close_near_high?" do
    context "when close and high are present and high > 0" do
      it "returns false when close is not near high" do
        expect(aggregate.close_near_high?).to be false # (175.50 - 174.49) / 175.50 = 0.0058 > 0.02
      end

      it "returns true when close is within 2% of high" do
        near_high = described_class.new(ticker: "TEST", high: 100.0, close: 98.5) # 1.5% from high
        expect(near_high.close_near_high?).to be true
      end

      it "returns true when close equals high" do
        at_high = described_class.new(ticker: "TEST", high: 100.0, close: 100.0)
        expect(at_high.close_near_high?).to be true
      end

      it "returns true for exactly 2% from high" do
        exactly_2pct = described_class.new(ticker: "TEST", high: 100.0, close: 98.0)
        expect(exactly_2pct.close_near_high?).to be true
      end

      it "returns false for just over 2% from high" do
        just_over_2pct = described_class.new(ticker: "TEST", high: 100.0, close: 97.9)
        expect(just_over_2pct.close_near_high?).to be false
      end
    end

    context "when data is missing or invalid" do
      it "returns false when close is nil" do
        no_close = described_class.new(ticker: "TEST", high: 175.50)
        expect(no_close.close_near_high?).to be false
      end

      it "returns false when high is nil" do
        no_high = described_class.new(ticker: "TEST", close: 174.49)
        expect(no_high.close_near_high?).to be false
      end

      it "returns false when high is zero" do
        zero_high = described_class.new(ticker: "TEST", high: 0.0, close: 10.0)
        expect(zero_high.close_near_high?).to be false
      end

      it "returns false when high is negative" do
        negative_high = described_class.new(ticker: "TEST", high: -10.0, close: -9.0)
        expect(negative_high.close_near_high?).to be false
      end
    end
  end

  describe "#close_near_low?" do
    context "when close and low are present and low > 0" do
      it "returns false when close is not near low" do
        expect(aggregate.close_near_low?).to be false # (174.49 - 172.30) / 172.30 = 0.0127 > 0.02
      end

      it "returns true when close is within 2% of low" do
        near_low = described_class.new(ticker: "TEST", low: 100.0, close: 101.5) # 1.5% from low
        expect(near_low.close_near_low?).to be true
      end

      it "returns true when close equals low" do
        at_low = described_class.new(ticker: "TEST", low: 100.0, close: 100.0)
        expect(at_low.close_near_low?).to be true
      end

      it "returns true for exactly 2% from low" do
        exactly_2pct = described_class.new(ticker: "TEST", low: 100.0, close: 102.0)
        expect(exactly_2pct.close_near_low?).to be true
      end

      it "returns false for just over 2% from low" do
        just_over_2pct = described_class.new(ticker: "TEST", low: 100.0, close: 102.1)
        expect(just_over_2pct.close_near_low?).to be false
      end
    end

    context "when data is missing or invalid" do
      it "returns false when close is nil" do
        no_close = described_class.new(ticker: "TEST", low: 172.30)
        expect(no_close.close_near_low?).to be false
      end

      it "returns false when low is nil" do
        no_low = described_class.new(ticker: "TEST", close: 174.49)
        expect(no_low.close_near_low?).to be false
      end

      it "returns false when low is zero" do
        zero_low = described_class.new(ticker: "TEST", low: 0.0, close: 10.0)
        expect(zero_low.close_near_low?).to be false
      end

      it "returns false when low is negative" do
        negative_low = described_class.new(ticker: "TEST", low: -10.0, close: -9.0)
        expect(negative_low.close_near_low?).to be false
      end
    end
  end

  describe "#formatted_timestamp" do
    context "with valid timestamps in milliseconds" do
      it "formats timestamp correctly" do
        expect(aggregate.formatted_timestamp).to eq("2024-01-16")
      end

      it "handles different dates" do
        different_date = described_class.new(ticker: "TEST", timestamp: 1577836800000) # 2020-01-01
        expect(different_date.formatted_timestamp).to eq("2020-01-01")
      end
    end

    context "with invalid or missing timestamps" do
      it "returns 'N/A' when timestamp is nil" do
        no_timestamp = described_class.new(ticker: "TEST")
        expect(no_timestamp.formatted_timestamp).to eq("N/A")
      end

      it "handles invalid timestamp gracefully" do
        invalid_timestamp = described_class.new(ticker: "TEST", timestamp: "invalid")
        expect(invalid_timestamp.formatted_timestamp).to eq("invalid")
      end
    end
  end

  describe "#formatted_datetime" do
    context "with valid timestamps in milliseconds" do
      it "formats datetime correctly" do
        expect(aggregate.formatted_datetime).to eq("2024-01-16 00:00:00")
      end

      it "handles timestamps with time component" do
        with_time = described_class.new(ticker: "TEST", timestamp: 1705374825000) # includes time
        formatted = with_time.formatted_datetime
        expect(formatted).to start_with("2024-01-16")
        expect(formatted).to include(":")
      end
    end

    context "with invalid or missing timestamps" do
      it "returns 'N/A' when timestamp is nil" do
        no_timestamp = described_class.new(ticker: "TEST")
        expect(no_timestamp.formatted_datetime).to eq("N/A")
      end

      it "handles invalid timestamp gracefully" do
        invalid_timestamp = described_class.new(ticker: "TEST", timestamp: "invalid")
        expect(invalid_timestamp.formatted_datetime).to eq("invalid")
      end
    end
  end

  describe "#ohlc_string" do
    context "when all OHLC prices are present" do
      it "formats OHLC correctly" do
        expect(aggregate.ohlc_string).to eq("O:173.01 H:180.0 L:165.0 C:174.49")
      end

      it "handles integer prices" do
        integer_bar = described_class.new(ticker: "TEST", open: 100, high: 105, low: 95, close: 102)
        expect(integer_bar.ohlc_string).to eq("O:100 H:105 L:95 C:102")
      end
    end

    context "when any OHLC price is missing" do
      it "returns 'N/A' when open is nil" do
        no_open = described_class.new(ticker: "TEST", high: 175.50, low: 172.30, close: 174.49)
        expect(no_open.ohlc_string).to eq("N/A")
      end

      it "returns 'N/A' when high is nil" do
        no_high = described_class.new(ticker: "TEST", open: 173.01, low: 172.30, close: 174.49)
        expect(no_high.ohlc_string).to eq("N/A")
      end

      it "returns 'N/A' when low is nil" do
        no_low = described_class.new(ticker: "TEST", open: 173.01, high: 175.50, close: 174.49)
        expect(no_low.ohlc_string).to eq("N/A")
      end

      it "returns 'N/A' when close is nil" do
        no_close = described_class.new(ticker: "TEST", open: 173.01, high: 175.50, low: 172.30)
        expect(no_close.ohlc_string).to eq("N/A")
      end
    end
  end

  describe ".from_api" do
    let(:api_data) do
      {
        "o" => 173.01,
        "h" => 175.50,
        "l" => 172.30,
        "c" => 174.49,
        "v" => 45678901,
        "vw" => 174.25,
        "t" => 1705363200000,
        "n" => 123456
      }
    end

    it "creates Aggregate object from API response" do
      aggregate = described_class.from_api("AAPL", api_data)

      expect(aggregate).to be_a(described_class)
      expect(aggregate.ticker).to eq("AAPL")
      # The transformer will handle the field mapping
    end

    context "with minimal API data" do
      let(:minimal_api_data) { {"c" => 100.0} }

      it "creates Aggregate with ticker from method parameter" do
        aggregate = described_class.from_api("TEST", minimal_api_data)
        expect(aggregate.ticker).to eq("TEST")
      end
    end

    it "calls Api::Transformers.stock_aggregate for data transformation" do
      expect(Polymux::Api::Transformers).to receive(:stock_aggregate).with("AAPL", api_data).and_call_original
      described_class.from_api("AAPL", api_data)
    end
  end

  # Mutation resistance tests
  describe "mutation resistance" do
    context "exact comparisons in boolean methods" do
      it "uses exact > comparison for green?, not >=" do
        equal_prices = described_class.new(ticker: "TEST", open: 100.0, close: 100.0)
        expect(equal_prices.green?).to be false
      end

      it "uses exact < comparison for red?, not <=" do
        equal_prices = described_class.new(ticker: "TEST", open: 100.0, close: 100.0)
        expect(equal_prices.red?).to be false
      end

      it "uses exact == comparison for doji?, not approximate" do
        almost_equal = described_class.new(ticker: "TEST", open: 100.0, close: 100.0001)
        expect(almost_equal.doji?).to be false
      end

      it "uses exact > comparison for high_volume?, not >=" do
        exactly_threshold = described_class.new(ticker: "TEST", volume: 1_000_000)
        expect(exactly_threshold.high_volume?).to be false
      end

      it "uses exact > 0 checks in calculations" do
        zero_open = described_class.new(ticker: "TEST", open: 0.0, close: 10.0)
        zero_high = described_class.new(ticker: "TEST", high: 0.0, close: 10.0)
        zero_low = described_class.new(ticker: "TEST", low: 0.0, close: 10.0)

        expect(zero_open.change_percent).to be_nil
        expect(zero_open.range_percent).to be_nil
        expect(zero_high.close_near_high?).to be false
        expect(zero_low.close_near_low?).to be false
      end
    end
  end
end
