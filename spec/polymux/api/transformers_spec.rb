# frozen_string_literal: true

require "spec_helper"

RSpec.describe Polymux::Api::Transformers do
  describe ".contract" do
    let(:raw_contract) do
      {
        "cfi" => "OCASPS",
        "contract_type" => "call",
        "exercise_style" => "american",
        "expiration_date" => "2024-03-15",
        "primary_exchange" => "CBOE",
        "shares_per_contract" => 100,
        "strike_price" => 150.0,
        "ticker" => "O:AAPL240315C00150000",
        "underlying_ticker" => "AAPL"
      }
    end

    it "converts string keys to symbols" do
      result = described_class.contract(raw_contract)

      expect(result.keys).to all(be_a(Symbol))
    end

    it "preserves all original data" do
      result = described_class.contract(raw_contract)

      expect(result[:cfi]).to eq("OCASPS")
      expect(result[:contract_type]).to eq("call")
      expect(result[:exercise_style]).to eq("american")
      expect(result[:expiration_date]).to eq("2024-03-15")
      expect(result[:primary_exchange]).to eq("CBOE")
      expect(result[:shares_per_contract]).to eq(100)
      expect(result[:strike_price]).to eq(150.0)
      expect(result[:ticker]).to eq("O:AAPL240315C00150000")
      expect(result[:underlying_ticker]).to eq("AAPL")
    end
  end

  describe ".quote" do
    let(:raw_quote) do
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

    it "renames sip_timestamp to timestamp" do
      result = described_class.quote(raw_quote)

      expect(result[:timestamp]).to eq(1678901234000000000)
      expect(result).not_to have_key(:sip_timestamp)
    end

    it "renames sequence_number to sequence" do
      result = described_class.quote(raw_quote)

      expect(result[:sequence]).to eq(12345)
      expect(result).not_to have_key(:sequence_number)
    end

    it "converts timestamp to datetime" do
      result = described_class.quote(raw_quote)

      expected_datetime = Time.at(1678901234000000000 / 1_000_000_000).to_datetime
      expect(result[:datetime]).to eq(expected_datetime)
    end

    it "preserves other quote data" do
      result = described_class.quote(raw_quote)

      expect(result[:ask_price]).to eq(3.30)
      expect(result[:ask_size]).to eq(25)
      expect(result[:bid_price]).to eq(3.20)
      expect(result[:bid_size]).to eq(30)
      expect(result[:timeframe]).to eq("REALTIME")
    end

    context "when timestamp is nil" do
      let(:raw_quote_no_timestamp) do
        {
          "ask_price" => 3.30,
          "bid_price" => 3.20,
          "sip_timestamp" => nil
        }
      end

      it "handles nil timestamp gracefully" do
        result = described_class.quote(raw_quote_no_timestamp)

        expect(result[:timestamp]).to be_nil
        expect(result[:datetime]).to be_nil
      end
    end
  end

  describe ".trade" do
    let(:raw_trade) do
      {
        "conditions" => [200],
        "price" => 3.25,
        "sip_timestamp" => 1678901234000000000,
        "size" => 5,
        "timeframe" => "REALTIME"
      }
    end

    it "renames sip_timestamp to timestamp" do
      result = described_class.trade(raw_trade)

      expect(result[:timestamp]).to eq(1678901234000000000)
      expect(result).not_to have_key(:sip_timestamp)
    end

    it "converts timestamp to datetime" do
      result = described_class.trade(raw_trade)

      expected_datetime = Time.at(1678901234000000000 / 1_000_000_000).to_datetime
      expect(result[:datetime]).to eq(expected_datetime)
    end

    it "preserves other trade data" do
      result = described_class.trade(raw_trade)

      expect(result[:conditions]).to eq([200])
      expect(result[:price]).to eq(3.25)
      expect(result[:size]).to eq(5)
      expect(result[:timeframe]).to eq("REALTIME")
    end

    context "when timestamp is nil" do
      let(:raw_trade_no_timestamp) do
        {
          "price" => 3.25,
          "size" => 5,
          "sip_timestamp" => nil
        }
      end

      it "handles nil timestamp gracefully" do
        result = described_class.trade(raw_trade_no_timestamp)

        expect(result[:timestamp]).to be_nil
        expect(result[:datetime]).to be_nil
      end
    end
  end

  describe ".market_status" do
    let(:raw_market_status) do
      {
        "market" => "open",
        "afterHours" => false,
        "earlyHours" => false,
        "exchanges" => {"nasdaq" => "open"},
        "currencies" => {"fx" => "open"},
        "indiceGroups" => {"s_and_p" => "open"}
      }
    end

    it "renames market to status" do
      result = described_class.market_status(raw_market_status)

      expect(result[:status]).to eq("open")
      expect(result).not_to have_key(:market)
    end

    it "renames afterHours to after_hours" do
      result = described_class.market_status(raw_market_status)

      expect(result[:after_hours]).to eq(false)
      expect(result).not_to have_key(:afterHours)
    end

    it "renames earlyHours to pre_market" do
      result = described_class.market_status(raw_market_status)

      expect(result[:pre_market]).to eq(false)
      expect(result).not_to have_key(:earlyHours)
    end

    it "renames indiceGroups to indices" do
      result = described_class.market_status(raw_market_status)

      expect(result[:indices]).to eq({"s_and_p" => "open"})
      expect(result).not_to have_key(:indiceGroups)
    end

    it "preserves other market status data" do
      result = described_class.market_status(raw_market_status)

      expect(result[:exchanges]).to eq({"nasdaq" => "open"})
      expect(result[:currencies]).to eq({"fx" => "open"})
    end
  end

  describe ".previous_day" do
    let(:raw_previous_day) do
      {
        "T" => "O:AAPL240315C00150000",
        "c" => 3.10,
        "h" => 3.25,
        "l" => 2.95,
        "o" => 3.05,
        "t" => 1678815600000,
        "v" => 12450,
        "vw" => 3.08
      }
    end

    it "transforms single-letter keys to descriptive names" do
      result = described_class.previous_day(raw_previous_day)

      expect(result[:ticker]).to eq("O:AAPL240315C00150000")
      expect(result[:close]).to eq(3.10)
      expect(result[:high]).to eq(3.25)
      expect(result[:low]).to eq(2.95)
      expect(result[:open]).to eq(3.05)
      expect(result[:timestamp]).to eq(1678815600000)
      expect(result[:volume]).to eq(12450)
      expect(result[:vwap]).to eq(3.08)
    end

    it "removes original single-letter keys" do
      result = described_class.previous_day(raw_previous_day)

      expect(result).not_to have_key(:T)
      expect(result).not_to have_key(:c)
      expect(result).not_to have_key(:h)
      expect(result).not_to have_key(:l)
      expect(result).not_to have_key(:o)
      expect(result).not_to have_key(:t)
      expect(result).not_to have_key(:v)
      expect(result).not_to have_key(:vw)
    end
  end

  describe ".snapshot" do
    let(:raw_snapshot) do
      {
        "break_even_price" => 152.45,
        "day" => {"volume" => 15430},
        "last_quote" => {"ask_price" => 3.30},
        "last_trade" => {"price" => 3.25},
        "open_interest" => 1542
      }
    end

    it "renames day to daily_bar" do
      result = described_class.snapshot(raw_snapshot)

      expect(result[:daily_bar]).to eq({"volume" => 15430})
      expect(result).not_to have_key(:day)
    end

    it "preserves other snapshot data" do
      result = described_class.snapshot(raw_snapshot)

      expect(result[:break_even_price]).to eq(152.45)
      expect(result[:last_quote]).to eq({"ask_price" => 3.30})
      expect(result[:last_trade]).to eq({"price" => 3.25})
      expect(result[:open_interest]).to eq(1542)
    end

    context "when nested objects are empty" do
      let(:raw_snapshot_empty) do
        {
          "break_even_price" => 152.45,
          "day" => {},
          "last_quote" => {},
          "last_trade" => {},
          "open_interest" => 1542
        }
      end

      it "removes empty last_quote object" do
        result = described_class.snapshot(raw_snapshot_empty)

        expect(result).not_to have_key(:last_quote)
      end

      it "removes empty last_trade object" do
        result = described_class.snapshot(raw_snapshot_empty)

        expect(result).not_to have_key(:last_trade)
      end

      it "removes empty daily_bar object" do
        result = described_class.snapshot(raw_snapshot_empty)

        expect(result).not_to have_key(:daily_bar)
      end

      it "preserves non-empty fields" do
        result = described_class.snapshot(raw_snapshot_empty)

        expect(result[:break_even_price]).to eq(152.45)
        expect(result[:open_interest]).to eq(1542)
      end
    end
  end

  describe "module structure" do
    it "extends Dry::Transformer::Registry" do
      expect(described_class.singleton_class.included_modules).to include(Dry::Transformer::Registry)
    end

    it "imports required transformations" do
      expect(described_class).to respond_to(:[])
    end
  end
end
