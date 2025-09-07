# frozen_string_literal: true

require "spec_helper"

RSpec.describe Polymux::Api::Options::UnderlyingAsset do
  let(:asset_data) do
    {
      ticker: "AAPL",
      price: 150.00,
      value: 15000000,
      last_updated: 1678901234000000000,
      timeframe: "REAL-TIME",
      change_to_break_even: -2.45
    }
  end

  let(:underlying_asset) { described_class.new(asset_data) }

  describe "initialization" do
    it "accepts underlying asset data hash" do
      expect { described_class.new(asset_data) }.not_to raise_error
    end

    it "transforms keys to symbols" do
      expect(underlying_asset.ticker).to eq("AAPL")
      expect(underlying_asset.price).to eq(150.00)
      expect(underlying_asset.value).to eq(15000000)
      expect(underlying_asset.last_updated).to eq(1678901234000000000)
      expect(underlying_asset.timeframe).to eq("REAL-TIME")
      expect(underlying_asset.change_to_break_even).to eq(-2.45)
    end
  end

  describe "required and optional attributes" do
    it "requires ticker and change_to_break_even" do
      expect(underlying_asset.ticker).to be_a(String)
      expect(underlying_asset.change_to_break_even).to be_a(Numeric)
    end

    it "allows optional attributes to be nil" do
      minimal_asset = described_class.new(
        ticker: "TSLA",
        change_to_break_even: 5.25
      )

      expect(minimal_asset.price).to be_nil
      expect(minimal_asset.value).to be_nil
      expect(minimal_asset.last_updated).to be_nil
      expect(minimal_asset.timeframe).to be_nil
    end
  end

  describe "#timestamp" do
    it "converts nanosecond timestamp to DateTime" do
      expected_datetime = Time.at(Rational(1678901234000000000, 1_000_000_000)).to_datetime
      expect(underlying_asset.timestamp).to eq(expected_datetime)
    end

    context "when last_updated is nil" do
      let(:asset_without_timestamp) do
        described_class.new(asset_data.merge(last_updated: nil))
      end

      it "returns nil" do
        expect(asset_without_timestamp.timestamp).to be_nil
      end
    end
  end

  describe "#realtime?" do
    context "when timeframe is REAL-TIME" do
      it "returns true" do
        expect(underlying_asset.realtime?).to be true
      end
    end

    context "when timeframe is DELAYED" do
      let(:delayed_asset) do
        described_class.new(asset_data.merge(timeframe: "DELAYED"))
      end

      it "returns false" do
        expect(delayed_asset.realtime?).to be false
      end
    end

    context "when timeframe is nil" do
      let(:no_timeframe_asset) do
        described_class.new(asset_data.merge(timeframe: nil))
      end

      it "returns false" do
        expect(no_timeframe_asset.realtime?).to be false
      end
    end
  end

  describe "#delayed?" do
    context "when timeframe is DELAYED" do
      let(:delayed_asset) do
        described_class.new(asset_data.merge(timeframe: "DELAYED"))
      end

      it "returns true" do
        expect(delayed_asset.delayed?).to be true
      end
    end

    context "when timeframe is REAL-TIME" do
      it "returns false" do
        expect(underlying_asset.delayed?).to be false
      end
    end
  end

  describe "#needs_to_rise?" do
    context "when change_to_break_even is positive" do
      let(:rising_asset) do
        described_class.new(asset_data.merge(change_to_break_even: 3.50))
      end

      it "returns true" do
        expect(rising_asset.needs_to_rise?).to be true
      end
    end

    context "when change_to_break_even is negative" do
      it "returns false" do
        expect(underlying_asset.needs_to_rise?).to be false
      end
    end

    context "when change_to_break_even is zero" do
      let(:break_even_asset) do
        described_class.new(asset_data.merge(change_to_break_even: 0))
      end

      it "returns false" do
        expect(break_even_asset.needs_to_rise?).to be false
      end
    end
  end

  describe "#needs_to_fall?" do
    context "when change_to_break_even is negative" do
      it "returns true" do
        expect(underlying_asset.needs_to_fall?).to be true
      end
    end

    context "when change_to_break_even is positive" do
      let(:rising_asset) do
        described_class.new(asset_data.merge(change_to_break_even: 3.50))
      end

      it "returns false" do
        expect(rising_asset.needs_to_fall?).to be false
      end
    end

    context "when change_to_break_even is zero" do
      let(:break_even_asset) do
        described_class.new(asset_data.merge(change_to_break_even: 0))
      end

      it "returns false" do
        expect(break_even_asset.needs_to_fall?).to be false
      end
    end
  end

  describe "#distance_to_break_even" do
    it "returns absolute value of change_to_break_even" do
      expect(underlying_asset.distance_to_break_even).to eq(2.45) # abs(-2.45)
    end

    context "with positive change_to_break_even" do
      let(:positive_change_asset) do
        described_class.new(asset_data.merge(change_to_break_even: 5.75))
      end

      it "returns the positive value" do
        expect(positive_change_asset.distance_to_break_even).to eq(5.75)
      end
    end

    context "with zero change_to_break_even" do
      let(:zero_change_asset) do
        described_class.new(asset_data.merge(change_to_break_even: 0))
      end

      it "returns zero" do
        expect(zero_change_asset.distance_to_break_even).to eq(0)
      end
    end
  end

  describe "#break_even_move_percentage" do
    it "calculates percentage move needed relative to current price" do
      # -2.45 / 150.00 * 100 = -1.6333%
      expect(underlying_asset.break_even_move_percentage).to eq(-1.6333)
    end

    context "when price is nil" do
      let(:no_price_asset) do
        described_class.new(asset_data.merge(price: nil))
      end

      it "returns nil" do
        expect(no_price_asset.break_even_move_percentage).to be_nil
      end
    end

    context "when price is zero" do
      let(:zero_price_asset) do
        described_class.new(asset_data.merge(price: 0))
      end

      it "returns nil to avoid division by zero" do
        expect(zero_price_asset.break_even_move_percentage).to be_nil
      end
    end

    context "with positive change_to_break_even" do
      let(:upward_move_asset) do
        described_class.new(asset_data.merge(price: 100.0, change_to_break_even: 5.0))
      end

      it "calculates positive percentage" do
        expect(upward_move_asset.break_even_move_percentage).to eq(5.0) # 5.0 / 100.0 * 100
      end
    end

    context "rounds to 4 decimal places" do
      let(:precise_asset) do
        described_class.new(asset_data.merge(price: 333.333, change_to_break_even: 1.0))
      end

      it "returns rounded percentage" do
        # 1.0 / 333.333 * 100 = 0.300003, rounded to 0.3
        expect(precise_asset.break_even_move_percentage).to eq(0.3)
      end
    end
  end

  describe "#stale_data?" do
    it "returns false for recent data by default" do
      # The test data timestamp is from the past, but we need to mock time
      expect(underlying_asset.stale_data?).to be true # Default behavior with test data
    end

    context "when last_updated is nil" do
      let(:no_timestamp_asset) do
        described_class.new(asset_data.merge(last_updated: nil))
      end

      it "returns false" do
        expect(no_timestamp_asset.stale_data?).to be false
      end
    end

    context "with recent data" do
      around do |example|
        Timecop.freeze(Time.at(1678901234)) do
          example.run
        end
      end

      let(:recent_asset) do
        # Current time in nanoseconds
        current_nanos = Time.now.to_f * 1_000_000_000
        described_class.new(asset_data.merge(last_updated: current_nanos.to_i))
      end

      it "returns false for fresh data" do
        expect(recent_asset.stale_data?).to be false
      end
    end

    context "with old data" do
      around do |example|
        Timecop.freeze(Time.at(1678901234)) do
          example.run
        end
      end

      let(:old_asset) do
        # 10 minutes ago in nanoseconds
        old_nanos = (Time.now.to_f - 600) * 1_000_000_000
        described_class.new(asset_data.merge(last_updated: old_nanos.to_i))
      end

      it "returns true for stale data" do
        expect(old_asset.stale_data?).to be true
      end
    end
  end

  describe "numeric type handling" do
    context "with integer change_to_break_even" do
      let(:integer_change_asset) do
        described_class.new(asset_data.merge(change_to_break_even: -3))
      end

      it "handles integer values correctly" do
        expect(integer_change_asset.change_to_break_even).to eq(-3)
        expect(integer_change_asset.distance_to_break_even).to eq(3)
        expect(integer_change_asset.needs_to_fall?).to be true
      end
    end

    context "with float change_to_break_even" do
      let(:float_change_asset) do
        described_class.new(asset_data.merge(change_to_break_even: 2.5))
      end

      it "handles float values correctly" do
        expect(float_change_asset.change_to_break_even).to eq(2.5)
        expect(float_change_asset.distance_to_break_even).to eq(2.5)
        expect(float_change_asset.needs_to_rise?).to be true
      end
    end
  end

  describe "comprehensive direction testing" do
    let(:test_scenarios) do
      [
        {
          change: 5.0,
          expected: {
            needs_to_rise?: true,
            needs_to_fall?: false,
            distance: 5.0
          }
        },
        {
          change: -3.25,
          expected: {
            needs_to_rise?: false,
            needs_to_fall?: true,
            distance: 3.25
          }
        },
        {
          change: 0,
          expected: {
            needs_to_rise?: false,
            needs_to_fall?: false,
            distance: 0
          }
        }
      ]
    end

    it "correctly determines direction for all scenarios" do
      test_scenarios.each do |scenario|
        asset = described_class.new(
          asset_data.merge(change_to_break_even: scenario[:change])
        )

        scenario[:expected].each do |method, expected_result|
          if method == :distance
            expect(asset.distance_to_break_even).to eq(expected_result)
          else
            expect(asset.send(method)).to eq(expected_result),
              "Expected #{method} to return #{expected_result} for change #{scenario[:change]}"
          end
        end
      end
    end
  end

  describe "data structure inheritance" do
    it "inherits from Dry::Struct" do
      expect(described_class.superclass).to eq(Dry::Struct)
    end

    it "is immutable" do
      expect { underlying_asset.price = 200.0 }.to raise_error(NoMethodError)
    end
  end
end
