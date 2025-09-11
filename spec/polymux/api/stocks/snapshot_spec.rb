# frozen_string_literal: true

require "spec_helper"

RSpec.describe Polymux::Api::Stocks::Snapshot do
  let(:snapshot_data) do
    {
      ticker: "AAPL",
      market_status: "open",
      market: "stocks",
      last_trade: {
        "p" => 174.49,
        "s" => 100,
        "x" => 1,
        "t" => 1705328425123456789
      },
      last_quote: {
        "P" => 174.48,
        "p" => 174.50,
        "S" => 200,
        "s" => 300,
        "x" => 1,
        "X" => 2,
        "t" => 1705328425123456789
      },
      daily_bar: {
        "o" => 173.01,
        "h" => 175.50,
        "l" => 172.30,
        "c" => 174.49,
        "v" => 45678901,
        "cp" => 1.48,
        "change" => 1.48,
        "vw" => 174.25
      },
      prev_daily_bar: {
        "o" => 172.50,
        "h" => 173.80,
        "l" => 171.90,
        "c" => 173.01,
        "v" => 42000000,
        "vw" => 172.75
      },
      session: {
        "change" => 1.48,
        "change_percent" => 0.86
      },
      updated: 1705328425123456789
    }
  end

  let(:snapshot) { described_class.new(snapshot_data) }

  describe "initialization" do
    it "creates a snapshot with all attributes" do
      expect(snapshot.ticker).to eq("AAPL")
      expect(snapshot.market_status).to eq("open")
      expect(snapshot.market).to eq("stocks")
      expect(snapshot.last_trade).to be_a(Hash)
      expect(snapshot.last_quote).to be_a(Hash)
      expect(snapshot.daily_bar).to be_a(Hash)
      expect(snapshot.prev_daily_bar).to be_a(Hash)
      expect(snapshot.session).to be_a(Hash)
      expect(snapshot.updated).to eq(1705328425123456789)
    end

    it "handles optional attributes" do
      minimal_snapshot = described_class.new(ticker: "TEST")
      expect(minimal_snapshot.ticker).to eq("TEST")
      expect(minimal_snapshot.market_status).to be_nil
      expect(minimal_snapshot.last_trade).to be_nil
      expect(minimal_snapshot.last_quote).to be_nil
      expect(minimal_snapshot.daily_bar).to be_nil
    end

    it "is instance of Polymux::Api::Stocks::Snapshot" do
      expect(snapshot).to be_instance_of(Polymux::Api::Stocks::Snapshot)
    end

    it "inherits from Dry::Struct" do
      expect(snapshot).to be_a(Dry::Struct)
    end
  end

  describe "#current_price" do
    context "when last_trade contains price data" do
      it "returns price from 'p' key" do
        expect(snapshot.current_price).to eq(174.49)
      end

      it "returns price from 'price' key when 'p' is not available" do
        trade_with_price_key = snapshot_data.dup
        trade_with_price_key[:last_trade] = {"price" => 175.00, "size" => 100}
        snap = described_class.new(trade_with_price_key)
        expect(snap.current_price).to eq(175.00)
      end

      it "prefers 'p' key over 'price' key" do
        trade_with_both_keys = snapshot_data.dup
        trade_with_both_keys[:last_trade] = {"p" => 174.49, "price" => 175.00}
        snap = described_class.new(trade_with_both_keys)
        expect(snap.current_price).to eq(174.49)
      end

      it "handles zero price" do
        zero_price_data = snapshot_data.dup
        zero_price_data[:last_trade] = {"p" => 0.0}
        snap = described_class.new(zero_price_data)
        expect(snap.current_price).to eq(0.0)
      end

      it "handles negative price" do
        negative_price_data = snapshot_data.dup
        negative_price_data[:last_trade] = {"p" => -1.0}
        snap = described_class.new(negative_price_data)
        expect(snap.current_price).to eq(-1.0)
      end
    end

    context "when last_trade is nil" do
      let(:no_trade_snapshot) { described_class.new(ticker: "TEST", last_trade: nil) }

      it "returns nil" do
        expect(no_trade_snapshot.current_price).to be_nil
      end
    end

    context "when last_trade is missing" do
      let(:missing_trade_snapshot) { described_class.new(ticker: "TEST") }

      it "returns nil" do
        expect(missing_trade_snapshot.current_price).to be_nil
      end
    end

    context "when last_trade has no price data" do
      let(:no_price_data) do
        {ticker: "TEST", last_trade: {"s" => 100, "x" => 1}}
      end
      let(:no_price_snapshot) { described_class.new(no_price_data) }

      it "returns nil" do
        expect(no_price_snapshot.current_price).to be_nil
      end
    end
  end

  describe "#bid_price" do
    context "when last_quote contains bid price data" do
      it "returns bid price from 'P' key" do
        expect(snapshot.bid_price).to eq(174.48)
      end

      it "returns bid price from 'bid_price' key when 'P' is not available" do
        quote_with_bid_price_key = snapshot_data.dup
        quote_with_bid_price_key[:last_quote] = {"bid_price" => 174.45, "ask_price" => 174.55}
        snap = described_class.new(quote_with_bid_price_key)
        expect(snap.bid_price).to eq(174.45)
      end

      it "prefers 'P' key over 'bid_price' key" do
        quote_with_both_keys = snapshot_data.dup
        quote_with_both_keys[:last_quote] = {"P" => 174.48, "bid_price" => 174.45}
        snap = described_class.new(quote_with_both_keys)
        expect(snap.bid_price).to eq(174.48)
      end

      it "handles zero bid price" do
        zero_bid_data = snapshot_data.dup
        zero_bid_data[:last_quote] = {"P" => 0.0}
        snap = described_class.new(zero_bid_data)
        expect(snap.bid_price).to eq(0.0)
      end
    end

    context "when last_quote is nil" do
      let(:no_quote_snapshot) { described_class.new(ticker: "TEST", last_quote: nil) }

      it "returns nil" do
        expect(no_quote_snapshot.bid_price).to be_nil
      end
    end

    context "when last_quote is missing" do
      let(:missing_quote_snapshot) { described_class.new(ticker: "TEST") }

      it "returns nil" do
        expect(missing_quote_snapshot.bid_price).to be_nil
      end
    end
  end

  describe "#ask_price" do
    context "when last_quote contains ask price data" do
      it "returns ask price from 'p' key (lowercase)" do
        expect(snapshot.ask_price).to eq(174.50)
      end

      it "returns ask price from 'ask_price' key when 'p' is not available" do
        quote_with_ask_price_key = snapshot_data.dup
        quote_with_ask_price_key[:last_quote] = {"bid_price" => 174.45, "ask_price" => 174.55}
        snap = described_class.new(quote_with_ask_price_key)
        expect(snap.ask_price).to eq(174.55)
      end

      it "prefers 'p' key over 'ask_price' key" do
        quote_with_both_keys = snapshot_data.dup
        quote_with_both_keys[:last_quote] = {"p" => 174.50, "ask_price" => 174.55}
        snap = described_class.new(quote_with_both_keys)
        expect(snap.ask_price).to eq(174.50)
      end

      it "handles zero ask price" do
        zero_ask_data = snapshot_data.dup
        zero_ask_data[:last_quote] = {"p" => 0.0}
        snap = described_class.new(zero_ask_data)
        expect(snap.ask_price).to eq(0.0)
      end
    end

    context "when last_quote is nil" do
      let(:no_quote_snapshot) { described_class.new(ticker: "TEST", last_quote: nil) }

      it "returns nil" do
        expect(no_quote_snapshot.ask_price).to be_nil
      end
    end
  end

  describe "#volume" do
    context "when daily_bar contains volume data" do
      it "returns volume from 'v' key" do
        expect(snapshot.volume).to eq(45678901)
      end

      it "returns volume from 'volume' key when 'v' is not available" do
        bar_with_volume_key = snapshot_data.dup
        bar_with_volume_key[:daily_bar] = {"volume" => 50000000, "close" => 174.49}
        snap = described_class.new(bar_with_volume_key)
        expect(snap.volume).to eq(50000000)
      end

      it "prefers 'v' key over 'volume' key" do
        bar_with_both_keys = snapshot_data.dup
        bar_with_both_keys[:daily_bar] = {"v" => 45678901, "volume" => 50000000}
        snap = described_class.new(bar_with_both_keys)
        expect(snap.volume).to eq(45678901)
      end

      it "handles zero volume" do
        zero_volume_data = snapshot_data.dup
        zero_volume_data[:daily_bar] = {"v" => 0}
        snap = described_class.new(zero_volume_data)
        expect(snap.volume).to eq(0)
      end
    end

    context "when daily_bar is nil" do
      let(:no_bar_snapshot) { described_class.new(ticker: "TEST", daily_bar: nil) }

      it "returns nil" do
        expect(no_bar_snapshot.volume).to be_nil
      end
    end
  end

  describe "#change_amount" do
    context "when daily_bar contains change data" do
      it "returns change from 'c' key" do
        bar_with_c_key = snapshot_data.dup
        bar_with_c_key[:daily_bar] = {"c" => 1.48}
        snap = described_class.new(bar_with_c_key)
        expect(snap.change_amount).to eq(1.48)
      end

      it "returns change from 'change' key when 'c' is not available" do
        bar_without_c = snapshot_data.dup
        bar_without_c[:daily_bar] = {"change" => 1.48}
        snap = described_class.new(bar_without_c)
        expect(snap.change_amount).to eq(1.48)
      end

      it "prefers 'c' key over 'change' key" do
        bar_with_both_keys = snapshot_data.dup
        bar_with_both_keys[:daily_bar] = {"c" => 1.48, "change" => 2.00}
        snap = described_class.new(bar_with_both_keys)
        expect(snap.change_amount).to eq(1.48)
      end

      it "handles zero change" do
        zero_change_data = snapshot_data.dup
        zero_change_data[:daily_bar] = {"change" => 0.0}
        snap = described_class.new(zero_change_data)
        expect(snap.change_amount).to eq(0.0)
      end

      it "handles negative change" do
        negative_change_data = snapshot_data.dup
        negative_change_data[:daily_bar] = {"change" => -1.25}
        snap = described_class.new(negative_change_data)
        expect(snap.change_amount).to eq(-1.25)
      end
    end

    context "when daily_bar is nil" do
      let(:no_bar_snapshot) { described_class.new(ticker: "TEST", daily_bar: nil) }

      it "returns nil" do
        expect(no_bar_snapshot.change_amount).to be_nil
      end
    end
  end

  describe "#change_percent" do
    context "when daily_bar contains change percent data" do
      it "returns change percent from 'cp' key" do
        expect(snapshot.change_percent).to eq(1.48)
      end

      it "returns change percent from 'change_percent' key when 'cp' is not available" do
        bar_with_change_percent_key = snapshot_data.dup
        bar_with_change_percent_key[:daily_bar] = {"change_percent" => 2.5}
        snap = described_class.new(bar_with_change_percent_key)
        expect(snap.change_percent).to eq(2.5)
      end

      it "prefers 'cp' key over 'change_percent' key" do
        bar_with_both_keys = snapshot_data.dup
        bar_with_both_keys[:daily_bar] = {"cp" => 1.48, "change_percent" => 2.5}
        snap = described_class.new(bar_with_both_keys)
        expect(snap.change_percent).to eq(1.48)
      end

      it "handles zero change percent" do
        zero_change_percent_data = snapshot_data.dup
        zero_change_percent_data[:daily_bar] = {"cp" => 0.0}
        snap = described_class.new(zero_change_percent_data)
        expect(snap.change_percent).to eq(0.0)
      end

      it "handles negative change percent" do
        negative_change_percent_data = snapshot_data.dup
        negative_change_percent_data[:daily_bar] = {"cp" => -2.15}
        snap = described_class.new(negative_change_percent_data)
        expect(snap.change_percent).to eq(-2.15)
      end
    end

    context "when daily_bar is nil" do
      let(:no_bar_snapshot) { described_class.new(ticker: "TEST", daily_bar: nil) }

      it "returns nil" do
        expect(no_bar_snapshot.change_percent).to be_nil
      end
    end
  end

  describe "#daily_high" do
    context "when daily_bar contains high data" do
      it "returns high from 'h' key" do
        expect(snapshot.daily_high).to eq(175.50)
      end

      it "returns high from 'high' key when 'h' is not available" do
        bar_with_high_key = snapshot_data.dup
        bar_with_high_key[:daily_bar] = {"high" => 176.00}
        snap = described_class.new(bar_with_high_key)
        expect(snap.daily_high).to eq(176.00)
      end

      it "prefers 'h' key over 'high' key" do
        bar_with_both_keys = snapshot_data.dup
        bar_with_both_keys[:daily_bar] = {"h" => 175.50, "high" => 176.00}
        snap = described_class.new(bar_with_both_keys)
        expect(snap.daily_high).to eq(175.50)
      end
    end

    context "when daily_bar is nil" do
      let(:no_bar_snapshot) { described_class.new(ticker: "TEST", daily_bar: nil) }

      it "returns nil" do
        expect(no_bar_snapshot.daily_high).to be_nil
      end
    end
  end

  describe "#daily_low" do
    context "when daily_bar contains low data" do
      it "returns low from 'l' key" do
        expect(snapshot.daily_low).to eq(172.30)
      end

      it "returns low from 'low' key when 'l' is not available" do
        bar_with_low_key = snapshot_data.dup
        bar_with_low_key[:daily_bar] = {"low" => 171.50}
        snap = described_class.new(bar_with_low_key)
        expect(snap.daily_low).to eq(171.50)
      end

      it "prefers 'l' key over 'low' key" do
        bar_with_both_keys = snapshot_data.dup
        bar_with_both_keys[:daily_bar] = {"l" => 172.30, "low" => 171.50}
        snap = described_class.new(bar_with_both_keys)
        expect(snap.daily_low).to eq(172.30)
      end
    end

    context "when daily_bar is nil" do
      let(:no_bar_snapshot) { described_class.new(ticker: "TEST", daily_bar: nil) }

      it "returns nil" do
        expect(no_bar_snapshot.daily_low).to be_nil
      end
    end
  end

  describe "#daily_open" do
    context "when daily_bar contains open data" do
      it "returns open from 'o' key" do
        expect(snapshot.daily_open).to eq(173.01)
      end

      it "returns open from 'open' key when 'o' is not available" do
        bar_with_open_key = snapshot_data.dup
        bar_with_open_key[:daily_bar] = {"open" => 172.75}
        snap = described_class.new(bar_with_open_key)
        expect(snap.daily_open).to eq(172.75)
      end

      it "prefers 'o' key over 'open' key" do
        bar_with_both_keys = snapshot_data.dup
        bar_with_both_keys[:daily_bar] = {"o" => 173.01, "open" => 172.75}
        snap = described_class.new(bar_with_both_keys)
        expect(snap.daily_open).to eq(173.01)
      end
    end

    context "when daily_bar is nil" do
      let(:no_bar_snapshot) { described_class.new(ticker: "TEST", daily_bar: nil) }

      it "returns nil" do
        expect(no_bar_snapshot.daily_open).to be_nil
      end
    end
  end

  describe "#daily_close" do
    context "when daily_bar contains close data" do
      it "returns close from 'c' key" do
        expect(snapshot.daily_close).to eq(174.49)
      end

      it "returns close from 'close' key when 'c' is not available" do
        bar_with_close_key = snapshot_data.dup
        bar_with_close_key[:daily_bar] = {"close" => 174.25}
        snap = described_class.new(bar_with_close_key)
        expect(snap.daily_close).to eq(174.25)
      end

      it "prefers 'c' key over 'close' key" do
        bar_with_both_keys = snapshot_data.dup
        bar_with_both_keys[:daily_bar] = {"c" => 174.49, "close" => 174.25}
        snap = described_class.new(bar_with_both_keys)
        expect(snap.daily_close).to eq(174.49)
      end
    end

    context "when daily_bar is nil" do
      let(:no_bar_snapshot) { described_class.new(ticker: "TEST", daily_bar: nil) }

      it "returns nil" do
        expect(no_bar_snapshot.daily_close).to be_nil
      end
    end
  end

  describe "#vwap" do
    context "when daily_bar contains VWAP data" do
      it "returns VWAP from 'vw' key" do
        expect(snapshot.vwap).to eq(174.25)
      end

      it "returns VWAP from 'vwap' key when 'vw' is not available" do
        bar_with_vwap_key = snapshot_data.dup
        bar_with_vwap_key[:daily_bar] = {"vwap" => 174.15}
        snap = described_class.new(bar_with_vwap_key)
        expect(snap.vwap).to eq(174.15)
      end

      it "prefers 'vw' key over 'vwap' key" do
        bar_with_both_keys = snapshot_data.dup
        bar_with_both_keys[:daily_bar] = {"vw" => 174.25, "vwap" => 174.15}
        snap = described_class.new(bar_with_both_keys)
        expect(snap.vwap).to eq(174.25)
      end
    end

    context "when daily_bar is nil" do
      let(:no_bar_snapshot) { described_class.new(ticker: "TEST", daily_bar: nil) }

      it "returns nil" do
        expect(no_bar_snapshot.vwap).to be_nil
      end
    end
  end

  describe "#up?" do
    context "when change_amount is available" do
      it "returns true for positive change" do
        expect(snapshot.up?).to be true # change_amount is 1.48
      end

      it "returns false for negative change" do
        negative_data = snapshot_data.dup
        negative_data[:daily_bar] = {"change" => -1.25}
        negative_snapshot = described_class.new(negative_data)
        expect(negative_snapshot.up?).to be false
      end

      it "returns false for zero change" do
        zero_data = snapshot_data.dup
        zero_data[:daily_bar] = {"change" => 0.0}
        zero_snapshot = described_class.new(zero_data)
        expect(zero_snapshot.up?).to be false
      end
    end

    context "when change_amount is nil" do
      let(:no_change_snapshot) { described_class.new(ticker: "TEST") }

      it "returns false" do
        expect(no_change_snapshot.up?).to be false
      end
    end
  end

  describe "#down?" do
    context "when change_amount is available" do
      it "returns false for positive change" do
        expect(snapshot.down?).to be false # change_amount is 1.48
      end

      it "returns true for negative change" do
        negative_data = snapshot_data.dup
        negative_data[:daily_bar] = {"change" => -1.25}
        negative_snapshot = described_class.new(negative_data)
        expect(negative_snapshot.down?).to be true
      end

      it "returns false for zero change" do
        zero_data = snapshot_data.dup
        zero_data[:daily_bar] = {"change" => 0.0}
        zero_snapshot = described_class.new(zero_data)
        expect(zero_snapshot.down?).to be false
      end
    end

    context "when change_amount is nil" do
      let(:no_change_snapshot) { described_class.new(ticker: "TEST") }

      it "returns false" do
        expect(no_change_snapshot.down?).to be false
      end
    end
  end

  describe "#unchanged?" do
    context "when change_amount is available" do
      it "returns false for positive change" do
        expect(snapshot.unchanged?).to be false # change_amount is 1.48
      end

      it "returns false for negative change" do
        negative_data = snapshot_data.dup
        negative_data[:daily_bar] = {"change" => -1.25}
        negative_snapshot = described_class.new(negative_data)
        expect(negative_snapshot.unchanged?).to be false
      end

      it "returns true for zero change" do
        zero_data = snapshot_data.dup
        zero_data[:daily_bar] = {"change" => 0.0}
        zero_snapshot = described_class.new(zero_data)
        expect(zero_snapshot.unchanged?).to be true
      end

      it "uses exact equality (== 0), not approximate" do
        very_small_change_data = snapshot_data.dup
        very_small_change_data[:daily_bar] = {"change" => 0.0001}
        very_small_snapshot = described_class.new(very_small_change_data)
        expect(very_small_snapshot.unchanged?).to be false
      end
    end

    context "when change_amount is nil" do
      let(:no_change_snapshot) { described_class.new(ticker: "TEST") }

      it "returns false" do
        expect(no_change_snapshot.unchanged?).to be false
      end
    end
  end

  describe "#market_open?" do
    context "when market_status is available" do
      it "returns true for 'open' status" do
        expect(snapshot.market_open?).to be true # market_status is "open"
      end

      it "returns false for 'closed' status" do
        closed_data = snapshot_data.dup
        closed_data[:market_status] = "closed"
        closed_snapshot = described_class.new(closed_data)
        expect(closed_snapshot.market_open?).to be false
      end

      it "returns false for 'pre_market' status" do
        pre_market_data = snapshot_data.dup
        pre_market_data[:market_status] = "pre_market"
        pre_market_snapshot = described_class.new(pre_market_data)
        expect(pre_market_snapshot.market_open?).to be false
      end

      it "returns false for 'after_hours' status" do
        after_hours_data = snapshot_data.dup
        after_hours_data[:market_status] = "after_hours"
        after_hours_snapshot = described_class.new(after_hours_data)
        expect(after_hours_snapshot.market_open?).to be false
      end

      it "is case sensitive - returns false for 'Open'" do
        case_data = snapshot_data.dup
        case_data[:market_status] = "Open"
        case_snapshot = described_class.new(case_data)
        expect(case_snapshot.market_open?).to be false
      end

      it "returns false for empty string status" do
        empty_data = snapshot_data.dup
        empty_data[:market_status] = ""
        empty_snapshot = described_class.new(empty_data)
        expect(empty_snapshot.market_open?).to be false
      end
    end

    context "when market_status is nil" do
      let(:no_status_snapshot) { described_class.new(ticker: "TEST") }

      it "returns false" do
        expect(no_status_snapshot.market_open?).to be false
      end
    end
  end

  describe "#spread" do
    context "when both bid and ask prices are available" do
      it "calculates spread correctly" do
        expect(snapshot.spread).to eq(0.02) # 174.50 - 174.48
      end

      it "handles zero spread (locked market)" do
        locked_data = snapshot_data.dup
        locked_data[:last_quote] = {"P" => 174.50, "p" => 174.50}
        locked_snapshot = described_class.new(locked_data)
        expect(locked_snapshot.spread).to eq(0.0)
      end

      it "handles negative spread (crossed market)" do
        crossed_data = snapshot_data.dup
        crossed_data[:last_quote] = {"P" => 174.51, "p" => 174.50}
        crossed_snapshot = described_class.new(crossed_data)
        expect(crossed_snapshot.spread).to eq(-0.01)
      end

      it "handles decimal precision" do
        precise_data = snapshot_data.dup
        precise_data[:last_quote] = {"P" => 123.456, "p" => 123.789}
        precise_snapshot = described_class.new(precise_data)
        expect(precise_snapshot.spread).to eq(0.333)
      end
    end

    context "when bid_price is nil" do
      let(:no_bid_data) do
        data = snapshot_data.dup
        data[:last_quote] = {"p" => 174.50}
        data
      end
      let(:no_bid_snapshot) { described_class.new(no_bid_data) }

      it "returns nil" do
        expect(no_bid_snapshot.spread).to be_nil
      end
    end

    context "when ask_price is nil" do
      let(:no_ask_data) do
        data = snapshot_data.dup
        data[:last_quote] = {"P" => 174.48}
        data
      end
      let(:no_ask_snapshot) { described_class.new(no_ask_data) }

      it "returns nil" do
        expect(no_ask_snapshot.spread).to be_nil
      end
    end

    context "when both prices are nil" do
      let(:no_prices_snapshot) { described_class.new(ticker: "TEST") }

      it "returns nil" do
        expect(no_prices_snapshot.spread).to be_nil
      end
    end
  end

  describe "#spread_percentage" do
    context "when spread and midpoint are available and midpoint > 0" do
      it "calculates spread percentage correctly" do
        # spread = 0.02, midpoint = 174.49, percentage should be (0.02 / 174.49) * 100
        expected_percentage = (0.02 / 174.49 * 100).round(4)
        expect(snapshot.spread_percentage).to eq(expected_percentage)
      end

      it "handles wide spreads" do
        wide_data = snapshot_data.dup
        wide_data[:last_quote] = {"P" => 100.0, "p" => 105.0}
        wide_snapshot = described_class.new(wide_data)
        # spread = 5.0, midpoint = 102.5, percentage = (5.0 / 102.5) * 100 = 4.878%
        expect(wide_snapshot.spread_percentage).to eq(4.878)
      end

      it "handles zero spread" do
        locked_data = snapshot_data.dup
        locked_data[:last_quote] = {"P" => 174.50, "p" => 174.50}
        locked_snapshot = described_class.new(locked_data)
        expect(locked_snapshot.spread_percentage).to eq(0.0)
      end

      it "rounds to 4 decimal places" do
        # Ensure result is rounded to 4 decimal places
        result = snapshot.spread_percentage
        decimal_places = result.to_s.split(".")[1]&.length || 0
        expect(decimal_places).to be <= 4
      end
    end

    context "when spread is nil" do
      let(:no_spread_snapshot) { described_class.new(ticker: "TEST", last_quote: {"P" => 100.0}) }

      it "returns nil" do
        expect(no_spread_snapshot.spread_percentage).to be_nil
      end
    end

    context "when midpoint is zero or negative" do
      it "returns nil for zero midpoint" do
        zero_data = snapshot_data.dup
        zero_data[:last_quote] = {"P" => 0.0, "p" => 0.0}
        zero_snapshot = described_class.new(zero_data)
        expect(zero_snapshot.spread_percentage).to be_nil
      end

      it "returns nil for negative midpoint" do
        negative_data = snapshot_data.dup
        negative_data[:last_quote] = {"P" => -1.0, "p" => -0.5}
        negative_snapshot = described_class.new(negative_data)
        expect(negative_snapshot.spread_percentage).to be_nil
      end
    end
  end

  describe "#formatted_change" do
    context "when both change_amount and change_percent are available" do
      it "formats positive change correctly" do
        positive_data = snapshot_data.dup
        positive_data[:daily_bar] = {"change" => 1.48, "cp" => 1.48}
        positive_snapshot = described_class.new(positive_data)
        expect(positive_snapshot.formatted_change).to eq("+$1.48 (+1.48%)")
      end

      it "formats negative change correctly" do
        negative_data = snapshot_data.dup
        negative_data[:daily_bar] = {"change" => -1.25, "cp" => -0.72}
        negative_snapshot = described_class.new(negative_data)
        expect(negative_snapshot.formatted_change).to eq("-$1.25 (-0.72%)")
      end

      it "formats zero change correctly" do
        zero_data = snapshot_data.dup
        zero_data[:daily_bar] = {"change" => 0.0, "cp" => 0.0}
        zero_snapshot = described_class.new(zero_data)
        expect(zero_snapshot.formatted_change).to eq("+$0.0 (+0.0%)")
      end

      it "rounds amounts to 2 decimal places" do
        precise_data = snapshot_data.dup
        precise_data[:daily_bar] = {"change" => 1.23456, "cp" => 0.71234}
        precise_snapshot = described_class.new(precise_data)
        expect(precise_snapshot.formatted_change).to eq("+$1.23 (+0.71%)")
      end
    end

    context "when change_amount is nil" do
      let(:no_amount_data) do
        data = snapshot_data.dup
        data[:daily_bar] = {"cp" => 1.48}
        data
      end
      let(:no_amount_snapshot) { described_class.new(no_amount_data) }

      it "returns 'N/A'" do
        expect(no_amount_snapshot.formatted_change).to eq("N/A")
      end
    end

    context "when change_percent is nil" do
      let(:no_percent_data) do
        data = snapshot_data.dup
        data[:daily_bar] = {"change" => 1.48}
        data
      end
      let(:no_percent_snapshot) { described_class.new(no_percent_data) }

      it "returns 'N/A'" do
        expect(no_percent_snapshot.formatted_change).to eq("N/A")
      end
    end

    context "when both are nil" do
      let(:no_change_data_snapshot) { described_class.new(ticker: "TEST") }

      it "returns 'N/A'" do
        expect(no_change_data_snapshot.formatted_change).to eq("N/A")
      end
    end
  end

  describe ".from_api" do
    let(:api_data) do
      {
        "ticker" => "AAPL",
        "market_status" => "open",
        "market" => "stocks",
        "day" => {
          "o" => 173.01,
          "h" => 175.50,
          "l" => 172.30,
          "c" => 174.49,
          "v" => 45678901
        },
        "prevDay" => {
          "o" => 172.50,
          "h" => 173.80,
          "l" => 171.90,
          "c" => 173.01
        },
        "lastTrade" => {
          "p" => 174.49,
          "s" => 100
        },
        "lastQuote" => {
          "P" => 174.48,
          "p" => 174.50
        },
        "updated" => 1705328425123456789
      }
    end

    it "creates Snapshot object from API response" do
      snapshot = described_class.from_api(api_data)

      expect(snapshot).to be_a(described_class)
      expect(snapshot.ticker).to eq("AAPL")
      expect(snapshot.market_status).to eq("open")
      expect(snapshot.market).to eq("stocks")
      # The transformer will handle the field mapping and renaming
    end

    context "with minimal API data" do
      let(:minimal_api_data) { {"ticker" => "TEST"} }

      it "creates Snapshot with minimal data" do
        snapshot = described_class.from_api(minimal_api_data)
        expect(snapshot.ticker).to eq("TEST")
      end
    end

    it "calls Api::Transformers.stock_snapshot for data transformation" do
      expect(Polymux::Api::Transformers).to receive(:stock_snapshot).with(api_data).and_call_original
      described_class.from_api(api_data)
    end
  end

  # Mutation resistance tests
  describe "mutation resistance" do
    context "exact comparisons in status checking" do
      it "uses exact string equality for market_open?, not contains check" do
        partial_match_data = snapshot_data.dup
        partial_match_data[:market_status] = "open_market"
        partial_snapshot = described_class.new(partial_match_data)
        expect(partial_snapshot.market_open?).to be false
      end

      it "uses exact string equality for market_open?, not startswith check" do
        prefix_match_data = snapshot_data.dup
        prefix_match_data[:market_status] = "opening"
        prefix_snapshot = described_class.new(prefix_match_data)
        expect(prefix_snapshot.market_open?).to be false
      end
    end

    context "exact numeric comparisons" do
      it "uses exact > 0 check for up?, not >= 0" do
        zero_change_data = snapshot_data.dup
        zero_change_data[:daily_bar] = {"change" => 0.0}
        zero_snapshot = described_class.new(zero_change_data)
        expect(zero_snapshot.up?).to be false
      end

      it "uses exact < 0 check for down?, not <= 0" do
        zero_change_data = snapshot_data.dup
        zero_change_data[:daily_bar] = {"change" => 0.0}
        zero_snapshot = described_class.new(zero_change_data)
        expect(zero_snapshot.down?).to be false
      end

      it "uses exact == 0 check for unchanged?, not approximate" do
        tiny_change_data = snapshot_data.dup
        tiny_change_data[:daily_bar] = {"change" => 0.0001}
        tiny_snapshot = described_class.new(tiny_change_data)
        expect(tiny_snapshot.unchanged?).to be false
      end
    end
  end

  # Additional comprehensive tests for edge cases
  describe "edge cases" do
    context "nested data access patterns" do
      it "handles empty hash in last_trade" do
        empty_trade_data = snapshot_data.dup
        empty_trade_data[:last_trade] = {}
        empty_trade_snapshot = described_class.new(empty_trade_data)
        expect(empty_trade_snapshot.current_price).to be_nil
      end

      it "handles empty hash in last_quote" do
        empty_quote_data = snapshot_data.dup
        empty_quote_data[:last_quote] = {}
        empty_quote_snapshot = described_class.new(empty_quote_data)
        expect(empty_quote_snapshot.bid_price).to be_nil
        expect(empty_quote_snapshot.ask_price).to be_nil
      end

      it "handles empty hash in daily_bar" do
        empty_bar_data = snapshot_data.dup
        empty_bar_data[:daily_bar] = {}
        empty_bar_snapshot = described_class.new(empty_bar_data)
        expect(empty_bar_snapshot.volume).to be_nil
        expect(empty_bar_snapshot.change_amount).to be_nil
        expect(empty_bar_snapshot.change_percent).to be_nil
      end
    end

    context "extreme numeric values" do
      it "handles very large volumes" do
        large_volume_data = snapshot_data.dup
        large_volume_data[:daily_bar] = {"v" => 999_999_999_999}
        large_volume_snapshot = described_class.new(large_volume_data)
        expect(large_volume_snapshot.volume).to eq(999_999_999_999)
      end

      it "handles very small prices" do
        tiny_price_data = snapshot_data.dup
        tiny_price_data[:last_trade] = {"p" => 0.0001}
        tiny_price_snapshot = described_class.new(tiny_price_data)
        expect(tiny_price_snapshot.current_price).to eq(0.0001)
      end

      it "handles very large price changes" do
        huge_change_data = snapshot_data.dup
        huge_change_data[:daily_bar] = {"change" => 500.0, "cp" => 50.0}
        huge_change_snapshot = described_class.new(huge_change_data)
        expect(huge_change_snapshot.formatted_change).to eq("+$500.0 (+50.0%)")
      end
    end
  end
end
