# frozen_string_literal: true

require "spec_helper"

RSpec.describe Polymux::Api::Options::Snapshot do
  let(:valid_snapshot_data) do
    {
      break_even_price: 152.45,
      daily_bar: daily_bar_data,
      implied_volatility: 0.28,
      last_quote: last_quote_data,
      last_trade: last_trade_data,
      open_interest: 1542,
      underlying_asset: underlying_asset_data,
      greeks: greeks_data
    }
  end

  let(:daily_bar_data) do
    Polymux::Api::Options::DailyBar.new(
      open: 150.0,
      high: 155.0,
      low: 148.5,
      close: 152.0,
      volume: 500,
      vwap: 151.5,
      previous_close: 149.0,
      change: 3.0,
      change_percent: 2.01
    )
  end

  let(:last_quote_data) do
    Polymux::Api::Options::LastQuote.new(
      ask_price: 2.50,
      ask_size: 10,
      bid_price: 2.45,
      bid_size: 15,
      midpoint: 2.475,
      last_updated: 1678901234000000000,
      timeframe: "REAL-TIME"
    )
  end

  let(:last_trade_data) do
    Polymux::Api::Options::LastTrade.new(
      price: 2.47,
      size: 5,
      sip_timestamp: 1678901234000000000,
      timeframe: "REAL-TIME"
    )
  end

  let(:underlying_asset_data) do
    Polymux::Api::Options::UnderlyingAsset.new(
      ticker: "AAPL",
      price: 153.25,
      value: 153.25,
      last_updated: 1678901234000000000,
      timeframe: "REAL-TIME",
      change_to_break_even: 0.80
    )
  end

  let(:greeks_data) do
    Polymux::Api::Options::Greeks.new(
      delta: 0.75,
      gamma: 0.02,
      theta: -0.08,
      vega: 0.15
    )
  end

  let(:snapshot) { described_class.new(valid_snapshot_data) }

  describe "initialization" do
    it "creates a snapshot with valid attributes" do
      expect(snapshot.break_even_price).to eq(152.45)
      expect(snapshot.implied_volatility).to eq(0.28)
      expect(snapshot.open_interest).to eq(1542)
      expect(snapshot.daily_bar).to eq(daily_bar_data)
      expect(snapshot.last_quote).to eq(last_quote_data)
      expect(snapshot.last_trade).to eq(last_trade_data)
      expect(snapshot.underlying_asset).to eq(underlying_asset_data)
      expect(snapshot.greeks).to eq(greeks_data)
    end

    it "enforces required attributes" do
      expect {
        described_class.new({})
      }.to raise_error(Dry::Struct::Error)
    end

    context "with minimal required data" do
      let(:minimal_data) do
        {
          break_even_price: 150.0,
          open_interest: 100,
          underlying_asset: underlying_asset_data
        }
      end

      it "creates snapshot with optional attributes as nil" do
        minimal_snapshot = described_class.new(minimal_data)

        expect(minimal_snapshot.break_even_price).to eq(150.0)
        expect(minimal_snapshot.open_interest).to eq(100)
        expect(minimal_snapshot.daily_bar).to be_nil
        expect(minimal_snapshot.implied_volatility).to be_nil
        expect(minimal_snapshot.last_quote).to be_nil
        expect(minimal_snapshot.last_trade).to be_nil
        expect(minimal_snapshot.greeks).to be_nil
      end
    end
  end

  describe "#actively_traded?" do
    context "when last_trade data is present" do
      it "returns true" do
        expect(snapshot.actively_traded?).to be true
      end
    end

    context "when last_trade data is nil" do
      let(:snapshot_without_trade) do
        described_class.new(valid_snapshot_data.merge(last_trade: nil))
      end

      it "returns false" do
        expect(snapshot_without_trade.actively_traded?).to be false
      end
    end

    context "with mutation-resistant assertion" do
      it "specifically checks for nil using negation" do
        expect(snapshot.last_trade).not_to be_nil
        expect(snapshot.actively_traded?).to be true
      end

      it "returns false when last_trade is explicitly nil" do
        snapshot_data = valid_snapshot_data.dup
        snapshot_data[:last_trade] = nil
        no_trade_snapshot = described_class.new(snapshot_data)

        expect(no_trade_snapshot.last_trade).to be_nil
        expect(no_trade_snapshot.actively_traded?).to be false
      end
    end
  end

  describe "#liquid?" do
    context "when last_quote data is present" do
      it "returns true" do
        expect(snapshot.liquid?).to be true
      end
    end

    context "when last_quote data is nil" do
      let(:snapshot_without_quote) do
        described_class.new(valid_snapshot_data.merge(last_quote: nil))
      end

      it "returns false" do
        expect(snapshot_without_quote.liquid?).to be false
      end
    end

    context "with mutation-resistant assertion" do
      it "specifically checks for nil using negation" do
        expect(snapshot.last_quote).not_to be_nil
        expect(snapshot.liquid?).to be true
      end

      it "returns false when last_quote is explicitly nil" do
        snapshot_data = valid_snapshot_data.dup
        snapshot_data[:last_quote] = nil
        no_quote_snapshot = described_class.new(snapshot_data)

        expect(no_quote_snapshot.last_quote).to be_nil
        expect(no_quote_snapshot.liquid?).to be false
      end
    end
  end

  describe "#current_price" do
    context "when last_trade is available" do
      it "returns last trade price" do
        expect(snapshot.current_price).to eq(2.47)
      end
    end

    context "when last_trade is nil but last_quote is available" do
      let(:quote_only_snapshot) do
        described_class.new(valid_snapshot_data.merge(last_trade: nil))
      end

      it "returns quote midpoint" do
        expect(quote_only_snapshot.current_price).to eq(2.475)
      end
    end

    context "when both last_trade and last_quote are nil" do
      let(:no_price_data_snapshot) do
        described_class.new(valid_snapshot_data.merge(last_trade: nil, last_quote: nil))
      end

      it "returns nil" do
        expect(no_price_data_snapshot.current_price).to be_nil
      end
    end

    context "priority testing (trade over quote)" do
      it "prefers trade price over quote midpoint when both are present" do
        # Create a snapshot where trade and quote prices differ
        modified_quote = Polymux::Api::Options::LastQuote.new(
          ask_price: 3.00,
          ask_size: 10,
          bid_price: 2.90,
          bid_size: 15,
          midpoint: 2.95, # Different from trade price
          last_updated: 1678901234000000000,
          timeframe: "REAL-TIME"
        )

        snapshot_with_diff_prices = described_class.new(
          valid_snapshot_data.merge(last_quote: modified_quote)
        )

        expect(snapshot_with_diff_prices.current_price).to eq(2.47) # Trade price, not quote midpoint
      end
    end

    context "with edge case scenarios" do
      it "handles zero trade price" do
        zero_trade = Polymux::Api::Options::LastTrade.new(
          price: 0.0,
          size: 5,
          sip_timestamp: 1678901234000000000,
          timeframe: "REAL-TIME"
        )

        zero_price_snapshot = described_class.new(
          valid_snapshot_data.merge(last_trade: zero_trade)
        )

        expect(zero_price_snapshot.current_price).to eq(0.0)
      end

      it "handles zero quote midpoint" do
        zero_quote = Polymux::Api::Options::LastQuote.new(
          ask_price: 0.0,
          ask_size: 10,
          bid_price: 0.0,
          bid_size: 15,
          midpoint: 0.0,
          last_updated: 1678901234000000000,
          timeframe: "REAL-TIME"
        )

        zero_quote_snapshot = described_class.new(
          valid_snapshot_data.merge(last_trade: nil, last_quote: zero_quote)
        )

        expect(zero_quote_snapshot.current_price).to eq(0.0)
      end
    end
  end

  describe "#moneyness" do
    context "when underlying price equals break-even price (ATM)" do
      let(:atm_snapshot) do
        atm_underlying = Polymux::Api::Options::UnderlyingAsset.new(
          underlying_asset_data.to_h.merge(price: 152.45) # Same as break_even_price
        )
        described_class.new(valid_snapshot_data.merge(underlying_asset: atm_underlying))
      end

      it "returns ATM" do
        expect(atm_snapshot.moneyness).to eq("ATM")
      end
    end

    context "when underlying price is within 0.01 of break-even (ATM threshold)" do
      it "returns ATM for price within threshold above" do
        near_atm_underlying = Polymux::Api::Options::UnderlyingAsset.new(
          underlying_asset_data.to_h.merge(price: 152.45 + 0.005) # Within 0.01
        )
        near_atm_snapshot = described_class.new(valid_snapshot_data.merge(underlying_asset: near_atm_underlying))

        expect(near_atm_snapshot.moneyness).to eq("ATM")
      end

      it "returns ATM for price within threshold below" do
        near_atm_underlying = Polymux::Api::Options::UnderlyingAsset.new(
          underlying_asset_data.to_h.merge(price: 152.45 - 0.005) # Within 0.01
        )
        near_atm_snapshot = described_class.new(valid_snapshot_data.merge(underlying_asset: near_atm_underlying))

        expect(near_atm_snapshot.moneyness).to eq("ATM")
      end
    end

    context "when underlying price is above break-even price (ITM)" do
      it "returns ITM" do
        # underlying_asset_data has price 153.25 vs break_even_price 152.45
        expect(snapshot.moneyness).to eq("ITM")
      end
    end

    context "when underlying price is below break-even price (OTM)" do
      let(:otm_snapshot) do
        otm_underlying = Polymux::Api::Options::UnderlyingAsset.new(
          underlying_asset_data.to_h.merge(price: 150.00) # Below break_even_price 152.45
        )
        described_class.new(valid_snapshot_data.merge(underlying_asset: otm_underlying))
      end

      it "returns OTM" do
        expect(otm_snapshot.moneyness).to eq("OTM")
      end
    end

    context "edge cases and boundary conditions" do
      it "returns ATM when underlying price is nil" do
        nil_price_underlying = Polymux::Api::Options::UnderlyingAsset.new(
          underlying_asset_data.to_h.merge(price: nil)
        )
        nil_price_snapshot = described_class.new(valid_snapshot_data.merge(underlying_asset: nil_price_underlying))

        expect(nil_price_snapshot.moneyness).to eq("ATM")
      end

      it "returns ATM when break_even_price is nil" do
        nil_break_even_snapshot = described_class.new(valid_snapshot_data.merge(break_even_price: nil))

        expect(nil_break_even_snapshot.moneyness).to eq("ATM")
      end

      it "correctly calculates absolute difference for comparison" do
        # Test exactly at the 0.01 boundary
        boundary_underlying = Polymux::Api::Options::UnderlyingAsset.new(
          underlying_asset_data.to_h.merge(price: 152.46) # Exactly 0.01 above break_even_price
        )
        boundary_snapshot = described_class.new(valid_snapshot_data.merge(underlying_asset: boundary_underlying))

        # Should be ITM since 0.01 is not < 0.01
        expect(boundary_snapshot.moneyness).to eq("ITM")
      end

      it "handles negative break-even price" do
        negative_break_even_snapshot = described_class.new(
          valid_snapshot_data.merge(break_even_price: -10.0)
        )

        expect(negative_break_even_snapshot.moneyness).to eq("ITM") # 153.25 > -10.0
      end
    end
  end

  describe ".from_api" do
    let(:api_json) do
      {
        "break_even_price" => 152.45,
        "implied_volatility" => 0.28,
        "open_interest" => 1542,
        "underlying_asset" => {
          "ticker" => "AAPL",
          "price" => 153.25
        }
      }
    end

    let(:transformed_data) { valid_snapshot_data }

    before do
      allow(Polymux::Api::Transformers).to receive(:snapshot)
        .with(api_json.deep_symbolize_keys)
        .and_return(transformed_data)
    end

    it "uses transformers to convert API data" do
      snapshot = described_class.from_api(api_json)

      expect(Polymux::Api::Transformers).to have_received(:snapshot).with(api_json.deep_symbolize_keys)
      expect(snapshot).to be_instance_of(described_class)
      expect(snapshot.break_even_price).to eq(152.45)
    end

    it "deep symbolizes keys before transformation" do
      described_class.from_api(api_json)

      expect(Polymux::Api::Transformers).to have_received(:snapshot).with(
        hash_including(
          break_even_price: 152.45,
          implied_volatility: 0.28,
          underlying_asset: hash_including(ticker: "AAPL", price: 153.25)
        )
      )
    end

    it "returns a Snapshot instance" do
      snapshot = described_class.from_api(api_json)
      expect(snapshot).to be_instance_of(described_class)
    end
  end

  describe "immutability and inheritance" do
    it "inherits from Dry::Struct" do
      expect(described_class.superclass).to eq(Dry::Struct)
    end

    it "is immutable after creation" do
      expect { snapshot.break_even_price = 200.0 }.to raise_error(NoMethodError)
    end

    it "creates independent instances" do
      snapshot1 = described_class.new(valid_snapshot_data)
      snapshot2 = described_class.new(valid_snapshot_data.merge(break_even_price: 200.0))

      expect(snapshot1.break_even_price).to eq(152.45)
      expect(snapshot2.break_even_price).to eq(200.0)
      expect(snapshot1.object_id).not_to eq(snapshot2.object_id)
    end
  end

  describe "type validations" do
    it "validates break_even_price as Float" do
      expect(snapshot.break_even_price).to be_instance_of(Float)
    end

    it "validates open_interest as Integer" do
      expect(snapshot.open_interest).to be_instance_of(Integer)
    end

    it "validates optional implied_volatility as Float when present" do
      expect(snapshot.implied_volatility).to be_instance_of(Float)
    end
  end
end
