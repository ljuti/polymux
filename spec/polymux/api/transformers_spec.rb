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

  describe ".ticker" do
    let(:raw_ticker) do
      {
        "ticker" => "AAPL",
        "name" => "Apple Inc.",
        "market" => "stocks",
        "locale" => "us",
        "primary_exchange" => "XNGS",
        "type" => "CS",
        "active" => true,
        "currency_name" => "usd",
        "cik" => "0000320193",
        "composite_figi" => "BBG000B9XRY4",
        "share_class_figi" => "BBG001S5N8V8",
        "last_updated_utc" => "2023-01-09T00:00:00Z"
      }
    end

    it "converts string keys to symbols" do
      result = described_class.ticker(raw_ticker)

      expect(result.keys).to all(be_a(Symbol))
    end

    it "preserves all ticker data" do
      result = described_class.ticker(raw_ticker)

      expect(result[:ticker]).to eq("AAPL")
      expect(result[:name]).to eq("Apple Inc.")
      expect(result[:market]).to eq("stocks")
      expect(result[:locale]).to eq("us")
      expect(result[:primary_exchange]).to eq("XNGS")
      expect(result[:type]).to eq("CS")
      expect(result[:active]).to eq(true)
      expect(result[:currency_name]).to eq("usd")
      expect(result[:cik]).to eq("0000320193")
      expect(result[:composite_figi]).to eq("BBG000B9XRY4")
      expect(result[:share_class_figi]).to eq("BBG001S5N8V8")
      expect(result[:last_updated_utc]).to eq("2023-01-09T00:00:00Z")
    end

    context "with empty input" do
      it "handles empty hash" do
        result = described_class.ticker({})

        expect(result).to eq({})
      end
    end

    context "with nil values" do
      let(:ticker_with_nils) do
        {
          "ticker" => "AAPL",
          "name" => nil,
          "active" => false
        }
      end

      it "preserves nil values" do
        result = described_class.ticker(ticker_with_nils)

        expect(result[:ticker]).to eq("AAPL")
        expect(result[:name]).to be_nil
        expect(result[:active]).to eq(false)
      end
    end
  end

  describe ".ticker_details" do
    let(:raw_ticker_details) do
      {
        "ticker" => "AAPL",
        "name" => "Apple Inc.",
        "description" => "Apple Inc. designs, manufactures, and markets smartphones",
        "homepage_url" => "https://www.apple.com",
        "total_employees" => 164000,
        "list_date" => "1980-12-12",
        "branding" => {
          "logo_url" => "https://api.polygon.io/v1/reference/company-branding/d3d3LmFwcGxlLmNvbQ/images/2022-01-10_logo.svg",
          "icon_url" => "https://api.polygon.io/v1/reference/company-branding/d3d3LmFwcGxlLmNvbQ/images/2022-01-10_icon.png"
        },
        "address" => {
          "address1" => "One Apple Park Way",
          "city" => "Cupertino",
          "state" => "CA",
          "postal_code" => "95014"
        },
        "phone_number" => "(408) 996-1010",
        "sic_code" => "3571",
        "sic_description" => "ELECTRONIC COMPUTERS"
      }
    end

    it "converts string keys to symbols" do
      result = described_class.ticker_details(raw_ticker_details)

      expect(result.keys).to all(be_a(Symbol))
    end

    it "symbolizes nested address keys" do
      result = described_class.ticker_details(raw_ticker_details)

      expect(result[:address].keys).to all(be_a(Symbol))
      expect(result[:address][:address1]).to eq("One Apple Park Way")
      expect(result[:address][:city]).to eq("Cupertino")
      expect(result[:address][:state]).to eq("CA")
      expect(result[:address][:postal_code]).to eq("95014")
    end

    it "preserves all ticker details data" do
      result = described_class.ticker_details(raw_ticker_details)

      expect(result[:ticker]).to eq("AAPL")
      expect(result[:name]).to eq("Apple Inc.")
      expect(result[:description]).to eq("Apple Inc. designs, manufactures, and markets smartphones")
      expect(result[:homepage_url]).to eq("https://www.apple.com")
      expect(result[:total_employees]).to eq(164000)
      expect(result[:list_date]).to eq("1980-12-12")
      expect(result[:phone_number]).to eq("(408) 996-1010")
      expect(result[:sic_code]).to eq("3571")
      expect(result[:sic_description]).to eq("ELECTRONIC COMPUTERS")
    end

    it "preserves nested branding with string keys" do
      result = described_class.ticker_details(raw_ticker_details)

      # The branding field is not automatically symbolized like address
      expect(result[:branding]["logo_url"]).to include("logo.svg")
      expect(result[:branding]["icon_url"]).to include("icon.png")
    end

    context "when address is nil" do
      let(:ticker_details_no_address) do
        {
          "ticker" => "AAPL",
          "name" => "Apple Inc.",
          "address" => nil
        }
      end

      it "handles nil address gracefully" do
        result = described_class.ticker_details(ticker_details_no_address)

        expect(result[:address]).to be_nil
        expect(result[:ticker]).to eq("AAPL")
      end
    end

    context "when address is not a hash" do
      let(:ticker_details_string_address) do
        {
          "ticker" => "AAPL",
          "address" => "One Apple Park Way, Cupertino, CA"
        }
      end

      it "preserves non-hash address" do
        result = described_class.ticker_details(ticker_details_string_address)

        expect(result[:address]).to eq("One Apple Park Way, Cupertino, CA")
      end
    end

    context "with empty address" do
      let(:ticker_details_empty_address) do
        {
          "ticker" => "AAPL",
          "address" => {}
        }
      end

      it "handles empty address hash" do
        result = described_class.ticker_details(ticker_details_empty_address)

        expect(result[:address]).to eq({})
      end
    end
  end

  describe ".stock_trade" do
    let(:ticker) { "AAPL" }
    let(:raw_stock_trade) do
      {
        "conditions" => [1, 14, 37],
        "p" => 150.25,
        "s" => 100,
        "sip_timestamp" => 1678901234000000000,
        "x" => 4,
        "participant_timestamp" => 1678901234000000000,
        "tape" => "A"
      }
    end

    it "adds ticker to the result" do
      result = described_class.stock_trade(ticker, raw_stock_trade)

      expect(result[:ticker]).to eq("AAPL")
    end

    it "renames p to price" do
      result = described_class.stock_trade(ticker, raw_stock_trade)

      expect(result[:price]).to eq(150.25)
      expect(result).not_to have_key(:p)
    end

    it "renames s to size" do
      result = described_class.stock_trade(ticker, raw_stock_trade)

      expect(result[:size]).to eq(100)
      expect(result).not_to have_key(:s)
    end

    it "renames x to exchange" do
      result = described_class.stock_trade(ticker, raw_stock_trade)

      expect(result[:exchange]).to eq(4)
      expect(result).not_to have_key(:x)
    end

    it "renames c to conditions when present" do
      trade_with_c = raw_stock_trade.merge("c" => [200])
      result = described_class.stock_trade(ticker, trade_with_c)

      expect(result[:conditions]).to eq([200])
      expect(result).not_to have_key(:c)
    end

    it "renames sip_timestamp to timestamp (overriding convert_timestamp)" do
      result = described_class.stock_trade(ticker, raw_stock_trade)

      # Due to rename_keys overriding the converted timestamp, original value is preserved
      expect(result[:timestamp]).to be_a(String)
      expect(result).not_to have_key(:sip_timestamp)
    end

    it "preserves other trade data" do
      result = described_class.stock_trade(ticker, raw_stock_trade)

      expect(result[:conditions]).to eq([1, 14, 37])
      expect(result[:participant_timestamp]).to eq(1678901234000000000)
      expect(result[:tape]).to eq("A")
    end

    context "with t field timestamp" do
      let(:trade_with_t) do
        {
          "p" => 150.25,
          "s" => 100,
          "t" => 1678901234000,
          "x" => 4
        }
      end

      it "renames t to timestamp" do
        result = described_class.stock_trade(ticker, trade_with_t)

        expect(result[:timestamp]).to be_a(String)
        expect(result).not_to have_key(:t)
      end
    end

    context "with participant_timestamp only" do
      let(:trade_with_participant) do
        {
          "p" => 150.25,
          "s" => 100,
          "participant_timestamp" => 1678901234000000000,
          "x" => 4
        }
      end

      it "uses participant_timestamp for conversion" do
        result = described_class.stock_trade(ticker, trade_with_participant)

        expect(result[:timestamp]).to be_a(String)
        expect(result[:participant_timestamp]).to eq(1678901234000000000)
      end
    end

    context "without any timestamp fields" do
      let(:trade_no_timestamp) do
        {
          "p" => 150.25,
          "s" => 100,
          "x" => 4
        }
      end

      it "handles missing timestamp fields" do
        result = described_class.stock_trade(ticker, trade_no_timestamp)

        expect(result[:timestamp]).to be_nil
        expect(result[:ticker]).to eq("AAPL")
        expect(result[:price]).to eq(150.25)
      end
    end

    context "with nil timestamp values" do
      let(:trade_nil_timestamp) do
        {
          "p" => 150.25,
          "s" => 100,
          "sip_timestamp" => nil,
          "t" => nil,
          "participant_timestamp" => nil
        }
      end

      it "handles nil timestamp values" do
        result = described_class.stock_trade(ticker, trade_nil_timestamp)

        expect(result[:timestamp]).to be_nil
        expect(result[:participant_timestamp]).to be_nil
      end
    end
  end

  describe ".stock_quote" do
    let(:ticker) { "AAPL" }
    let(:raw_stock_quote) do
      {
        "P" => 150.20,  # bid_price (capital P)
        "p" => 150.25,  # ask_price (lowercase p)
        "S" => 300,     # bid_size (capital S)
        "s" => 200,     # ask_size (lowercase s)
        "x" => 4,       # bid_exchange
        "X" => 11,      # ask_exchange
        "sip_timestamp" => 1678901234000000000,
        "c" => [1],
        "tape" => "A"
      }
    end

    it "adds ticker to the result" do
      result = described_class.stock_quote(ticker, raw_stock_quote)

      expect(result[:ticker]).to eq("AAPL")
    end

    it "renames P to bid_price" do
      result = described_class.stock_quote(ticker, raw_stock_quote)

      expect(result[:bid_price]).to eq(150.20)
      expect(result).not_to have_key(:P)
    end

    it "renames p to ask_price" do
      result = described_class.stock_quote(ticker, raw_stock_quote)

      expect(result[:ask_price]).to eq(150.25)
      expect(result).not_to have_key(:p)
    end

    it "renames S to bid_size" do
      result = described_class.stock_quote(ticker, raw_stock_quote)

      expect(result[:bid_size]).to eq(300)
      expect(result).not_to have_key(:S)
    end

    it "renames s to ask_size" do
      result = described_class.stock_quote(ticker, raw_stock_quote)

      expect(result[:ask_size]).to eq(200)
      expect(result).not_to have_key(:s)
    end

    it "renames x to bid_exchange" do
      result = described_class.stock_quote(ticker, raw_stock_quote)

      expect(result[:bid_exchange]).to eq(4)
      expect(result).not_to have_key(:x)
    end

    it "renames X to ask_exchange" do
      result = described_class.stock_quote(ticker, raw_stock_quote)

      expect(result[:ask_exchange]).to eq(11)
      expect(result).not_to have_key(:X)
    end

    it "renames c to conditions" do
      result = described_class.stock_quote(ticker, raw_stock_quote)

      expect(result[:conditions]).to eq([1])
      expect(result).not_to have_key(:c)
    end

    it "renames sip_timestamp to timestamp (overriding convert_timestamp)" do
      result = described_class.stock_quote(ticker, raw_stock_quote)

      # Due to rename_keys overriding the converted timestamp, original value is preserved
      expect(result[:timestamp]).to be_a(String)
      expect(result).not_to have_key(:sip_timestamp)
    end

    context "with t field timestamp" do
      let(:quote_with_t) do
        {
          "P" => 150.20,
          "p" => 150.25,
          "t" => 1678901234000,
          "S" => 300,
          "s" => 200
        }
      end

      it "renames t to timestamp" do
        result = described_class.stock_quote(ticker, quote_with_t)

        expect(result[:timestamp]).to be_a(String)
        expect(result).not_to have_key(:t)
      end
    end

    context "with participant_timestamp only" do
      let(:quote_with_participant) do
        {
          "P" => 150.20,
          "p" => 150.25,
          "participant_timestamp" => 1678901234000000000,
          "S" => 300,
          "s" => 200
        }
      end

      it "uses participant_timestamp for conversion" do
        result = described_class.stock_quote(ticker, quote_with_participant)

        expect(result[:timestamp]).to be_a(String)
        expect(result[:participant_timestamp]).to eq(1678901234000000000)
      end
    end

    context "without any timestamp fields" do
      let(:quote_no_timestamp) do
        {
          "P" => 150.20,
          "p" => 150.25,
          "S" => 300,
          "s" => 200
        }
      end

      it "handles missing timestamp fields" do
        result = described_class.stock_quote(ticker, quote_no_timestamp)

        expect(result[:timestamp]).to be_nil
        expect(result[:ticker]).to eq("AAPL")
        expect(result[:bid_price]).to eq(150.20)
        expect(result[:ask_price]).to eq(150.25)
      end
    end

    context "with partial field coverage" do
      let(:quote_partial) do
        {
          "P" => 150.20,  # Only bid price, no ask
          "S" => 300,     # Only bid size, no ask
          "x" => 4        # Only bid exchange, no ask
        }
      end

      it "handles partial field coverage" do
        result = described_class.stock_quote(ticker, quote_partial)

        expect(result[:bid_price]).to eq(150.20)
        expect(result[:bid_size]).to eq(300)
        expect(result[:bid_exchange]).to eq(4)
        expect(result[:ask_price]).to be_nil
        expect(result[:ask_size]).to be_nil
        expect(result[:ask_exchange]).to be_nil
      end
    end
  end

  describe ".stock_snapshot" do
    let(:raw_stock_snapshot) do
      {
        "ticker" => "AAPL",
        "todaysChangePerc" => 1.23,
        "todaysChange" => 1.85,
        "updated" => 1678901234000000000,
        "day" => {
          "o" => 150.00,
          "h" => 152.50,
          "l" => 149.75,
          "c" => 151.85,
          "v" => 2500000
        },
        "prevDay" => {
          "o" => 149.50,
          "h" => 151.00,
          "l" => 148.90,
          "c" => 150.00,
          "v" => 2200000
        },
        "lastTrade" => {
          "p" => 151.85,
          "s" => 100,
          "t" => 1678901234000000000
        },
        "lastQuote" => {
          "P" => 151.84,
          "p" => 151.86,
          "S" => 200,
          "s" => 150,
          "t" => 1678901234000000000
        }
      }
    end

    it "converts string keys to symbols" do
      result = described_class.stock_snapshot(raw_stock_snapshot)

      expect(result.keys).to all(be_a(Symbol))
    end

    it "renames day to daily_bar" do
      result = described_class.stock_snapshot(raw_stock_snapshot)

      expect(result[:daily_bar]).to eq({
        "o" => 150.00,
        "h" => 152.50,
        "l" => 149.75,
        "c" => 151.85,
        "v" => 2500000
      })
      expect(result).not_to have_key(:day)
    end

    it "renames prevDay to prev_daily_bar" do
      result = described_class.stock_snapshot(raw_stock_snapshot)

      expect(result[:prev_daily_bar]).to eq({
        "o" => 149.50,
        "h" => 151.00,
        "l" => 148.90,
        "c" => 150.00,
        "v" => 2200000
      })
      expect(result).not_to have_key(:prevDay)
    end

    it "renames lastTrade to last_trade" do
      result = described_class.stock_snapshot(raw_stock_snapshot)

      expect(result[:last_trade]).to eq({
        "p" => 151.85,
        "s" => 100,
        "t" => 1678901234000000000
      })
      expect(result).not_to have_key(:lastTrade)
    end

    it "renames lastQuote to last_quote" do
      result = described_class.stock_snapshot(raw_stock_snapshot)

      expect(result[:last_quote]).to eq({
        "P" => 151.84,
        "p" => 151.86,
        "S" => 200,
        "s" => 150,
        "t" => 1678901234000000000
      })
      expect(result).not_to have_key(:lastQuote)
    end

    it "preserves updated field" do
      result = described_class.stock_snapshot(raw_stock_snapshot)

      expect(result[:updated]).to eq(1678901234000000000)
    end

    it "preserves other snapshot data" do
      result = described_class.stock_snapshot(raw_stock_snapshot)

      expect(result[:ticker]).to eq("AAPL")
      expect(result[:todaysChangePerc]).to eq(1.23)
      expect(result[:todaysChange]).to eq(1.85)
    end

    context "when nested objects are empty" do
      let(:snapshot_with_empty_objects) do
        {
          "ticker" => "AAPL",
          "todaysChange" => 1.85,
          "day" => {},
          "prevDay" => {},
          "lastTrade" => {},
          "lastQuote" => {}
        }
      end

      it "removes empty daily_bar object" do
        result = described_class.stock_snapshot(snapshot_with_empty_objects)

        expect(result).not_to have_key(:daily_bar)
      end

      it "removes empty prev_daily_bar object" do
        result = described_class.stock_snapshot(snapshot_with_empty_objects)

        expect(result).not_to have_key(:prev_daily_bar)
      end

      it "removes empty last_trade object" do
        result = described_class.stock_snapshot(snapshot_with_empty_objects)

        expect(result).not_to have_key(:last_trade)
      end

      it "removes empty last_quote object" do
        result = described_class.stock_snapshot(snapshot_with_empty_objects)

        expect(result).not_to have_key(:last_quote)
      end
    end

    context "when nested objects are nil" do
      let(:snapshot_with_nil_objects) do
        {
          "ticker" => "AAPL",
          "day" => nil,
          "lastTrade" => nil
        }
      end

      it "preserves nil nested objects" do
        result = described_class.stock_snapshot(snapshot_with_nil_objects)

        expect(result[:daily_bar]).to be_nil
        expect(result[:last_trade]).to be_nil
      end
    end

    context "when only some nested objects are empty" do
      let(:snapshot_mixed_empty) do
        {
          "ticker" => "AAPL",
          "day" => {"c" => 151.85},
          "prevDay" => {},
          "lastTrade" => {"p" => 151.85},
          "lastQuote" => {}
        }
      end

      it "removes only empty objects, preserves non-empty ones" do
        result = described_class.stock_snapshot(snapshot_mixed_empty)

        expect(result[:daily_bar]).to eq({"c" => 151.85})
        expect(result[:last_trade]).to eq({"p" => 151.85})
        expect(result).not_to have_key(:prev_daily_bar)
        expect(result).not_to have_key(:last_quote)
      end
    end
  end

  describe ".stock_aggregate" do
    let(:ticker) { "AAPL" }
    let(:raw_stock_aggregate) do
      {
        "o" => 150.00,
        "h" => 152.50,
        "l" => 149.75,
        "c" => 151.85,
        "v" => 2500000,
        "vw" => 150.92,
        "t" => 1678901234000,
        "n" => 12456
      }
    end

    it "adds ticker to the result" do
      result = described_class.stock_aggregate(ticker, raw_stock_aggregate)

      expect(result[:ticker]).to eq("AAPL")
    end

    it "renames o to open" do
      result = described_class.stock_aggregate(ticker, raw_stock_aggregate)

      expect(result[:open]).to eq(150.00)
      expect(result).not_to have_key(:o)
    end

    it "renames h to high" do
      result = described_class.stock_aggregate(ticker, raw_stock_aggregate)

      expect(result[:high]).to eq(152.50)
      expect(result).not_to have_key(:h)
    end

    it "renames l to low" do
      result = described_class.stock_aggregate(ticker, raw_stock_aggregate)

      expect(result[:low]).to eq(149.75)
      expect(result).not_to have_key(:l)
    end

    it "renames c to close" do
      result = described_class.stock_aggregate(ticker, raw_stock_aggregate)

      expect(result[:close]).to eq(151.85)
      expect(result).not_to have_key(:c)
    end

    it "renames v to volume" do
      result = described_class.stock_aggregate(ticker, raw_stock_aggregate)

      expect(result[:volume]).to eq(2500000)
      expect(result).not_to have_key(:v)
    end

    it "renames vw to vwap" do
      result = described_class.stock_aggregate(ticker, raw_stock_aggregate)

      expect(result[:vwap]).to eq(150.92)
      expect(result).not_to have_key(:vw)
    end

    it "renames t to timestamp" do
      result = described_class.stock_aggregate(ticker, raw_stock_aggregate)

      expect(result[:timestamp]).to eq(1678901234000)
      expect(result).not_to have_key(:t)
    end

    it "renames n to transactions" do
      result = described_class.stock_aggregate(ticker, raw_stock_aggregate)

      expect(result[:transactions]).to eq(12456)
      expect(result).not_to have_key(:n)
    end

    context "with partial data" do
      let(:partial_aggregate) do
        {
          "o" => 150.00,
          "c" => 151.85,
          "v" => 2500000
        }
      end

      it "transforms available fields only" do
        result = described_class.stock_aggregate(ticker, partial_aggregate)

        expect(result[:open]).to eq(150.00)
        expect(result[:close]).to eq(151.85)
        expect(result[:volume]).to eq(2500000)
        expect(result[:ticker]).to eq("AAPL")
        expect(result[:high]).to be_nil
        expect(result[:low]).to be_nil
        expect(result[:vwap]).to be_nil
      end
    end

    context "with empty input" do
      it "handles empty hash" do
        result = described_class.stock_aggregate(ticker, {})

        expect(result[:ticker]).to eq("AAPL")
        expect(result.keys.length).to eq(1)
      end
    end
  end

  describe ".stock_daily_summary" do
    let(:raw_daily_summary) do
      {
        "status" => "OK",
        "request_id" => "abc123",
        "count" => 1,
        "queryCount" => 1,
        "resultsCount" => 1,
        "afterHours" => {
          "change" => 0.25,
          "changePercent" => 0.16,
          "close" => 152.10
        },
        "preMarket" => {
          "change" => -0.35,
          "changePercent" => -0.23,
          "open" => 151.50
        },
        "close" => {
          "o" => 150.00,
          "h" => 152.50,
          "l" => 149.75,
          "c" => 151.85
        }
      }
    end

    it "converts string keys to symbols" do
      result = described_class.stock_daily_summary(raw_daily_summary)

      expect(result.keys).to all(be_a(Symbol))
    end

    it "renames queryCount to query_count" do
      result = described_class.stock_daily_summary(raw_daily_summary)

      expect(result[:query_count]).to eq(1)
      expect(result).not_to have_key(:queryCount)
    end

    it "renames resultsCount to result_count" do
      result = described_class.stock_daily_summary(raw_daily_summary)

      expect(result[:result_count]).to eq(1)
      expect(result).not_to have_key(:resultsCount)
    end

    it "renames afterHours to after_hours_close" do
      result = described_class.stock_daily_summary(raw_daily_summary)

      expect(result[:after_hours_close]).to eq({
        "change" => 0.25,
        "changePercent" => 0.16,
        "close" => 152.10
      })
      expect(result).not_to have_key(:afterHours)
    end

    it "renames preMarket to pre_market_open" do
      result = described_class.stock_daily_summary(raw_daily_summary)

      expect(result[:pre_market_open]).to eq({
        "change" => -0.35,
        "changePercent" => -0.23,
        "open" => 151.50
      })
      expect(result).not_to have_key(:preMarket)
    end

    it "preserves other fields" do
      result = described_class.stock_daily_summary(raw_daily_summary)

      expect(result[:status]).to eq("OK")
      expect(result[:request_id]).to eq("abc123")
      expect(result[:count]).to eq(1)
      expect(result[:close]).to eq({
        "o" => 150.00,
        "h" => 152.50,
        "l" => 149.75,
        "c" => 151.85
      })
    end

    context "with minimal data" do
      let(:minimal_summary) do
        {
          "status" => "OK"
        }
      end

      it "handles missing camelCase fields" do
        result = described_class.stock_daily_summary(minimal_summary)

        expect(result[:status]).to eq("OK")
        expect(result[:query_count]).to be_nil
        expect(result[:result_count]).to be_nil
        expect(result[:after_hours_close]).to be_nil
        expect(result[:pre_market_open]).to be_nil
      end
    end

    context "with empty input" do
      it "handles empty hash" do
        result = described_class.stock_daily_summary({})

        expect(result).to eq({})
      end
    end
  end

  describe ".convert_timestamp" do
    # Testing private method by accessing it through send
    def convert_timestamp(timestamp)
      described_class.send(:convert_timestamp, timestamp)
    end

    context "with nanosecond timestamps (> 1e12)" do
      it "converts nanoseconds to ISO8601 format" do
        nanosecond_timestamp = 1678901234000000000
        result = convert_timestamp(nanosecond_timestamp)

        expect(result).to match(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}[+-]\d{2}:\d{2}\z|\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z\z/)
        expect(Time.parse(result).to_i).to eq(1678901234)
      end

      it "handles edge case at boundary" do
        boundary_timestamp = 1_000_000_000_001  # Just above boundary
        result = convert_timestamp(boundary_timestamp)

        expect(result).to be_a(String)
        expect(result).to match(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}[+-]\d{2}:\d{2}\z|\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z\z/)
      end
    end

    context "with millisecond timestamps (< 1e12)" do
      it "converts milliseconds to ISO8601 format" do
        # Use a true millisecond timestamp (13 digits is nanoseconds, 10-13 digits varies)
        millisecond_timestamp = 167890123400  # True milliseconds (12 digits)
        result = convert_timestamp(millisecond_timestamp)

        expect(result).to match(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}[+-]\d{2}:\d{2}\z|\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z\z/)
        expect(Time.parse(result).to_i).to eq(167890123)
      end

      it "handles second timestamps by treating as milliseconds (< 1e12 boundary)" do
        second_timestamp = 1678901234  # This gets treated as milliseconds since < 1e12
        result = convert_timestamp(second_timestamp)

        expect(result).to match(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}[+-]\d{2}:\d{2}\z|\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z\z/)
        # When divided by 1000, becomes 1678901 seconds
        expect(Time.parse(result).to_i).to eq(1678901)
      end
    end

    context "with string timestamps" do
      it "returns string timestamps unchanged" do
        string_timestamp = "2023-03-15T14:30:34Z"
        result = convert_timestamp(string_timestamp)

        expect(result).to eq("2023-03-15T14:30:34Z")
      end

      it "returns any string unchanged" do
        weird_string = "not-a-timestamp"
        result = convert_timestamp(weird_string)

        expect(result).to eq("not-a-timestamp")
      end
    end

    context "with nil input" do
      it "returns nil for nil input" do
        result = convert_timestamp(nil)

        expect(result).to be_nil
      end
    end

    context "with other types" do
      it "converts float to string" do
        float_input = 123.456
        result = convert_timestamp(float_input)

        expect(result).to eq("123.456")
      end

      it "converts symbol to string" do
        symbol_input = :timestamp
        result = convert_timestamp(symbol_input)

        expect(result).to eq("timestamp")
      end

      it "converts boolean to string" do
        boolean_input = true
        result = convert_timestamp(boolean_input)

        expect(result).to eq("true")
      end
    end

    context "with edge cases for arithmetic" do
      it "handles zero timestamp" do
        result = convert_timestamp(0)

        expect(result).to match(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}[+-]\d{2}:\d{2}\z|\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z\z/)
        expect(Time.parse(result).to_i).to eq(0)
      end

      it "handles negative timestamp" do
        result = convert_timestamp(-1000000)

        expect(result).to match(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}[+-]\d{2}:\d{2}\z|\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z\z/)
      end

      it "handles very large timestamp" do
        large_timestamp = 9999999999000000000
        result = convert_timestamp(large_timestamp)

        expect(result).to be_a(String)
        expect(result).to match(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}[+-]\d{2}:\d{2}\z|\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z\z/)
      end
    end
  end

  # Additional edge case tests for market_status to catch non-hash mutations
  describe ".market_status edge cases" do
    context "with non-hash input" do
      it "returns empty hash for nil input" do
        result = described_class.market_status(nil)

        expect(result).to eq({})
      end

      it "returns empty hash for string input" do
        result = described_class.market_status("not a hash")

        expect(result).to eq({})
      end

      it "returns empty hash for array input" do
        result = described_class.market_status([1, 2, 3])

        expect(result).to eq({})
      end

      it "returns empty hash for numeric input" do
        result = described_class.market_status(123)

        expect(result).to eq({})
      end

      it "returns empty hash for boolean input" do
        result = described_class.market_status(false)

        expect(result).to eq({})
      end
    end

    context "with empty hash" do
      it "handles empty hash correctly" do
        result = described_class.market_status({})

        expect(result).to eq({})
      end
    end

    context "with partial field coverage" do
      let(:partial_status) do
        {
          "market" => "open",
          "afterHours" => false
          # Missing earlyHours and indiceGroups
        }
      end

      it "transforms available fields only" do
        result = described_class.market_status(partial_status)

        expect(result[:status]).to eq("open")
        expect(result[:after_hours]).to eq(false)
        expect(result[:pre_market]).to be_nil
        expect(result[:indices]).to be_nil
      end
    end
  end

  describe ".ticker" do
    let(:raw_ticker) do
      {
        "ticker" => "AAPL",
        "name" => "Apple Inc.",
        "market" => "stocks",
        "locale" => "us",
        "primary_exchange" => "XNAS",
        "type" => "CS",
        "active" => true,
        "currency_name" => "usd",
        "cik" => "0000320193",
        "composite_figi" => "BBG000B9XRY4",
        "share_class_figi" => "BBG001S5N8V8"
      }
    end

    it "converts string keys to symbols" do
      result = described_class.ticker(raw_ticker)

      expect(result.keys).to all(be_a(Symbol))
      expect(result[:ticker]).to eq("AAPL")
      expect(result[:name]).to eq("Apple Inc.")
      expect(result[:active]).to eq(true)
    end

    it "preserves all ticker data" do
      result = described_class.ticker(raw_ticker)

      expect(result[:market]).to eq("stocks")
      expect(result[:locale]).to eq("us")
      expect(result[:primary_exchange]).to eq("XNAS")
      expect(result[:type]).to eq("CS")
      expect(result[:currency_name]).to eq("usd")
      expect(result[:cik]).to eq("0000320193")
      expect(result[:composite_figi]).to eq("BBG000B9XRY4")
      expect(result[:share_class_figi]).to eq("BBG001S5N8V8")
    end

    context "with empty hash" do
      it "returns empty hash with symbol keys" do
        result = described_class.ticker({})
        expect(result).to eq({})
      end
    end
  end

  describe ".ticker_details" do
    let(:raw_ticker_details) do
      {
        "ticker" => "AAPL",
        "name" => "Apple Inc.",
        "description" => "Apple Inc. designs, manufactures and markets smartphones",
        "homepage_url" => "https://www.apple.com",
        "total_employees" => 154000,
        "list_date" => "1980-12-12",
        "branding" => {
          "logo_url" => "https://api.polygon.io/v1/reference/company-branding/aapl/images/2022-01-10_logo.svg",
          "icon_url" => "https://api.polygon.io/v1/reference/company-branding/aapl/images/2022-01-10_icon.jpeg"
        },
        "address" => {
          "address1" => "One Apple Park Way",
          "city" => "Cupertino",
          "state" => "CA",
          "postal_code" => "95014"
        }
      }
    end

    it "converts string keys to symbols" do
      result = described_class.ticker_details(raw_ticker_details)

      expect(result.keys).to all(be_a(Symbol))
      expect(result[:ticker]).to eq("AAPL")
      expect(result[:name]).to eq("Apple Inc.")
      expect(result[:total_employees]).to eq(154000)
    end

    it "symbolizes nested address hash" do
      result = described_class.ticker_details(raw_ticker_details)

      expect(result[:address]).to be_a(Hash)
      expect(result[:address].keys).to all(be_a(Symbol))
      expect(result[:address][:address1]).to eq("One Apple Park Way")
      expect(result[:address][:city]).to eq("Cupertino")
      expect(result[:address][:state]).to eq("CA")
      expect(result[:address][:postal_code]).to eq("95014")
    end

    it "preserves non-address nested objects as-is" do
      result = described_class.ticker_details(raw_ticker_details)

      expect(result[:branding]).to eq(raw_ticker_details["branding"])
    end

    context "when address is not a hash" do
      let(:raw_ticker_no_address) do
        {
          "ticker" => "AAPL",
          "name" => "Apple Inc.",
          "address" => "One Apple Park Way, Cupertino, CA"
        }
      end

      it "preserves non-hash address" do
        result = described_class.ticker_details(raw_ticker_no_address)

        expect(result[:address]).to eq("One Apple Park Way, Cupertino, CA")
      end
    end

    context "when address is nil" do
      let(:raw_ticker_nil_address) do
        {
          "ticker" => "AAPL",
          "name" => "Apple Inc.",
          "address" => nil
        }
      end

      it "handles nil address gracefully" do
        result = described_class.ticker_details(raw_ticker_nil_address)

        expect(result[:address]).to be_nil
      end
    end
  end

  describe ".stock_trade" do
    let(:ticker) { "AAPL" }
    let(:raw_stock_trade) do
      {
        "p" => 150.25,
        "s" => 100,
        "c" => [14, 37],
        "x" => 4,
        "t" => 1678901234000000000,
        "r" => 123,
        "q" => 1
      }
    end

    it "adds ticker to the result" do
      result = described_class.stock_trade(ticker, raw_stock_trade)

      expect(result[:ticker]).to eq("AAPL")
    end

    it "renames short-form keys to descriptive names" do
      result = described_class.stock_trade(ticker, raw_stock_trade)

      expect(result[:price]).to eq(150.25)
      expect(result[:size]).to eq(100)
      expect(result[:conditions]).to eq([14, 37])
      expect(result[:exchange]).to eq(4)
      # t field gets converted to ISO string by convert_timestamp
      expect(result[:timestamp]).to be_a(String)
    end

    it "removes original short-form keys" do
      result = described_class.stock_trade(ticker, raw_stock_trade)

      expect(result).not_to have_key(:p)
      expect(result).not_to have_key(:s)
      expect(result).not_to have_key(:c)
      expect(result).not_to have_key(:x)
      # t field gets removed when it's used for timestamp conversion
      expect(result).not_to have_key(:t)
    end

    it "preserves other fields" do
      result = described_class.stock_trade(ticker, raw_stock_trade)

      expect(result[:r]).to eq(123)
      expect(result[:q]).to eq(1)
    end

    context "with sip_timestamp field" do
      let(:raw_trade_sip) do
        {
          "p" => 150.25,
          "s" => 100,
          "sip_timestamp" => 1678901234000000000
        }
      end

      it "handles sip_timestamp conversion" do
        result = described_class.stock_trade(ticker, raw_trade_sip)

        # sip_timestamp gets properly converted to string
        expect(result[:timestamp]).to be_a(String)
        expect(result).not_to have_key(:sip_timestamp)
      end
    end

    context "with participant_timestamp field" do
      let(:raw_trade_participant) do
        {
          "p" => 150.25,
          "s" => 100,
          "participant_timestamp" => 1678901234000000000
        }
      end

      it "handles participant_timestamp conversion" do
        result = described_class.stock_trade(ticker, raw_trade_participant)

        expect(result[:timestamp]).to be_a(String)
        expect(result[:participant_timestamp]).to eq(1678901234000000000) # Preserved in renames
      end
    end

    context "when no timestamp fields present" do
      let(:raw_trade_no_timestamp) do
        {
          "p" => 150.25,
          "s" => 100
        }
      end

      it "handles missing timestamp gracefully" do
        result = described_class.stock_trade(ticker, raw_trade_no_timestamp)

        expect(result[:timestamp]).to be_nil
        expect(result[:ticker]).to eq("AAPL")
        expect(result[:price]).to eq(150.25)
      end
    end
  end

  describe ".stock_quote" do
    let(:ticker) { "AAPL" }
    let(:raw_stock_quote) do
      {
        "P" => 150.20, # bid_price
        "p" => 150.25, # ask_price
        "S" => 300,    # bid_size
        "s" => 200,    # ask_size
        "x" => 4,      # bid_exchange
        "X" => 11,     # ask_exchange
        "t" => 1678901234000000000,
        "c" => [1],    # conditions
        "z" => 3       # other field
      }
    end

    it "adds ticker to the result" do
      result = described_class.stock_quote(ticker, raw_stock_quote)

      expect(result[:ticker]).to eq("AAPL")
    end

    it "renames quote-specific keys" do
      result = described_class.stock_quote(ticker, raw_stock_quote)

      expect(result[:bid_price]).to eq(150.20)
      expect(result[:ask_price]).to eq(150.25)
      expect(result[:bid_size]).to eq(300)
      expect(result[:ask_size]).to eq(200)
      expect(result[:bid_exchange]).to eq(4)
      expect(result[:ask_exchange]).to eq(11)
      expect(result[:conditions]).to eq([1])
      # t field gets converted to ISO string by convert_timestamp
      expect(result[:timestamp]).to be_a(String)
    end

    it "removes original short-form keys" do
      result = described_class.stock_quote(ticker, raw_stock_quote)

      expect(result).not_to have_key(:P)
      expect(result).not_to have_key(:p)
      expect(result).not_to have_key(:S)
      expect(result).not_to have_key(:s)
      expect(result).not_to have_key(:x)
      expect(result).not_to have_key(:X)
      # t field gets removed when it's used for timestamp conversion
      expect(result).not_to have_key(:t)
      expect(result).not_to have_key(:c)
    end

    it "preserves other fields" do
      result = described_class.stock_quote(ticker, raw_stock_quote)

      expect(result[:z]).to eq(3)
    end

    context "with different timestamp fields" do
      let(:raw_quote_sip) do
        {
          "P" => 150.20,
          "p" => 150.25,
          "sip_timestamp" => 1678901234000000000
        }
      end

      it "handles sip_timestamp" do
        result = described_class.stock_quote(ticker, raw_quote_sip)

        # sip_timestamp gets properly converted to string
        expect(result[:timestamp]).to be_a(String)
        expect(result).not_to have_key(:sip_timestamp)
      end
    end
  end

  describe ".stock_snapshot" do
    let(:raw_stock_snapshot) do
      {
        "ticker" => "AAPL",
        "day" => {"o" => 150.0, "h" => 152.0, "l" => 149.5, "c" => 151.0},
        "prevDay" => {"o" => 149.0, "c" => 150.5},
        "lastTrade" => {"p" => 151.0, "s" => 100},
        "lastQuote" => {"P" => 150.95, "p" => 151.05},
        "updated" => 1678901234000,
        "market_status" => "closed"
      }
    end

    it "renames snapshot-specific keys" do
      result = described_class.stock_snapshot(raw_stock_snapshot)

      expect(result[:daily_bar]).to eq({"o" => 150.0, "h" => 152.0, "l" => 149.5, "c" => 151.0})
      expect(result[:prev_daily_bar]).to eq({"o" => 149.0, "c" => 150.5})
      expect(result[:last_trade]).to eq({"p" => 151.0, "s" => 100})
      expect(result[:last_quote]).to eq({"P" => 150.95, "p" => 151.05})
      expect(result[:updated]).to eq(1678901234000)
    end

    it "removes original camelCase keys" do
      result = described_class.stock_snapshot(raw_stock_snapshot)

      expect(result).not_to have_key(:day)
      expect(result).not_to have_key(:prevDay)
      expect(result).not_to have_key(:lastTrade)
      expect(result).not_to have_key(:lastQuote)
    end

    it "preserves other fields" do
      result = described_class.stock_snapshot(raw_stock_snapshot)

      expect(result[:ticker]).to eq("AAPL")
      expect(result[:market_status]).to eq("closed")
    end

    context "when nested objects are empty" do
      let(:raw_snapshot_empty) do
        {
          "ticker" => "AAPL",
          "day" => {},
          "prevDay" => {},
          "lastTrade" => {},
          "lastQuote" => {},
          "updated" => 1678901234000
        }
      end

      it "removes empty nested objects" do
        result = described_class.stock_snapshot(raw_snapshot_empty)

        expect(result).not_to have_key(:daily_bar)
        expect(result).not_to have_key(:prev_daily_bar)
        expect(result).not_to have_key(:last_trade)
        expect(result).not_to have_key(:last_quote)
        expect(result[:ticker]).to eq("AAPL")
        expect(result[:updated]).to eq(1678901234000)
      end
    end

    context "when nested objects are nil" do
      let(:raw_snapshot_nil) do
        {
          "ticker" => "AAPL",
          "day" => nil,
          "lastQuote" => nil
        }
      end

      it "preserves nil values" do
        result = described_class.stock_snapshot(raw_snapshot_nil)

        expect(result[:daily_bar]).to be_nil
        expect(result[:last_quote]).to be_nil
      end
    end
  end

  describe ".stock_aggregate" do
    let(:ticker) { "AAPL" }
    let(:raw_stock_aggregate) do
      {
        "o" => 150.0,
        "h" => 152.0,
        "l" => 149.5,
        "c" => 151.0,
        "v" => 1500000,
        "vw" => 150.75,
        "t" => 1678901234000,
        "n" => 12543
      }
    end

    it "adds ticker to the result" do
      result = described_class.stock_aggregate(ticker, raw_stock_aggregate)

      expect(result[:ticker]).to eq("AAPL")
    end

    it "transforms OHLC keys to descriptive names" do
      result = described_class.stock_aggregate(ticker, raw_stock_aggregate)

      expect(result[:open]).to eq(150.0)
      expect(result[:high]).to eq(152.0)
      expect(result[:low]).to eq(149.5)
      expect(result[:close]).to eq(151.0)
      expect(result[:volume]).to eq(1500000)
      expect(result[:vwap]).to eq(150.75)
      expect(result[:timestamp]).to eq(1678901234000)
      expect(result[:transactions]).to eq(12543)
    end

    it "removes original single-letter keys" do
      result = described_class.stock_aggregate(ticker, raw_stock_aggregate)

      expect(result).not_to have_key(:o)
      expect(result).not_to have_key(:h)
      expect(result).not_to have_key(:l)
      expect(result).not_to have_key(:c)
      expect(result).not_to have_key(:v)
      expect(result).not_to have_key(:vw)
      expect(result).not_to have_key(:t)
      expect(result).not_to have_key(:n)
    end
  end

  describe ".stock_daily_summary" do
    let(:raw_daily_summary) do
      {
        "symbol" => "AAPL",
        "open" => 150.0,
        "close" => 151.0,
        "afterHours" => 151.25,
        "preMarket" => 149.75,
        "from" => "2024-01-15",
        "queryCount" => 1,
        "resultsCount" => 1,
        "request_id" => "abc123"
      }
    end

    it "converts camelCase to snake_case" do
      result = described_class.stock_daily_summary(raw_daily_summary)

      expect(result[:after_hours_close]).to eq(151.25)
      expect(result[:pre_market_open]).to eq(149.75)
      expect(result[:query_count]).to eq(1)
      expect(result[:result_count]).to eq(1)
    end

    it "removes original camelCase keys" do
      result = described_class.stock_daily_summary(raw_daily_summary)

      expect(result).not_to have_key(:afterHours)
      expect(result).not_to have_key(:preMarket)
      expect(result).not_to have_key(:queryCount)
      expect(result).not_to have_key(:resultsCount)
    end

    it "preserves other fields" do
      result = described_class.stock_daily_summary(raw_daily_summary)

      expect(result[:symbol]).to eq("AAPL")
      expect(result[:open]).to eq(150.0)
      expect(result[:close]).to eq(151.0)
      expect(result[:from]).to eq("2024-01-15")
      expect(result[:request_id]).to eq("abc123")
    end
  end

  describe ".convert_timestamp" do
    context "with nanosecond timestamps" do
      it "converts nanoseconds to ISO8601" do
        timestamp = 1678901234000000000 # > 1e12, so nanoseconds
        result = described_class.send(:convert_timestamp, timestamp)

        expected = Time.at(1678901234000000000 / 1_000_000_000.0).iso8601
        expect(result).to eq(expected)
      end
    end

    context "with millisecond timestamps" do
      it "converts milliseconds to ISO8601" do
        timestamp = 1678901234 # < 1e12, so treated as milliseconds
        result = described_class.send(:convert_timestamp, timestamp)

        expected = Time.at(1678901234 / 1_000.0).iso8601
        expect(result).to eq(expected)
      end
    end

    context "with second timestamps" do
      it "converts seconds to ISO8601" do
        timestamp = 1678901234 # Even smaller, treated as seconds
        result = described_class.send(:convert_timestamp, timestamp)

        expected = Time.at(1678901234 / 1_000.0).iso8601
        expect(result).to eq(expected)
      end
    end

    context "with string timestamps" do
      it "returns string as-is" do
        timestamp = "2024-01-15T10:30:00Z"
        result = described_class.send(:convert_timestamp, timestamp)

        expect(result).to eq("2024-01-15T10:30:00Z")
      end
    end

    context "with nil timestamp" do
      it "returns nil" do
        result = described_class.send(:convert_timestamp, nil)

        expect(result).to be_nil
      end
    end

    context "with other types" do
      it "converts to string" do
        timestamp = 12.5
        result = described_class.send(:convert_timestamp, timestamp)

        expect(result).to eq("12.5")
      end
    end
  end

  describe ".market_status with edge cases" do
    context "when input is not a hash" do
      it "returns empty hash for nil input" do
        result = described_class.market_status(nil)
        expect(result).to eq({})
      end

      it "returns empty hash for string input" do
        result = described_class.market_status("not a hash")
        expect(result).to eq({})
      end

      it "returns empty hash for array input" do
        result = described_class.market_status([1, 2, 3])
        expect(result).to eq({})
      end
    end

    context "with empty hash input" do
      it "returns empty hash" do
        result = described_class.market_status({})
        expect(result).to eq({})
      end
    end
  end

  describe "hash access patterns for mutation testing" do
    let(:test_hash) { {"key1" => "value1", "key2" => "value2"} }

    # These tests specifically target [] vs fetch() mutations
    it "symbolize_keys handles missing keys gracefully" do
      result = described_class[:symbolize_keys].call(test_hash)

      expect(result[:key1]).to eq("value1")
      expect(result[:key2]).to eq("value2")
      expect(result[:nonexistent]).to be_nil
    end

    it "rename_keys handles missing source keys gracefully" do
      result = described_class[:rename_keys].call({key1: "value1"}, {nonexistent: :new_name})

      expect(result[:key1]).to eq("value1")
      expect(result[:new_name]).to be_nil
    end

    # Test behavior when transformer registry keys might be missing
    context "transformer registry access" do
      it "handles symbolize_keys transformation consistently" do
        input = {"test" => "value", "nested" => {"inner" => "data"}}

        # These should behave identically with [] or fetch()
        result = described_class[:symbolize_keys].call(input)
        expect(result).to have_key(:test)
        expect(result[:test]).to eq("value")
      end

      it "handles rename_keys transformation consistently" do
        input = {old_key: "value", keep_key: "keep"}
        renames = {old_key: :new_key, missing_key: :also_missing}

        # These should behave identically with [] or fetch()
        result = described_class[:rename_keys].call(input, renames)
        expect(result[:new_key]).to eq("value")
        expect(result[:keep_key]).to eq("keep")
        expect(result).not_to have_key(:old_key)
      end

      it "validates that fetch() is used for transformer registry access" do
        # This test ensures our code uses the more explicit fetch() pattern
        input = {"key" => "value"}

        # Mock to verify fetch is called instead of []
        expect(described_class).to receive(:fetch).with(:symbolize_keys).and_call_original

        described_class.contract(input)
      end

      it "validates transformer registry has all expected keys" do
        # Ensure the registry has the expected transformer methods
        expect(described_class.respond_to?(:[]))
        expect(described_class.respond_to?(:fetch))

        # Verify specific transformers exist
        expect { described_class.fetch(:symbolize_keys) }.not_to raise_error
        expect { described_class.fetch(:rename_keys) }.not_to raise_error
      end
    end

    # Edge case tests to catch conditional mutations
    context "conditional logic mutations" do
      it "handles falsy timestamp values in quote" do
        # Test with timestamp = 0 (falsy but valid)
        raw_quote = {"sip_timestamp" => 0, "ask_price" => 3.30}
        result = described_class.quote(raw_quote)

        expect(result[:timestamp]).to eq(0)
        # Should still convert to datetime even with 0 timestamp
        expect(result[:datetime]).to eq(Time.at(0).to_datetime)
      end

      it "handles falsy timestamp values in trade" do
        raw_trade = {"sip_timestamp" => 0, "price" => 3.25}
        result = described_class.trade(raw_trade)

        expect(result[:timestamp]).to eq(0)
        expect(result[:datetime]).to eq(Time.at(0).to_datetime)
      end

      it "handles missing timestamp field in stock methods" do
        raw_trade = {"p" => 150.25, "s" => 100}
        result = described_class.stock_trade("AAPL", raw_trade)

        expect(result[:timestamp]).to be_nil
        expect(result[:price]).to eq(150.25)
        expect(result[:ticker]).to eq("AAPL")
      end
    end

    # Arithmetic and comparison edge cases
    context "arithmetic mutations in convert_timestamp" do
      it "tests boundary conditions for nanosecond detection" do
        # Test exactly at the boundary (1e12)
        boundary_value = 1_000_000_000_000
        result = described_class.send(:convert_timestamp, boundary_value)

        # At boundary, should be treated as milliseconds (not nanoseconds)
        expected = Time.at(boundary_value / 1_000.0).iso8601
        expect(result).to eq(expected)
      end

      it "tests just above the boundary" do
        above_boundary = 1_000_000_000_001
        result = described_class.send(:convert_timestamp, above_boundary)

        # Above boundary, should be treated as nanoseconds
        expected = Time.at(above_boundary / 1_000_000_000.0).iso8601
        expect(result).to eq(expected)
      end
    end

    # Hash existence and deletion mutations
    context "hash manipulation mutations" do
      it "tests hash key existence checks in snapshot cleanup" do
        # Test with all combinations of empty/nil/missing nested objects
        scenarios = [
          {"day" => {}, "lastQuote" => nil, "lastTrade" => {"p" => 1}},
          {"day" => nil, "lastQuote" => {}, "lastTrade" => nil},
          {"lastQuote" => {}, "lastTrade" => {}}
        ]

        scenarios.each do |raw_snapshot|
          result = described_class.snapshot(raw_snapshot)

          # Empty hashes should be removed, nil values preserved
          if raw_snapshot["day"] == {}
            expect(result).not_to have_key(:daily_bar)
          elsif raw_snapshot["day"].nil?
            expect(result[:daily_bar]).to be_nil
          end

          if raw_snapshot["lastQuote"] == {}
            expect(result).not_to have_key(:last_quote)
          elsif raw_snapshot["lastQuote"].nil?
            expect(result[:last_quote]).to be_nil
          end
        end
      end

      it "tests address symbolization with various input types" do
        test_cases = [
          {"address" => {"street" => "123 Main St"}},  # Hash to symbolize
          {"address" => "123 Main St"},                   # String to preserve
          {"address" => nil},                              # Nil to preserve
          {"address" => []},                               # Array to preserve
          {}                                                # Missing address
        ]

        test_cases.each do |raw_ticker|
          result = described_class.ticker_details(raw_ticker)

          if raw_ticker["address"].is_a?(Hash)
            expect(result[:address]).to be_a(Hash)
            expect(result[:address].keys).to all(be_a(Symbol))
          else
            expect(result[:address]).to eq(raw_ticker["address"])
          end
        end
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
