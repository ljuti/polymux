# frozen_string_literal: true

require "spec_helper"

RSpec.describe Polymux::Api::Options::LastQuote do
  let(:wire_data) do
    {
      ask: 0.35,
      ask_size: 338,
      ask_exchange: 304,
      bid: 0.05,
      bid_size: 47,
      bid_exchange: 320,
      last_updated: 1787342365646547606,
      midpoint: 0.2,
      timeframe: "REAL-TIME"
    }
  end

  describe "wire format parsing" do
    it "accepts the live API field names (ask/bid)" do
      quote = described_class.new(wire_data)

      expect(quote.ask).to eq(0.35)
      expect(quote.ask_size).to eq(338)
      expect(quote.ask_exchange).to eq(304)
      expect(quote.bid).to eq(0.05)
      expect(quote.bid_size).to eq(47)
      expect(quote.bid_exchange).to eq(320)
      expect(quote.midpoint).to eq(0.2)
      expect(quote.last_updated).to eq(1787342365646547606)
      expect(quote.timeframe).to eq("REAL-TIME")
    end

    it "accepts legacy ask_price/bid_price input keys" do
      quote = described_class.new(ask_price: 0.35, bid_price: 0.05, ask_size: 1, bid_size: 1, last_updated: 1)

      expect(quote.ask).to eq(0.35)
      expect(quote.bid).to eq(0.05)
    end
  end

  describe "backwards-compatible aliases" do
    it "exposes ask_price and bid_price readers" do
      quote = described_class.new(wire_data)

      expect(quote.ask_price).to eq(0.35)
      expect(quote.bid_price).to eq(0.05)
    end
  end

  describe "#spread" do
    it "calculates ask minus bid" do
      expect(described_class.new(wire_data).spread).to eq(0.3)
    end
  end

  describe "#midpoint_price" do
    it "returns the wire midpoint when present" do
      expect(described_class.new(wire_data).midpoint_price).to eq(0.2)
    end

    it "averages bid and ask when midpoint is absent" do
      quote = described_class.new(wire_data.merge(midpoint: nil))

      expect(quote.midpoint_price).to eq(((0.05 + 0.35) / 2.0).round(4))
    end
  end

  describe "#spread_percentage" do
    it "computes spread as a percentage of the midpoint" do
      expect(described_class.new(wire_data).spread_percentage).to eq(150.0) # 0.3 / 0.2 * 100
    end
  end

  describe "#realtime?" do
    it "is true for REAL-TIME timeframe" do
      expect(described_class.new(wire_data).realtime?).to be true
    end

    it "is false for DELAYED timeframe" do
      expect(described_class.new(wire_data.merge(timeframe: "DELAYED")).realtime?).to be false
    end
  end

  describe "#delayed?" do
    it "is true for DELAYED timeframe" do
      expect(described_class.new(wire_data.merge(timeframe: "DELAYED")).delayed?).to be true
    end

    it "is false for REAL-TIME timeframe" do
      expect(described_class.new(wire_data).delayed?).to be false
    end
  end

  describe "#timestamp" do
    it "converts nanosecond timestamp to DateTime" do
      expected_datetime = Time.at(Rational(1787342365646547606, 1_000_000_000)).to_datetime
      expect(described_class.new(wire_data).timestamp).to eq(expected_datetime)
    end
  end
end
