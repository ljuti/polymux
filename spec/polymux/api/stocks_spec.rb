# frozen_string_literal: true

require "spec_helper"

RSpec.describe Polymux::Api::Stocks do
  let(:config) { Polymux::Config.new(api_key: "test_key_123", base_url: "https://api.polygon.io") }
  let(:client) { Polymux::Client.new(config) }
  let(:stocks_api) { described_class.new(client) }

  describe "inheritance" do
    it "inherits from PolymuxRestHandler" do
      expect(described_class.superclass).to eq(Polymux::Client::PolymuxRestHandler)
    end

    it "has access to the parent client" do
      expect(stocks_api.send(:_client)).to eq(client)
    end
  end

  describe "#tickers" do
    context "when requesting all active tickers" do
      before do
        stub_request(:get, "https://api.polygon.io/v3/reference/tickers")
          .with(
            query: {active: "true", limit: "100"},
            headers: {"Authorization" => "Bearer test_key_123"}
          )
          .to_return(
            status: 200,
            body: load_fixture("stocks_tickers"),
            headers: {"Content-Type" => "application/json"}
          )
      end

      it "makes GET request to tickers endpoint with default params" do
        stocks_api.tickers

        expect(a_request(:get, "https://api.polygon.io/v3/reference/tickers")
          .with(query: {active: "true", limit: "100"}))
          .to have_been_made.once
      end

      it "returns an array of Ticker objects" do
        tickers = stocks_api.tickers

        expect(tickers).to be_an(Array)
        expect(tickers.length).to eq(2)
        expect(tickers).to all(be_a(Polymux::Api::Stocks::Ticker))
      end

      it "transforms API data correctly" do
        tickers = stocks_api.tickers
        first_ticker = tickers.first

        expect(first_ticker.ticker).to eq("AAPL")
        expect(first_ticker.name).to eq("Apple Inc.")
        expect(first_ticker.market).to eq("stocks")
        expect(first_ticker.active).to be true
        expect(first_ticker.common_stock?).to be true
      end
    end

    context "with custom filtering options" do
      before do
        stub_request(:get, "https://api.polygon.io/v3/reference/tickers")
          .with(
            query: {ticker: "AAPL", active: "true", limit: "1"},
            headers: {"Authorization" => "Bearer test_key_123"}
          )
          .to_return(status: 200, body: {results: []}.to_json)
      end

      it "passes custom options to API request" do
        stocks_api.tickers(ticker: "AAPL", limit: 1)

        expect(a_request(:get, "https://api.polygon.io/v3/reference/tickers")
          .with(query: {ticker: "AAPL", active: "true", limit: "1"}))
          .to have_been_made.once
      end
    end

    context "when API returns empty results" do
      before do
        stub_request(:get, "https://api.polygon.io/v3/reference/tickers")
          .with(
            query: {active: "true", limit: "100"},
            headers: {"Authorization" => "Bearer test_key_123"}
          )
          .to_return(status: 200, body: {results: []}.to_json)
      end

      it "returns empty array" do
        tickers = stocks_api.tickers
        expect(tickers).to eq([])
      end
    end
  end

  describe "#ticker_details" do
    context "when requesting ticker details" do
      before do
        stub_request(:get, "https://api.polygon.io/v3/reference/tickers/AAPL")
          .with(headers: {"Authorization" => "Bearer test_key_123"})
          .to_return(
            status: 200,
            body: load_fixture("stocks_ticker_details"),
            headers: {"Content-Type" => "application/json"}
          )
      end

      it "makes GET request to ticker details endpoint" do
        stocks_api.ticker_details("AAPL")

        expect(a_request(:get, "https://api.polygon.io/v3/reference/tickers/AAPL"))
          .to have_been_made.once
      end

      it "returns TickerDetails object" do
        details = stocks_api.ticker_details("AAPL")

        expect(details).to be_a(Polymux::Api::Stocks::TickerDetails)
        expect(details.ticker).to eq("AAPL")
        expect(details.name).to eq("Apple Inc.")
        expect(details.market_cap).to eq(2800000000000)
        expect(details.formatted_market_cap).to eq("$2.8T")
      end
    end

    context "with invalid ticker argument" do
      it "raises ArgumentError for non-string ticker" do
        expect { stocks_api.ticker_details(123) }.to raise_error(ArgumentError, "Ticker must be a string")
      end
    end
  end

  describe "#snapshot" do
    context "when requesting stock snapshot" do
      before do
        stub_request(:get, "https://api.polygon.io/v2/snapshot/locale/us/markets/stocks/tickers/AAPL")
          .with(headers: {"Authorization" => "Bearer test_key_123"})
          .to_return(
            status: 200,
            body: {ticker: JSON.parse(load_fixture("stocks_snapshot"))}.to_json,
            headers: {"Content-Type" => "application/json"}
          )
      end

      it "makes GET request to snapshot endpoint" do
        stocks_api.snapshot("AAPL")

        expect(a_request(:get, "https://api.polygon.io/v2/snapshot/locale/us/markets/stocks/tickers/AAPL"))
          .to have_been_made.once
      end

      it "returns Snapshot object" do
        snapshot = stocks_api.snapshot("AAPL")

        expect(snapshot).to be_a(Polymux::Api::Stocks::Snapshot)
        expect(snapshot.ticker).to eq("AAPL")
      end
    end

    context "with invalid ticker argument" do
      it "raises ArgumentError for non-string ticker" do
        expect { stocks_api.snapshot(123) }.to raise_error(ArgumentError, "Ticker must be a string")
      end
    end
  end

  describe "#trades" do
    context "when requesting stock trades" do
      before do
        stub_request(:get, "https://api.polygon.io/v3/trades/AAPL")
          .with(headers: {"Authorization" => "Bearer test_key_123"})
          .to_return(
            status: 200,
            body: load_fixture("stocks_trades"),
            headers: {"Content-Type" => "application/json"}
          )
      end

      it "makes GET request to trades endpoint" do
        stocks_api.trades("AAPL")

        expect(a_request(:get, "https://api.polygon.io/v3/trades/AAPL"))
          .to have_been_made.once
      end

      it "returns array of Trade objects" do
        trades = stocks_api.trades("AAPL")

        expect(trades).to be_an(Array)
        expect(trades.length).to eq(2)
        expect(trades).to all(be_a(Polymux::Api::Stocks::Trade))

        first_trade = trades.first
        expect(first_trade.ticker).to eq("AAPL")
        expect(first_trade.price).to eq(174.49)
        expect(first_trade.size).to eq(100)
      end
    end

    context "with query options" do
      before do
        stub_request(:get, "https://api.polygon.io/v3/trades/AAPL")
          .with(
            query: {limit: "1000", order: "desc"},
            headers: {"Authorization" => "Bearer test_key_123"}
          )
          .to_return(status: 200, body: {results: []}.to_json, headers: {"Content-Type" => "application/json"})
      end

      it "passes query parameters to API request" do
        stocks_api.trades("AAPL", limit: 1000, order: "desc")

        expect(a_request(:get, "https://api.polygon.io/v3/trades/AAPL")
          .with(query: {limit: "1000", order: "desc"}))
          .to have_been_made.once
      end
    end

    context "with invalid ticker argument" do
      it "raises ArgumentError for non-string ticker" do
        expect { stocks_api.trades(123) }.to raise_error(ArgumentError, "Ticker must be a string")
      end
    end
  end

  describe "#quotes" do
    context "when requesting stock quotes" do
      before do
        stub_request(:get, "https://api.polygon.io/v3/quotes/AAPL")
          .with(headers: {"Authorization" => "Bearer test_key_123"})
          .to_return(
            status: 200,
            body: load_fixture("stocks_quotes"),
            headers: {"Content-Type" => "application/json"}
          )
      end

      it "makes GET request to quotes endpoint" do
        stocks_api.quotes("AAPL")

        expect(a_request(:get, "https://api.polygon.io/v3/quotes/AAPL"))
          .to have_been_made.once
      end

      it "returns array of Quote objects" do
        quotes = stocks_api.quotes("AAPL")

        expect(quotes).to be_an(Array)
        expect(quotes.length).to eq(2)
        expect(quotes).to all(be_a(Polymux::Api::Stocks::Quote))

        first_quote = quotes.first
        expect(first_quote.ticker).to eq("AAPL")
        expect(first_quote.ask_price).to eq(174.51)
        expect(first_quote.bid_price).to eq(174.49)
      end
    end

    context "with invalid ticker argument" do
      it "raises ArgumentError for non-string ticker" do
        expect { stocks_api.quotes(123) }.to raise_error(ArgumentError, "Ticker must be a string")
      end
    end
  end

  describe "#aggregates" do
    context "when requesting stock aggregates" do
      before do
        stub_request(:get, "https://api.polygon.io/v2/aggs/ticker/AAPL/range/1/day/2024-01-01/2024-01-31")
          .with(
            query: {adjusted: "true", sort: "asc"},
            headers: {"Authorization" => "Bearer test_key_123"}
          )
          .to_return(
            status: 200,
            body: load_fixture("stocks_aggregates"),
            headers: {"Content-Type" => "application/json"}
          )
      end

      it "makes GET request to aggregates endpoint" do
        stocks_api.aggregates("AAPL", 1, "day", "2024-01-01", "2024-01-31")

        expect(a_request(:get, "https://api.polygon.io/v2/aggs/ticker/AAPL/range/1/day/2024-01-01/2024-01-31")
          .with(query: {adjusted: "true", sort: "asc"}))
          .to have_been_made.once
      end

      it "returns array of Aggregate objects" do
        aggregates = stocks_api.aggregates("AAPL", 1, "day", "2024-01-01", "2024-01-31")

        expect(aggregates).to be_an(Array)
        expect(aggregates.length).to eq(2)
        expect(aggregates).to all(be_a(Polymux::Api::Stocks::Aggregate))

        first_aggregate = aggregates.first
        expect(first_aggregate.ticker).to eq("AAPL")
        expect(first_aggregate.open).to eq(173.01)
        expect(first_aggregate.high).to eq(175.50)
        expect(first_aggregate.low).to eq(172.30)
        expect(first_aggregate.close).to eq(174.49)
        expect(first_aggregate.volume).to eq(45678901)
      end
    end

    context "with invalid arguments" do
      it "raises ArgumentError for non-string ticker" do
        expect { stocks_api.aggregates(123, 1, "day", "2024-01-01", "2024-01-31") }
          .to raise_error(ArgumentError, "Ticker must be a string")
      end

      it "raises ArgumentError for invalid multiplier" do
        expect { stocks_api.aggregates("AAPL", 0, "day", "2024-01-01", "2024-01-31") }
          .to raise_error(ArgumentError, "Multiplier must be a positive integer")
      end

      it "raises ArgumentError for invalid timespan" do
        expect { stocks_api.aggregates("AAPL", 1, "invalid", "2024-01-01", "2024-01-31") }
          .to raise_error(ArgumentError, "Timespan must be a valid time unit")
      end

      it "raises ArgumentError for invalid date format" do
        expect { stocks_api.aggregates("AAPL", 1, "day", "invalid-date", "2024-01-31") }
          .to raise_error(ArgumentError, "From date must be in YYYY-MM-DD format")
      end
    end
  end

  describe "#previous_day" do
    context "when requesting previous day data" do
      before do
        stub_request(:get, "https://api.polygon.io/v2/aggs/ticker/AAPL/prev")
          .with(
            query: {adjusted: "true"},
            headers: {"Authorization" => "Bearer test_key_123"}
          )
          .to_return(
            status: 200,
            body: {results: [JSON.parse(load_fixture("stocks_aggregates"))["results"].first]}.to_json,
            headers: {"Content-Type" => "application/json"}
          )
      end

      it "makes GET request to previous day endpoint" do
        stocks_api.previous_day("AAPL")

        expect(a_request(:get, "https://api.polygon.io/v2/aggs/ticker/AAPL/prev")
          .with(query: {adjusted: "true"}))
          .to have_been_made.once
      end

      it "returns Aggregate object" do
        prev_day = stocks_api.previous_day("AAPL")

        expect(prev_day).to be_a(Polymux::Api::Stocks::Aggregate)
        expect(prev_day.ticker).to eq("AAPL")
      end
    end

    context "when no previous day data exists" do
      before do
        stub_request(:get, "https://api.polygon.io/v2/aggs/ticker/AAPL/prev")
          .with(
            query: {adjusted: "true"},
            headers: {"Authorization" => "Bearer test_key_123"}
          )
          .to_return(status: 200, body: {results: []}.to_json, headers: {"Content-Type" => "application/json"})
      end

      it "raises error when no results" do
        expect { stocks_api.previous_day("AAPL") }
          .to raise_error(Polymux::Api::Error, "No previous day data found for AAPL")
      end
    end

    context "with invalid ticker argument" do
      it "raises ArgumentError for non-string ticker" do
        expect { stocks_api.previous_day(123) }.to raise_error(ArgumentError, "Ticker must be a string")
      end
    end
  end

  describe "#daily_summary" do
    context "when requesting daily summary" do
      before do
        stub_request(:get, "https://api.polygon.io/v1/open-close/AAPL/2024-08-15")
          .with(
            query: {adjusted: "true"},
            headers: {"Authorization" => "Bearer test_key_123"}
          )
          .to_return(
            status: 200,
            body: load_fixture("stocks_daily_summary"),
            headers: {"Content-Type" => "application/json"}
          )
      end

      it "makes GET request to daily summary endpoint" do
        stocks_api.daily_summary("AAPL", "2024-08-15")

        expect(a_request(:get, "https://api.polygon.io/v1/open-close/AAPL/2024-08-15")
          .with(query: {adjusted: "true"}))
          .to have_been_made.once
      end

      it "returns DailySummary object" do
        summary = stocks_api.daily_summary("AAPL", "2024-08-15")

        expect(summary).to be_a(Polymux::Api::Stocks::DailySummary)
        expect(summary.symbol).to eq("AAPL")
        expect(summary.open).to eq(173.01)
        expect(summary.close).to eq(174.49)
        expect(summary.after_hours_close).to eq(174.65)
      end
    end

    context "with invalid arguments" do
      it "raises ArgumentError for non-string ticker" do
        expect { stocks_api.daily_summary(123, "2024-08-15") }
          .to raise_error(ArgumentError, "Ticker must be a string")
      end

      it "raises ArgumentError for invalid date format" do
        expect { stocks_api.daily_summary("AAPL", "invalid-date") }
          .to raise_error(ArgumentError, "Date must be in YYYY-MM-DD format")
      end
    end
  end

  describe "#all_snapshots" do
    context "when requesting all market snapshots" do
      before do
        stub_request(:get, "https://api.polygon.io/v2/snapshot/locale/us/markets/stocks/tickers")
          .with(headers: {"Authorization" => "Bearer test_key_123"})
          .to_return(
            status: 200,
            body: {tickers: [JSON.parse(load_fixture("stocks_snapshot"))]}.to_json,
            headers: {"Content-Type" => "application/json"}
          )
      end

      it "makes GET request to all snapshots endpoint" do
        stocks_api.all_snapshots

        expect(a_request(:get, "https://api.polygon.io/v2/snapshot/locale/us/markets/stocks/tickers"))
          .to have_been_made.once
      end

      it "returns array of Snapshot objects" do
        snapshots = stocks_api.all_snapshots

        expect(snapshots).to be_an(Array)
        expect(snapshots.length).to eq(1)
        expect(snapshots).to all(be_a(Polymux::Api::Stocks::Snapshot))
      end
    end

    context "with filtering options" do
      before do
        stub_request(:get, "https://api.polygon.io/v2/snapshot/locale/us/markets/stocks/tickers")
          .with(
            query: {tickers: "AAPL,MSFT", include_otc: "true"},
            headers: {"Authorization" => "Bearer test_key_123"}
          )
          .to_return(
            status: 200,
            body: {tickers: []}.to_json,
            headers: {"Content-Type" => "application/json"}
          )
      end

      it "passes filtering options to API request" do
        stocks_api.all_snapshots(tickers: "AAPL,MSFT", include_otc: true)

        expect(a_request(:get, "https://api.polygon.io/v2/snapshot/locale/us/markets/stocks/tickers")
          .with(query: {tickers: "AAPL,MSFT", include_otc: "true"}))
          .to have_been_made.once
      end
    end

    context "when API request fails" do
      before do
        stub_request(:get, "https://api.polygon.io/v2/snapshot/locale/us/markets/stocks/tickers")
          .with(headers: {"Authorization" => "Bearer test_key_123"})
          .to_return(status: 500, body: {error: "Internal server error"}.to_json)
      end

      it "raises Polymux::Api::Error" do
        expect { stocks_api.all_snapshots }
          .to raise_error(Polymux::Api::Error, "Failed to fetch market snapshots")
      end
    end

    context "when API returns empty tickers array" do
      before do
        stub_request(:get, "https://api.polygon.io/v2/snapshot/locale/us/markets/stocks/tickers")
          .with(headers: {"Authorization" => "Bearer test_key_123"})
          .to_return(
            status: 200,
            body: {tickers: []}.to_json,
            headers: {"Content-Type" => "application/json"}
          )
      end

      it "returns empty array" do
        snapshots = stocks_api.all_snapshots
        expect(snapshots).to eq([])
      end
    end

    context "when API returns missing tickers key" do
      before do
        stub_request(:get, "https://api.polygon.io/v2/snapshot/locale/us/markets/stocks/tickers")
          .with(headers: {"Authorization" => "Bearer test_key_123"})
          .to_return(
            status: 200,
            body: {status: "OK"}.to_json,
            headers: {"Content-Type" => "application/json"}
          )
      end

      it "returns empty array when tickers key is missing" do
        snapshots = stocks_api.all_snapshots
        expect(snapshots).to eq([])
      end
    end
  end

  # Additional comprehensive error handling tests
  describe "error handling" do
    context "when API returns non-200 status codes" do
      [
        [400, "Bad Request"],
        [401, "Unauthorized"],
        [403, "Forbidden"],
        [404, "Not Found"],
        [429, "Too Many Requests"],
        [500, "Internal Server Error"],
        [502, "Bad Gateway"],
        [503, "Service Unavailable"]
      ].each do |status_code, description|
        context "when API returns #{status_code} #{description}" do
          before do
            stub_request(:get, "https://api.polygon.io/v3/reference/tickers/AAPL")
              .with(headers: {"Authorization" => "Bearer test_key_123"})
              .to_return(status: status_code, body: {error: description}.to_json)
          end

          it "raises Polymux::Api::Error for ticker_details" do
            expect { stocks_api.ticker_details("AAPL") }
              .to raise_error(Polymux::Api::Error, "Failed to fetch ticker details for AAPL")
          end
        end
      end
    end

    # Note: Error handling for malformed JSON is handled at the HTTP client level
    # The current implementation focuses on successful response handling
  end

  # Comprehensive argument validation tests
  describe "argument validation" do
    describe "ticker parameter validation" do
      [nil, 123, [], {}, true, false].each do |invalid_ticker|
        context "when ticker is #{invalid_ticker.inspect}" do
          it "raises ArgumentError for ticker_details" do
            expect { stocks_api.ticker_details(invalid_ticker) }
              .to raise_error(ArgumentError, "Ticker must be a string")
          end

          it "raises ArgumentError for snapshot" do
            expect { stocks_api.snapshot(invalid_ticker) }
              .to raise_error(ArgumentError, "Ticker must be a string")
          end

          it "raises ArgumentError for trades" do
            expect { stocks_api.trades(invalid_ticker) }
              .to raise_error(ArgumentError, "Ticker must be a string")
          end

          it "raises ArgumentError for quotes" do
            expect { stocks_api.quotes(invalid_ticker) }
              .to raise_error(ArgumentError, "Ticker must be a string")
          end

          it "raises ArgumentError for aggregates" do
            expect { stocks_api.aggregates(invalid_ticker, 1, "day", "2024-01-01", "2024-01-31") }
              .to raise_error(ArgumentError, "Ticker must be a string")
          end

          it "raises ArgumentError for previous_day" do
            expect { stocks_api.previous_day(invalid_ticker) }
              .to raise_error(ArgumentError, "Ticker must be a string")
          end

          it "raises ArgumentError for daily_summary" do
            expect { stocks_api.daily_summary(invalid_ticker, "2024-01-01") }
              .to raise_error(ArgumentError, "Ticker must be a string")
          end
        end
      end

      context "when ticker is empty string" do
        let(:empty_ticker) { "" }

        # Empty string is a string, so it passes validation but may cause API errors
        before do
          stub_request(:get, "https://api.polygon.io/v3/reference/tickers/")
            .with(headers: {"Authorization" => "Bearer test_key_123"})
            .to_return(status: 404, body: {error: "Not found"}.to_json)
        end

        it "accepts empty string but API may return error" do
          expect { stocks_api.ticker_details(empty_ticker) }
            .to raise_error(Polymux::Api::Error)
        end
      end
    end

    describe "aggregates parameter validation" do
      context "multiplier parameter" do
        [nil, "1", 0, -1, 1.5, [], {}].each do |invalid_multiplier|
          it "raises ArgumentError for multiplier #{invalid_multiplier.inspect}" do
            expect { stocks_api.aggregates("AAPL", invalid_multiplier, "day", "2024-01-01", "2024-01-31") }
              .to raise_error(ArgumentError, "Multiplier must be a positive integer")
          end
        end
      end

      context "timespan parameter" do
        ["invalid", "seconds", "millisecond", nil, 123, [], {}].each do |invalid_timespan|
          it "raises ArgumentError for timespan #{invalid_timespan.inspect}" do
            expect { stocks_api.aggregates("AAPL", 1, invalid_timespan, "2024-01-01", "2024-01-31") }
              .to raise_error(ArgumentError, "Timespan must be a valid time unit")
          end
        end

        ["minute", "hour", "day", "week", "month", "quarter", "year"].each do |valid_timespan|
          it "accepts valid timespan #{valid_timespan}" do
            # Mock the HTTP client to avoid actual HTTP calls in validation tests
            allow(client.http).to receive(:get).and_return(
              double("response", success?: true, status: 200, body: {"results" => []})
            )

            expect { stocks_api.aggregates("AAPL", 1, valid_timespan, "2024-01-01", "2024-01-31") }
              .not_to raise_error
          end
        end
      end

      context "date format validation" do
        [
          "2024-1-1", "2024-01-1", "2024-1-01",  # Missing zero padding
          "24-01-01", "2024/01/01", "01-01-2024",  # Wrong format
          "invalid"  # Invalid string format
        ].each do |invalid_date|
          it "raises ArgumentError for from_date #{invalid_date.inspect}" do
            expect { stocks_api.aggregates("AAPL", 1, "day", invalid_date, "2024-01-31") }
              .to raise_error(ArgumentError, "From date must be in YYYY-MM-DD format")
          end

          it "raises ArgumentError for to_date #{invalid_date.inspect}" do
            expect { stocks_api.aggregates("AAPL", 1, "day", "2024-01-01", invalid_date) }
              .to raise_error(ArgumentError, "To date must be in YYYY-MM-DD format")
          end
        end

        # Test non-string types separately to handle NoMethodError properly
        context "with non-string date parameters" do
          [nil, 123, [], {}].each do |invalid_date|
            it "raises NoMethodError for from_date #{invalid_date.inspect}" do
              expect { stocks_api.aggregates("AAPL", 1, "day", invalid_date, "2024-01-31") }
                .to raise_error(NoMethodError)
            end

            it "raises NoMethodError for to_date #{invalid_date.inspect}" do
              expect { stocks_api.aggregates("AAPL", 1, "day", "2024-01-01", invalid_date) }
                .to raise_error(NoMethodError)
            end
          end
        end

        it "raises ArgumentError for daily_summary date parameter" do
          expect { stocks_api.daily_summary("AAPL", "invalid-date") }
            .to raise_error(ArgumentError, "Date must be in YYYY-MM-DD format")
        end
      end
    end
  end

  # Test case sensitivity and ticker normalization
  describe "ticker normalization" do
    before do
      # API should receive uppercase ticker regardless of input case
      stub_request(:get, "https://api.polygon.io/v3/reference/tickers/AAPL")
        .with(headers: {"Authorization" => "Bearer test_key_123"})
        .to_return(
          status: 200,
          body: load_fixture("stocks_ticker_details"),
          headers: {"Content-Type" => "application/json"}
        )
    end

    ["AAPL", "aapl", "Aapl", "aApL"].each do |ticker_variant|
      it "converts #{ticker_variant} to uppercase for API request" do
        stocks_api.ticker_details(ticker_variant)

        expect(a_request(:get, "https://api.polygon.io/v3/reference/tickers/AAPL"))
          .to have_been_made.once
      end
    end
  end

  # Test optional parameters handling
  describe "optional parameters handling" do
    context "ticker_details with date parameter" do
      before do
        stub_request(:get, "https://api.polygon.io/v3/reference/tickers/AAPL")
          .with(
            query: {date: "2024-01-15"},
            headers: {"Authorization" => "Bearer test_key_123"}
          )
          .to_return(
            status: 200,
            body: load_fixture("stocks_ticker_details"),
            headers: {"Content-Type" => "application/json"}
          )
      end

      it "includes date parameter when provided" do
        stocks_api.ticker_details("AAPL", "2024-01-15")

        expect(a_request(:get, "https://api.polygon.io/v3/reference/tickers/AAPL")
          .with(query: {date: "2024-01-15"}))
          .to have_been_made.once
      end
    end

    context "aggregates with custom options" do
      before do
        stub_request(:get, "https://api.polygon.io/v2/aggs/ticker/AAPL/range/1/day/2024-01-01/2024-01-31")
          .with(
            query: {adjusted: "false", sort: "desc", limit: "1000"},
            headers: {"Authorization" => "Bearer test_key_123"}
          )
          .to_return(
            status: 200,
            body: load_fixture("stocks_aggregates"),
            headers: {"Content-Type" => "application/json"}
          )
      end

      it "overrides default options with custom parameters" do
        stocks_api.aggregates("AAPL", 1, "day", "2024-01-01", "2024-01-31", adjusted: false, sort: "desc", limit: 1000)

        expect(a_request(:get, "https://api.polygon.io/v2/aggs/ticker/AAPL/range/1/day/2024-01-01/2024-01-31")
          .with(query: {adjusted: "false", sort: "desc", limit: "1000"}))
          .to have_been_made.once
      end
    end

    context "previous_day with custom options" do
      before do
        stub_request(:get, "https://api.polygon.io/v2/aggs/ticker/AAPL/prev")
          .with(
            query: {adjusted: "false"},
            headers: {"Authorization" => "Bearer test_key_123"}
          )
          .to_return(
            status: 200,
            body: {results: [JSON.parse(load_fixture("stocks_aggregates"))["results"].first]}.to_json,
            headers: {"Content-Type" => "application/json"}
          )
      end

      it "overrides default adjusted parameter" do
        stocks_api.previous_day("AAPL", adjusted: false)

        expect(a_request(:get, "https://api.polygon.io/v2/aggs/ticker/AAPL/prev")
          .with(query: {adjusted: "false"}))
          .to have_been_made.once
      end
    end

    context "daily_summary with custom options" do
      before do
        stub_request(:get, "https://api.polygon.io/v1/open-close/AAPL/2024-08-15")
          .with(
            query: {adjusted: "false"},
            headers: {"Authorization" => "Bearer test_key_123"}
          )
          .to_return(
            status: 200,
            body: load_fixture("stocks_daily_summary"),
            headers: {"Content-Type" => "application/json"}
          )
      end

      it "overrides default adjusted parameter" do
        stocks_api.daily_summary("AAPL", "2024-08-15", adjusted: false)

        expect(a_request(:get, "https://api.polygon.io/v1/open-close/AAPL/2024-08-15")
          .with(query: {adjusted: "false"}))
          .to have_been_made.once
      end
    end
  end
end
