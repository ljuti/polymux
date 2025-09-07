# frozen_string_literal: true

require "spec_helper"

RSpec.describe Polymux::Api::Options do
  let(:config) { Polymux::Config.new(api_key: "test_key_123", base_url: "https://api.polygon.io") }
  let(:client) { Polymux::Client.new(config) }
  let(:options_api) { described_class.new(client) }

  describe "inheritance" do
    it "inherits from PolymuxRestHandler" do
      expect(described_class.superclass).to eq(Polymux::Client::PolymuxRestHandler)
    end

    it "has access to the parent client" do
      expect(options_api.send(:_client)).to eq(client)
    end
  end

  describe "#contracts" do
    context "when requesting all contracts" do
      before do
        stub_request(:get, "https://api.polygon.io/v3/reference/options/contracts")
          .with(headers: {"Authorization" => "Bearer test_key_123"})
          .to_return(
            status: 200,
            body: load_fixture("options_contracts"),
            headers: {"Content-Type" => "application/json"}
          )
      end

      it "makes GET request to options contracts endpoint" do
        options_api.contracts

        expect(a_request(:get, "https://api.polygon.io/v3/reference/options/contracts"))
          .to have_been_made.once
      end

      it "returns an array of Contract objects" do
        contracts = options_api.contracts

        expect(contracts).to be_an(Array)
        expect(contracts.length).to eq(2)
        expect(contracts).to all(be_a(Polymux::Api::Options::Contract))
      end

      it "transforms API data correctly" do
        contracts = options_api.contracts
        first_contract = contracts.first

        expect(first_contract.ticker).to eq("O:AAPL240315C00150000")
        expect(first_contract.underlying_ticker).to eq("AAPL")
        expect(first_contract.contract_type).to eq("call")
        expect(first_contract.strike_price).to eq(150.0)
        expect(first_contract.expiration_date).to eq("2024-03-15")
      end
    end

    context "when requesting contracts for specific ticker" do
      before do
        stub_request(:get, "https://api.polygon.io/v3/reference/options/contracts")
          .with(
            query: {underlying_ticker: "AAPL"},
            headers: {"Authorization" => "Bearer test_key_123"}
          )
          .to_return(
            status: 200,
            body: load_fixture("options_contracts"),
            headers: {"Content-Type" => "application/json"}
          )
      end

      it "includes underlying_ticker parameter in request" do
        options_api.contracts("AAPL")

        expect(a_request(:get, "https://api.polygon.io/v3/reference/options/contracts")
          .with(query: {underlying_ticker: "AAPL"})).to have_been_made.once
      end

      it "returns contracts for the specified ticker" do
        contracts = options_api.contracts("AAPL")

        expect(contracts).to all(be_a(Polymux::Api::Options::Contract))
        expect(contracts.map(&:underlying_ticker)).to all(eq("AAPL"))
      end
    end

    context "with additional filter options" do
      before do
        stub_request(:get, "https://api.polygon.io/v3/reference/options/contracts")
          .with(
            query: {
              underlying_ticker: "AAPL",
              contract_type: "call",
              limit: 50
            },
            headers: {"Authorization" => "Bearer test_key_123"}
          )
          .to_return(
            status: 200,
            body: load_fixture("options_contracts"),
            headers: {"Content-Type" => "application/json"}
          )
      end

      it "passes filter options to API request" do
        options_api.contracts("AAPL", contract_type: "call", limit: 50)

        expect(a_request(:get, "https://api.polygon.io/v3/reference/options/contracts")
          .with(query: {"underlying_ticker" => "AAPL", "contract_type" => "call", "limit" => 50})).to have_been_made.once
      end
    end
  end

  describe "#for_ticker" do
    before do
      stub_request(:get, "https://api.polygon.io/v3/reference/options/contracts")
        .with(
          query: {underlying_ticker: "TSLA"},
          headers: {"Authorization" => "Bearer test_key_123"}
        )
        .to_return(
          status: 200,
          body: load_fixture("options_contracts"),
          headers: {"Content-Type" => "application/json"}
        )
    end

    it "is an alias for contracts method with explicit ticker" do
      expect(options_api).to receive(:contracts).with("TSLA", {limit: 100})

      options_api.for_ticker("TSLA", limit: 100)
    end
  end

  describe "#snapshot" do
    let(:contract) do
      Polymux::Api::Options::Contract.new(
        cfi: "OCASPS",
        contract_type: "call",
        exercise_style: "american",
        expiration_date: "2024-03-15",
        primary_exchange: "CBOE",
        shares_per_contract: 100,
        strike_price: 150.0,
        ticker: "O:AAPL240315C00150000",
        underlying_ticker: "AAPL"
      )
    end

    context "with valid contract" do
      before do
        stub_request(:get, "https://api.polygon.io/v3/snapshot/options/AAPL/O:AAPL240315C00150000")
          .with(headers: {"Authorization" => "Bearer test_key_123"})
          .to_return(
            status: 200,
            body: load_fixture("options_snapshot"),
            headers: {"Content-Type" => "application/json"}
          )
      end

      it "makes GET request to options snapshot endpoint" do
        options_api.snapshot(contract)

        expect(a_request(:get, "https://api.polygon.io/v3/snapshot/options/AAPL/O:AAPL240315C00150000"))
          .to have_been_made.once
      end

      it "returns a Snapshot object" do
        snapshot = options_api.snapshot(contract)

        expect(snapshot).to be_a(Polymux::Api::Options::Snapshot)
      end

      it "transforms API data correctly" do
        snapshot = options_api.snapshot(contract)

        expect(snapshot.break_even_price).to eq(152.45)
        expect(snapshot.implied_volatility).to eq(0.28)
        expect(snapshot.open_interest).to eq(1542)
      end
    end

    context "when contract argument is invalid" do
      it "raises ArgumentError for non-Contract object" do
        expect {
          options_api.snapshot("invalid_argument")
        }.to raise_error(ArgumentError, "A Contract object must be provided")
      end
    end

    context "when API request fails" do
      before do
        stub_request(:get, "https://api.polygon.io/v3/snapshot/options/AAPL/O:AAPL240315C00150000")
          .with(headers: {"Authorization" => "Bearer test_key_123"})
          .to_return(status: 404)
      end

      it "raises Polymux::Api::Error on failed request" do
        expect {
          options_api.snapshot(contract)
        }.to raise_error(Polymux::Api::Error, "Failed to fetch snapshot for O:AAPL240315C00150000")
      end
    end
  end

  describe "#chain" do
    context "with valid underlying ticker" do
      before do
        stub_request(:get, "https://api.polygon.io/v3/snapshot/options/AAPL")
          .with(headers: {"Authorization" => "Bearer test_key_123"})
          .to_return(
            status: 200,
            body: load_fixture("options_chain"),
            headers: {"Content-Type" => "application/json"}
          )
      end

      it "makes GET request to options chain endpoint" do
        options_api.chain("AAPL")

        expect(a_request(:get, "https://api.polygon.io/v3/snapshot/options/AAPL"))
          .to have_been_made.once
      end

      it "returns an array of Snapshot objects" do
        chain = options_api.chain("AAPL")

        expect(chain).to be_an(Array)
        expect(chain.length).to eq(2)
        expect(chain).to all(be_a(Polymux::Api::Options::Snapshot))
      end
    end

    context "when underlying_ticker is not a string" do
      it "raises ArgumentError for non-string ticker" do
        expect {
          options_api.chain(123)
        }.to raise_error(ArgumentError, "Underlying ticker must be a string")
      end
    end

    context "when API request fails" do
      before do
        stub_request(:get, "https://api.polygon.io/v3/snapshot/options/INVALID")
          .with(headers: {"Authorization" => "Bearer test_key_123"})
          .to_return(status: 404)
      end

      it "raises Polymux::Api::Error on failed request" do
        expect {
          options_api.chain("INVALID")
        }.to raise_error(Polymux::Api::Error, "Failed to fetch options chain for INVALID")
      end
    end
  end

  describe "#trades" do
    context "with string ticker" do
      before do
        stub_request(:get, "https://api.polygon.io/v3/trades/O:AAPL240315C00150000")
          .with(headers: {"Authorization" => "Bearer test_key_123"})
          .to_return(
            status: 200,
            body: load_fixture("options_trades"),
            headers: {"Content-Type" => "application/json"}
          )
      end

      it "makes GET request to trades endpoint" do
        options_api.trades("O:AAPL240315C00150000")

        expect(a_request(:get, "https://api.polygon.io/v3/trades/O:AAPL240315C00150000"))
          .to have_been_made.once
      end

      it "returns an array of Trade objects" do
        trades = options_api.trades("O:AAPL240315C00150000")

        expect(trades).to be_an(Array)
        expect(trades.length).to eq(2)
        expect(trades).to all(be_a(Polymux::Api::Options::Trade))
      end
    end

    context "with Contract object" do
      let(:contract) do
        Polymux::Api::Options::Contract.new(
          cfi: "OCASPS",
          contract_type: "call",
          exercise_style: "american",
          expiration_date: "2024-03-15",
          primary_exchange: "CBOE",
          shares_per_contract: 100,
          strike_price: 150.0,
          ticker: "O:AAPL240315C00150000",
          underlying_ticker: "AAPL"
        )
      end

      before do
        stub_request(:get, "https://api.polygon.io/v3/trades/O:AAPL240315C00150000")
          .with(headers: {"Authorization" => "Bearer test_key_123"})
          .to_return(
            status: 200,
            body: load_fixture("options_trades"),
            headers: {"Content-Type" => "application/json"}
          )
      end

      it "extracts ticker from Contract object" do
        options_api.trades(contract)

        expect(a_request(:get, "https://api.polygon.io/v3/trades/O:AAPL240315C00150000"))
          .to have_been_made.once
      end
    end

    context "with invalid contract argument" do
      it "raises ArgumentError for invalid type" do
        expect {
          options_api.trades(123)
        }.to raise_error(ArgumentError, "Contract must be a ticker or a Contract object")
      end
    end

    context "when API request fails" do
      before do
        stub_request(:get, "https://api.polygon.io/v3/trades/INVALID")
          .with(headers: {"Authorization" => "Bearer test_key_123"})
          .to_return(status: 404)
      end

      it "raises Polymux::Api::Error on failed request" do
        expect {
          options_api.trades("INVALID")
        }.to raise_error(Polymux::Api::Error, "Failed to fetch trades for INVALID")
      end
    end
  end

  describe "#quotes" do
    context "with string ticker" do
      before do
        stub_request(:get, "https://api.polygon.io/v3/quotes/O:AAPL240315C00150000")
          .with(headers: {"Authorization" => "Bearer test_key_123"})
          .to_return(
            status: 200,
            body: load_fixture("options_quotes"),
            headers: {"Content-Type" => "application/json"}
          )
      end

      it "makes GET request to quotes endpoint" do
        options_api.quotes("O:AAPL240315C00150000")

        expect(a_request(:get, "https://api.polygon.io/v3/quotes/O:AAPL240315C00150000"))
          .to have_been_made.once
      end

      it "returns an array of Quote objects" do
        quotes = options_api.quotes("O:AAPL240315C00150000")

        expect(quotes).to be_an(Array)
        expect(quotes.length).to eq(2)
        expect(quotes).to all(be_a(Polymux::Api::Options::Quote))
      end
    end

    context "with invalid contract argument" do
      it "raises ArgumentError for invalid type" do
        expect {
          options_api.quotes(123)
        }.to raise_error(ArgumentError, "Contract must be a ticker or a Contract object")
      end
    end

    context "when API request fails" do
      before do
        stub_request(:get, "https://api.polygon.io/v3/quotes/INVALID")
          .with(headers: {"Authorization" => "Bearer test_key_123"})
          .to_return(status: 404)
      end

      it "raises Polymux::Api::Error on failed request" do
        expect {
          options_api.quotes("INVALID")
        }.to raise_error(Polymux::Api::Error, "Failed to fetch quotes for INVALID")
      end
    end
  end

  describe "#daily_summary" do
    context "with valid parameters" do
      before do
        stub_request(:get, "https://api.polygon.io/v1/open-close/O:AAPL240315C00150000/2024-03-14")
          .with(headers: {"Authorization" => "Bearer test_key_123"})
          .to_return(
            status: 200,
            body: load_fixture("options_daily_summary"),
            headers: {"Content-Type" => "application/json"}
          )
      end

      it "makes GET request to daily summary endpoint" do
        options_api.daily_summary("O:AAPL240315C00150000", "2024-03-14")

        expect(a_request(:get, "https://api.polygon.io/v1/open-close/O:AAPL240315C00150000/2024-03-14"))
          .to have_been_made.once
      end

      it "returns a DailySummary object" do
        summary = options_api.daily_summary("O:AAPL240315C00150000", "2024-03-14")

        expect(summary).to be_a(Polymux::Api::Options::DailySummary)
      end
    end

    context "with invalid contract argument" do
      it "raises ArgumentError for non-string and non-Contract" do
        expect {
          options_api.daily_summary(123, "2024-03-14")
        }.to raise_error(ArgumentError, "Contract must be a string or a contract object must be provided")
      end
    end

    context "with invalid date format" do
      it "raises ArgumentError for invalid date format" do
        expect {
          options_api.daily_summary("O:AAPL240315C00150000", "03/14/2024")
        }.to raise_error(ArgumentError, "Date must be a String in YYYY-MM-DD format")
      end

      it "raises ArgumentError for non-string date" do
        expect {
          options_api.daily_summary("O:AAPL240315C00150000", Date.today)
        }.to raise_error(ArgumentError, "Date must be a String in YYYY-MM-DD format")
      end
    end

    context "when API request fails" do
      before do
        stub_request(:get, "https://api.polygon.io/v1/open-close/INVALID/2024-03-14")
          .with(headers: {"Authorization" => "Bearer test_key_123"})
          .to_return(status: 404)
      end

      it "raises Polymux::Api::Error on failed request" do
        expect {
          options_api.daily_summary("INVALID", "2024-03-14")
        }.to raise_error(Polymux::Api::Error, "Failed to fetch daily summary for INVALID on 2024-03-14")
      end
    end
  end

  describe "#previous_day" do
    context "with valid contract" do
      before do
        stub_request(:get, "https://api.polygon.io/v2/aggs/ticker/O:AAPL240315C00150000/prev")
          .with(headers: {"Authorization" => "Bearer test_key_123"})
          .to_return(
            status: 200,
            body: load_fixture("options_previous_day"),
            headers: {"Content-Type" => "application/json"}
          )
      end

      it "makes GET request to previous day endpoint" do
        options_api.previous_day("O:AAPL240315C00150000")

        expect(a_request(:get, "https://api.polygon.io/v2/aggs/ticker/O:AAPL240315C00150000/prev"))
          .to have_been_made.once
      end

      it "returns a PreviousDay object" do
        previous_day = options_api.previous_day("O:AAPL240315C00150000")

        expect(previous_day).to be_a(Polymux::Api::Options::PreviousDay)
      end
    end

    context "with invalid contract argument" do
      it "raises ArgumentError for invalid type" do
        expect {
          options_api.previous_day(123)
        }.to raise_error(ArgumentError, "Contract must be a ticker or a Contract object")
      end
    end

    context "when API request fails" do
      before do
        stub_request(:get, "https://api.polygon.io/v2/aggs/ticker/INVALID/prev")
          .with(headers: {"Authorization" => "Bearer test_key_123"})
          .to_return(status: 404)
      end

      it "raises Polymux::Api::Error on failed request" do
        expect {
          options_api.previous_day("INVALID")
        }.to raise_error(Polymux::Api::Error, "Failed to fetch previous day summary for INVALID")
      end
    end

    context "when no previous day data is available" do
      before do
        stub_request(:get, "https://api.polygon.io/v2/aggs/ticker/O:AAPL240315C00150000/prev")
          .with(headers: {"Authorization" => "Bearer test_key_123"})
          .to_return(
            status: 200,
            body: '{"results": [], "status": "OK"}',
            headers: {"Content-Type" => "application/json"}
          )
      end

      it "raises NoPreviousDataFound error" do
        expect {
          options_api.previous_day("O:AAPL240315C00150000")
        }.to raise_error(Polymux::Api::Options::NoPreviousDataFound, "No previous day data found for O:AAPL240315C00150000")
      end
    end
  end
end
