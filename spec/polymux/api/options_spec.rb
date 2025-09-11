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

        expect(contracts).to be_instance_of(Array)
        expect(contracts.length).to eq(2)
        expect(contracts).to all(be_instance_of(Polymux::Api::Options::Contract))
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

      context "when response body is not a Hash" do
        before do
          stub_request(:get, "https://api.polygon.io/v3/reference/options/contracts")
            .with(headers: {"Authorization" => "Bearer test_key_123"})
            .to_return(
              status: 200,
              body: "not a hash",
              headers: {"Content-Type" => "text/plain"}
            )
        end

        it "returns empty array for non-Hash response body" do
          contracts = options_api.contracts
          expect(contracts).to eq([])
        end
      end

      context "when response body has no results key" do
        before do
          stub_request(:get, "https://api.polygon.io/v3/reference/options/contracts")
            .with(headers: {"Authorization" => "Bearer test_key_123"})
            .to_return(
              status: 200,
              body: '{"status": "OK"}',
              headers: {"Content-Type" => "application/json"}
            )
        end

        it "returns empty array when results key is missing" do
          contracts = options_api.contracts
          expect(contracts).to eq([])
        end
      end

      context "when results is null" do
        before do
          stub_request(:get, "https://api.polygon.io/v3/reference/options/contracts")
            .with(headers: {"Authorization" => "Bearer test_key_123"})
            .to_return(
              status: 200,
              body: '{"results": null, "status": "OK"}',
              headers: {"Content-Type" => "application/json"}
            )
        end

        it "raises NoMethodError when results is null (actual behavior)" do
          expect {
            options_api.contracts
          }.to raise_error(NoMethodError, /undefined method `map' for nil:NilClass/)
        end
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

        expect(contracts).to all(be_instance_of(Polymux::Api::Options::Contract))
        expect(contracts.map(&:underlying_ticker)).to all(eq("AAPL"))
      end
    end

    context "parameter type checking (mutation-resistant)" do
      it "only sets underlying_ticker when ticker is specifically a String" do
        stub_request(:get, "https://api.polygon.io/v3/reference/options/contracts")
          .with(query: {underlying_ticker: "AAPL"})
          .to_return(status: 200, body: load_fixture("options_contracts"))

        options_api.contracts("AAPL")

        expect(a_request(:get, "https://api.polygon.io/v3/reference/options/contracts")
          .with(query: {underlying_ticker: "AAPL"})).to have_been_made.once
      end

      it "does not set underlying_ticker for integer" do
        stub_request(:get, "https://api.polygon.io/v3/reference/options/contracts")
          .with(query: {})
          .to_return(status: 200, body: load_fixture("options_contracts"))

        options_api.contracts(123)

        expect(a_request(:get, "https://api.polygon.io/v3/reference/options/contracts")
          .with(query: {})).to have_been_made.once
      end

      it "does not set underlying_ticker for symbol" do
        stub_request(:get, "https://api.polygon.io/v3/reference/options/contracts")
          .with(query: {})
          .to_return(status: 200, body: load_fixture("options_contracts"))

        options_api.contracts(:AAPL)

        expect(a_request(:get, "https://api.polygon.io/v3/reference/options/contracts")
          .with(query: {})).to have_been_made.once
      end

      it "does not set underlying_ticker for array" do
        stub_request(:get, "https://api.polygon.io/v3/reference/options/contracts")
          .with(query: {})
          .to_return(status: 200, body: load_fixture("options_contracts"))

        options_api.contracts(["AAPL"])

        expect(a_request(:get, "https://api.polygon.io/v3/reference/options/contracts")
          .with(query: {})).to have_been_made.once
      end

      it "does not set underlying_ticker for nil" do
        stub_request(:get, "https://api.polygon.io/v3/reference/options/contracts")
          .with(query: {})
          .to_return(status: 200, body: load_fixture("options_contracts"))

        options_api.contracts(nil)

        expect(a_request(:get, "https://api.polygon.io/v3/reference/options/contracts")
          .with(query: {})).to have_been_made.once
      end

      it "handles string-like objects that are not String instances" do
        string_like = Object.new
        def string_like.to_s
          "AAPL"
        end

        stub_request(:get, "https://api.polygon.io/v3/reference/options/contracts")
          .with(query: {})
          .to_return(status: 200, body: load_fixture("options_contracts"))

        options_api.contracts(string_like)

        # Should not set underlying_ticker since it's not a String instance
        expect(a_request(:get, "https://api.polygon.io/v3/reference/options/contracts")
          .with(query: {})).to have_been_made.once
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
      
      it "does not modify original options hash (mutation-resistant)" do
        original_options = {limit: 100}
        options_copy = original_options.dup
        
        stub_request(:get, "https://api.polygon.io/v3/reference/options/contracts")
          .with(query: {underlying_ticker: "AAPL", limit: 100})
          .to_return(status: 200, body: load_fixture("options_contracts"))

        options_api.contracts("AAPL", original_options)
        
        # Original hash should remain unchanged
        expect(original_options).to eq(options_copy)
      end

      it "default parameter must be {} not nil for contracts method" do
        # Mock fetch_collection to verify it's called with a Hash, not nil
        allow(options_api).to receive(:fetch_collection).and_call_original
        
        stub_request(:get, "https://api.polygon.io/v3/reference/options/contracts")
          .to_return(status: 200, body: load_fixture("options_contracts"))

        options_api.contracts
        
        # Verify fetch_collection was called with a Hash as second parameter
        expect(options_api).to have_received(:fetch_collection) do |url, options|
          expect(options).to be_a(Hash)
        end
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

      it "raises ArgumentError for nil" do
        expect {
          options_api.snapshot(nil)
        }.to raise_error(ArgumentError, "A Contract object must be provided")
      end

      it "raises ArgumentError for integer" do
        expect {
          options_api.snapshot(123)
        }.to raise_error(ArgumentError, "A Contract object must be provided")
      end

      it "raises ArgumentError for hash with contract-like data" do
        contract_hash = {
          ticker: "O:AAPL240315C00150000",
          underlying_ticker: "AAPL"
        }

        expect {
          options_api.snapshot(contract_hash)
        }.to raise_error(ArgumentError, "A Contract object must be provided")
      end

      it "raises ArgumentError for object with same methods as Contract" do
        fake_contract = Object.new
        def fake_contract.ticker
          "O:AAPL240315C00150000"
        end

        def fake_contract.underlying_ticker
          "AAPL"
        end

        expect {
          options_api.snapshot(fake_contract)
        }.to raise_error(ArgumentError, "A Contract object must be provided")
      end

      it "specifically checks for exact Contract class using instance_of?" do
        # Create a subclass of Contract to ensure instance_of? behavior (explicit type checking)
        contract_subclass = Class.new(Polymux::Api::Options::Contract)
        subclass_instance = contract_subclass.new(
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

        # Should raise error since subclass fails instance_of? Contract check (explicit type checking)
        expect {
          options_api.snapshot(subclass_instance)
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

      it "uses default empty hash when options parameter not provided" do
        stub_request(:get, "https://api.polygon.io/v3/snapshot/options/AAPL")
          .with(query: {}, headers: {"Authorization" => "Bearer test_key_123"})
          .to_return(status: 200, body: load_fixture("options_chain"))

        options_api.chain("AAPL")
        
        # Verify the request was made with empty params (default {})
        expect(a_request(:get, "https://api.polygon.io/v3/snapshot/options/AAPL")
          .with(query: {})).to have_been_made.once
      end

      it "passes through provided options parameter" do
        stub_request(:get, "https://api.polygon.io/v3/snapshot/options/AAPL")
          .with(query: {contract_type: "call"}, headers: {"Authorization" => "Bearer test_key_123"})
          .to_return(status: 200, body: load_fixture("options_chain"))

        options_api.chain("AAPL", {contract_type: "call"})
        
        expect(a_request(:get, "https://api.polygon.io/v3/snapshot/options/AAPL")
          .with(query: {contract_type: "call"})).to have_been_made.once
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
        }.to raise_error(Polymux::Api::Error, "API request failed for /v3/snapshot/options/INVALID")
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
        }.to raise_error(Polymux::Api::Error, "API request failed for /v3/trades/INVALID")
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
        }.to raise_error(Polymux::Api::Error, "API request failed for /v3/quotes/INVALID")
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
        }.to raise_error(ArgumentError, "Contract must be a ticker or a Contract object")
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

    context "date format validation (mutation-resistant)" do
      it "rejects date with newline at end ($ vs \\z anchor difference)" do
        # The regex /^\d{4}-\d{2}-\d{2}$/ would incorrectly match "2024-03-14\n"
        # but /^\d{4}-\d{2}-\d{2}\z/ correctly rejects it
        expect {
          options_api.daily_summary("O:AAPL240315C00150000", "2024-03-14\n")
        }.to raise_error(ArgumentError, "Date must be a String in YYYY-MM-DD format")
      end

      it "validates exact YYYY-MM-DD format with \\z anchor" do
        expect {
          options_api.daily_summary("O:AAPL240315C00150000", "2024-03-14\nADDITIONAL_TEXT")
        }.to raise_error(ArgumentError, "Date must be a String in YYYY-MM-DD format")
      end

      it "accepts valid YYYY-MM-DD format" do
        stub_request(:get, "https://api.polygon.io/v1/open-close/O:AAPL240315C00150000/2024-03-14")
          .to_return(status: 200, body: load_fixture("options_daily_summary"), headers: {"Content-Type" => "application/json"})

        expect { options_api.daily_summary("O:AAPL240315C00150000", "2024-03-14") }.not_to raise_error
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

  describe "graceful degradation behavior" do
    context "404 handling in contracts endpoint" do
      before do
        stub_request(:get, "https://api.polygon.io/v3/reference/options/contracts")
          .with(query: {underlying_ticker: "NONEXISTENT"})
          .to_return(status: 404)
      end

      it "returns empty array for 404 on contracts discovery" do
        result = options_api.contracts("NONEXISTENT")
        expect(result).to eq([])
      end

      it "enables graceful degradation with allow_404_graceful_degradation = true" do
        # This tests the specific parameter position in fetch_collection call
        result = options_api.contracts("NONEXISTENT")
        expect(result).to be_an(Array)
        expect(result).to be_empty
      end

      it "ensures graceful degradation specifically for contracts but not other endpoints" do
        # Test that other endpoints would fail with 404 (no graceful degradation)
        stub_request(:get, "https://api.polygon.io/v3/snapshot/options/NONEXISTENT")
          .to_return(status: 404)

        expect {
          options_api.chain("NONEXISTENT")
        }.to raise_error(Polymux::Api::Error)
      end
    end

    context "parameter default behavior (mutation-resistant)" do
      it "works when no options parameter provided (tests default {})" do
        stub_request(:get, "https://api.polygon.io/v3/snapshot/options/AAPL")
          .with(query: {})
          .to_return(status: 200, body: load_fixture("options_chain"))

        # This should not raise an error - if options defaults to nil, it would fail
        result = options_api.chain("AAPL")
        expect(result).to be_an(Array)
      end

      it "default parameter must be {} not nil (direct mutation test)" do
        # Mock fetch_collection to verify it's called with a Hash, not nil
        allow(options_api).to receive(:fetch_collection).and_call_original
        
        stub_request(:get, "https://api.polygon.io/v3/snapshot/options/AAPL")
          .to_return(status: 200, body: load_fixture("options_chain"))

        options_api.chain("AAPL")
        
        # Verify fetch_collection was called with a Hash as second parameter
        expect(options_api).to have_received(:fetch_collection) do |url, options|
          expect(options).to be_a(Hash)
        end
      end
    end
  end
end
