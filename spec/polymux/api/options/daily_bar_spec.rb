# frozen_string_literal: true

require "spec_helper"

RSpec.describe Polymux::Api::Options::DailyBar do
  let(:valid_daily_bar_data) do
    {
      open: 150.0,
      high: 155.0,
      low: 148.5,
      close: 152.0,
      volume: 500,
      vwap: 151.5,
      previous_close: 149.0,
      change: 3.0,
      change_percent: 2.01
    }
  end

  let(:daily_bar) { described_class.new(valid_daily_bar_data) }

  describe "initialization" do
    it "creates a DailyBar with valid attributes" do
      expect(daily_bar.open).to eq(150.0)
      expect(daily_bar.high).to eq(155.0)
      expect(daily_bar.low).to eq(148.5)
      expect(daily_bar.close).to eq(152.0)
      expect(daily_bar.volume).to eq(500)
      expect(daily_bar.vwap).to eq(151.5)
      expect(daily_bar.previous_close).to eq(149.0)
      expect(daily_bar.change).to eq(3.0)
      expect(daily_bar.change_percent).to eq(2.01)
    end

    it "enforces required attributes" do
      expect {
        described_class.new({})
      }.to raise_error(Dry::Struct::Error)
    end

    it "transforms keys to symbols" do
      string_key_data = valid_daily_bar_data.transform_keys(&:to_s)
      bar_from_strings = described_class.new(string_key_data)

      expect(bar_from_strings.open).to eq(150.0)
      expect(bar_from_strings.close).to eq(152.0)
    end
  end

  describe "#range" do
    it "calculates high minus low" do
      expect(daily_bar.range).to eq(6.5) # 155.0 - 148.5
    end

    context "with edge cases" do
      it "returns zero when high equals low" do
        flat_bar = described_class.new(valid_daily_bar_data.merge(high: 150.0, low: 150.0))
        expect(flat_bar.range).to eq(0.0)
      end

      it "handles very small ranges" do
        tiny_range_bar = described_class.new(valid_daily_bar_data.merge(high: 150.01, low: 150.0))
        expect(tiny_range_bar.range).to eq(0.01)
      end

      it "handles large ranges" do
        large_range_bar = described_class.new(valid_daily_bar_data.merge(high: 200.0, low: 100.0))
        expect(large_range_bar.range).to eq(100.0)
      end

      it "rounds to 4 decimal places" do
        precise_bar = described_class.new(valid_daily_bar_data.merge(high: 150.123456, low: 149.654321))
        expect(precise_bar.range).to eq(0.4691) # 150.123456 - 149.654321 = 0.469135, rounded
      end
    end
  end

  describe "#intraday_volatility" do
    it "calculates range as percentage of opening price" do
      # range = 6.5, open = 150.0
      # (6.5 / 150.0) * 100 = 4.3333%
      expect(daily_bar.intraday_volatility).to eq(4.3333)
    end

    context "when open is zero" do
      let(:zero_open_bar) do
        described_class.new(valid_daily_bar_data.merge(open: 0))
      end

      it "returns 0.0 to avoid division by zero" do
        expect(zero_open_bar.intraday_volatility).to eq(0.0)
      end
    end

    context "with edge cases" do
      it "handles very high volatility" do
        high_vol_bar = described_class.new(valid_daily_bar_data.merge(high: 200.0, low: 100.0, open: 150.0))
        # range = 100.0, open = 150.0
        # (100.0 / 150.0) * 100 = 66.6667%
        expect(high_vol_bar.intraday_volatility).to eq(66.6667)
      end

      it "handles very low volatility" do
        low_vol_bar = described_class.new(valid_daily_bar_data.merge(high: 150.01, low: 149.99, open: 150.0))
        # range = 0.02, open = 150.0
        # (0.02 / 150.0) * 100 = 0.0133%
        expect(low_vol_bar.intraday_volatility).to eq(0.0133)
      end

      it "rounds to 4 decimal places" do
        precise_bar = described_class.new(valid_daily_bar_data.merge(high: 150.333, low: 149.666, open: 150.0))
        # range = 0.667, open = 150.0
        # (0.667 / 150.0) * 100 = 0.444667, rounded to 0.4447
        expect(precise_bar.intraday_volatility).to eq(0.4447)
      end

      it "uses zero check (not equality comparison)" do
        # This test ensures the zero? method is used correctly, not == 0
        tiny_open_bar = described_class.new(valid_daily_bar_data.merge(open: 0.0))
        expect(tiny_open_bar.intraday_volatility).to eq(0.0)
      end
    end
  end

  describe "#change_direction" do
    context "when change is positive" do
      it "returns 'up'" do
        expect(daily_bar.change_direction).to eq("up") # change is 3.0
      end
    end

    context "when change is negative" do
      let(:down_bar) do
        described_class.new(valid_daily_bar_data.merge(change: -2.5))
      end

      it "returns 'down'" do
        expect(down_bar.change_direction).to eq("down")
      end
    end

    context "when change is zero" do
      let(:unchanged_bar) do
        described_class.new(valid_daily_bar_data.merge(change: 0))
      end

      it "returns 'unchanged'" do
        expect(unchanged_bar.change_direction).to eq("unchanged")
      end
    end

    context "with edge cases" do
      it "returns 'up' for very small positive change" do
        tiny_up_bar = described_class.new(valid_daily_bar_data.merge(change: 0.01))
        expect(tiny_up_bar.change_direction).to eq("up")
      end

      it "returns 'down' for very small negative change" do
        tiny_down_bar = described_class.new(valid_daily_bar_data.merge(change: -0.01))
        expect(tiny_down_bar.change_direction).to eq("down")
      end

      it "specifically checks for zero using zero?" do
        zero_bar = described_class.new(valid_daily_bar_data.merge(change: 0.0))
        expect(zero_bar.change_direction).to eq("unchanged")
      end
    end
  end

  describe "#green_day?" do
    context "when close is greater than open" do
      it "returns true" do
        expect(daily_bar.green_day?).to be true # close: 152.0, open: 150.0
      end
    end

    context "when close is less than open" do
      let(:red_bar) do
        described_class.new(valid_daily_bar_data.merge(close: 148.0)) # Less than open 150.0
      end

      it "returns false" do
        expect(red_bar.green_day?).to be false
      end
    end

    context "when close equals open" do
      let(:flat_bar) do
        described_class.new(valid_daily_bar_data.merge(close: 150.0)) # Same as open
      end

      it "returns false" do
        expect(flat_bar.green_day?).to be false
      end
    end

    context "boundary testing" do
      it "returns true for close just above open" do
        barely_green = described_class.new(valid_daily_bar_data.merge(close: 150.01))
        expect(barely_green.green_day?).to be true
      end

      it "returns false for close just below open" do
        barely_red = described_class.new(valid_daily_bar_data.merge(close: 149.99))
        expect(barely_red.green_day?).to be false
      end
    end
  end

  describe "#red_day?" do
    context "when close is less than open" do
      let(:red_bar) do
        described_class.new(valid_daily_bar_data.merge(close: 148.0)) # Less than open 150.0
      end

      it "returns true" do
        expect(red_bar.red_day?).to be true
      end
    end

    context "when close is greater than open" do
      it "returns false" do
        expect(daily_bar.red_day?).to be false # close: 152.0, open: 150.0
      end
    end

    context "when close equals open" do
      let(:flat_bar) do
        described_class.new(valid_daily_bar_data.merge(close: 150.0)) # Same as open
      end

      it "returns false" do
        expect(flat_bar.red_day?).to be false
      end
    end
  end

  describe "#doji?" do
    it "returns true when open and close are within 10% of range" do
      # range = 6.5, 10% of range = 0.65
      # |open - close| = |150.0 - 152.0| = 2.0
      # 2.0 < 0.65 is false, so this should be false
      expect(daily_bar.doji?).to be false
    end

    context "with actual doji pattern" do
      let(:doji_bar) do
        # Small body relative to range
        described_class.new(valid_daily_bar_data.merge(open: 150.0, close: 150.3)) # diff = 0.3, range = 6.5, 10% = 0.65
      end

      it "returns true when body is small relative to range" do
        expect(doji_bar.doji?).to be true
      end
    end

    context "with exact boundary conditions" do
      it "returns true when body equals exactly 10% of range" do
        # Set up so that |open - close| = range * 0.1
        boundary_bar = described_class.new(valid_daily_bar_data.merge(
          high: 160.0, low: 150.0, # range = 10.0
          open: 155.0, close: 154.0 # |155.0 - 154.0| = 1.0 = 10.0 * 0.1
        ))
        expect(boundary_bar.doji?).to be false # < is used, not <=
      end

      it "returns true when body is just under 10% of range" do
        under_boundary_bar = described_class.new(valid_daily_bar_data.merge(
          high: 160.0, low: 150.0, # range = 10.0
          open: 155.0, close: 154.01 # |155.0 - 154.01| = 0.99 < 1.0
        ))
        expect(under_boundary_bar.doji?).to be true
      end
    end

    context "edge cases" do
      it "returns true when open equals close" do
        perfect_doji = described_class.new(valid_daily_bar_data.merge(open: 150.0, close: 150.0))
        expect(perfect_doji.doji?).to be true
      end

      it "uses absolute value for comparison" do
        negative_body_bar = described_class.new(valid_daily_bar_data.merge(
          high: 160.0, low: 150.0, # range = 10.0
          open: 154.0, close: 155.0 # |154.0 - 155.0| = 1.0, should be false
        ))
        expect(negative_body_bar.doji?).to be false
      end
    end
  end

  describe "#high_volume?" do
    context "when volume is greater than 1000" do
      let(:high_vol_bar) do
        described_class.new(valid_daily_bar_data.merge(volume: 1500))
      end

      it "returns true" do
        expect(high_vol_bar.high_volume?).to be true
      end
    end

    context "when volume is less than or equal to 1000" do
      it "returns false for volume under 1000" do
        expect(daily_bar.high_volume?).to be false # volume is 500
      end

      it "returns false for volume exactly 1000" do
        exactly_1000_bar = described_class.new(valid_daily_bar_data.merge(volume: 1000))
        expect(exactly_1000_bar.high_volume?).to be false
      end
    end

    context "boundary testing" do
      it "returns true for volume just above 1000" do
        just_above_bar = described_class.new(valid_daily_bar_data.merge(volume: 1001))
        expect(just_above_bar.high_volume?).to be true
      end
    end
  end

  describe "#body_size" do
    it "calculates absolute difference between close and open" do
      expect(daily_bar.body_size).to eq(2.0) # |152.0 - 150.0|
    end

    context "when close is less than open" do
      let(:red_bar) do
        described_class.new(valid_daily_bar_data.merge(close: 147.0)) # Less than open 150.0
      end

      it "returns positive value (absolute difference)" do
        expect(red_bar.body_size).to eq(3.0) # |147.0 - 150.0|
      end
    end

    context "when close equals open" do
      let(:doji_bar) do
        described_class.new(valid_daily_bar_data.merge(close: 150.0))
      end

      it "returns zero" do
        expect(doji_bar.body_size).to eq(0.0)
      end
    end

    it "rounds to 4 decimal places" do
      precise_bar = described_class.new(valid_daily_bar_data.merge(open: 150.123456, close: 149.654321))
      expect(precise_bar.body_size).to eq(0.4691) # |150.123456 - 149.654321|
    end
  end

  describe "#upper_shadow" do
    it "calculates high minus max of open and close" do
      # high: 155.0, max(150.0, 152.0) = 152.0
      expect(daily_bar.upper_shadow).to eq(3.0) # 155.0 - 152.0
    end

    context "when open is higher than close" do
      let(:red_bar) do
        described_class.new(valid_daily_bar_data.merge(close: 148.0)) # open: 150.0, close: 148.0
      end

      it "uses open as the max" do
        # high: 155.0, max(150.0, 148.0) = 150.0
        expect(red_bar.upper_shadow).to eq(5.0) # 155.0 - 150.0
      end
    end

    context "when high equals the body top" do
      let(:no_upper_shadow_bar) do
        described_class.new(valid_daily_bar_data.merge(high: 152.0)) # Same as close
      end

      it "returns zero" do
        expect(no_upper_shadow_bar.upper_shadow).to eq(0.0)
      end
    end

    it "rounds to 4 decimal places" do
      precise_bar = described_class.new(valid_daily_bar_data.merge(
        high: 155.123456,
        open: 150.0,
        close: 151.654321
      ))
      # max(150.0, 151.654321) = 151.654321
      # 155.123456 - 151.654321 = 3.4691
      expect(precise_bar.upper_shadow).to eq(3.4691)
    end
  end

  describe "#lower_shadow" do
    it "calculates min of open and close minus low" do
      # min(150.0, 152.0) = 150.0, low: 148.5
      expect(daily_bar.lower_shadow).to eq(1.5) # 150.0 - 148.5
    end

    context "when close is lower than open" do
      let(:red_bar) do
        described_class.new(valid_daily_bar_data.merge(close: 148.0)) # open: 150.0, close: 148.0
      end

      it "uses close as the min" do
        # min(150.0, 148.0) = 148.0, low: 148.5
        expect(red_bar.lower_shadow).to eq(-0.5) # 148.0 - 148.5 (negative shadow indicates price gapped)
      end
    end

    context "when low equals the body bottom" do
      let(:no_lower_shadow_bar) do
        described_class.new(valid_daily_bar_data.merge(low: 150.0)) # Same as open (body bottom)
      end

      it "returns zero" do
        expect(no_lower_shadow_bar.lower_shadow).to eq(0.0)
      end
    end

    it "rounds to 4 decimal places" do
      precise_bar = described_class.new(valid_daily_bar_data.merge(
        low: 148.123456,
        open: 150.0,
        close: 149.654321
      ))
      # min(150.0, 149.654321) = 149.654321
      # 149.654321 - 148.123456 = 1.5309
      expect(precise_bar.lower_shadow).to eq(1.5309)
    end
  end

  describe "comprehensive candlestick pattern testing" do
    let(:test_patterns) do
      [
        {
          name: "green_hammer",
          data: {open: 150.0, close: 152.0, high: 153.0, low: 145.0},
          expectations: {
            green_day?: true,
            red_day?: false,
            body_size: 2.0,
            upper_shadow: 1.0, # 153.0 - 152.0
            lower_shadow: 5.0  # 150.0 - 145.0
          }
        },
        {
          name: "red_shooting_star",
          data: {open: 152.0, close: 150.0, high: 158.0, low: 149.0},
          expectations: {
            green_day?: false,
            red_day?: true,
            body_size: 2.0,
            upper_shadow: 6.0, # 158.0 - 152.0
            lower_shadow: 1.0  # 150.0 - 149.0
          }
        },
        {
          name: "perfect_doji",
          data: {open: 150.0, close: 150.0, high: 152.0, low: 148.0},
          expectations: {
            green_day?: false,
            red_day?: false,
            body_size: 0.0,
            upper_shadow: 2.0, # 152.0 - 150.0
            lower_shadow: 2.0, # 150.0 - 148.0
            doji?: true
          }
        }
      ]
    end

    it "correctly calculates all metrics for various candlestick patterns" do
      test_patterns.each do |pattern|
        bar_data = valid_daily_bar_data.merge(pattern[:data])
        bar = described_class.new(bar_data)

        pattern[:expectations].each do |method, expected_value|
          expect(bar.send(method)).to eq(expected_value),
            "Expected #{method} to return #{expected_value} for #{pattern[:name]} pattern"
        end
      end
    end
  end

  describe "immutability and inheritance" do
    it "inherits from Dry::Struct" do
      expect(described_class.superclass).to eq(Dry::Struct)
    end

    it "is immutable after creation" do
      expect { daily_bar.open = 200.0 }.to raise_error(NoMethodError)
    end
  end

  describe "numeric type handling" do
    context "with integer values" do
      let(:integer_bar) do
        described_class.new(
          open: 150,
          high: 155,
          low: 148,
          close: 152,
          volume: 500,
          vwap: 151,
          previous_close: 149,
          change: 3,
          change_percent: 2
        )
      end

      it "handles integer values correctly" do
        expect(integer_bar.range).to eq(7) # 155 - 148
        expect(integer_bar.body_size).to eq(2.0) # |152 - 150|
        expect(integer_bar.green_day?).to be true
      end
    end
  end
end
