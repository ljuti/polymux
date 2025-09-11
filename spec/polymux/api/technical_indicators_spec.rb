# frozen_string_literal: true

require "spec_helper"

RSpec.describe Polymux::Api::TechnicalIndicators do
  let(:config) { Polymux::Config.new(api_key: "test_key_123", base_url: "https://api.polygon.io") }
  let(:client) { Polymux::Client.new(config) }
  let(:indicators_api) { described_class.new(client) }

  describe "inheritance" do
    it "inherits from PolymuxRestHandler" do
      expect(described_class.superclass).to eq(Polymux::Client::PolymuxRestHandler)
    end

    it "has access to the parent client" do
      expect(indicators_api.send(:_client)).to eq(client)
    end
  end

  describe "#sma" do
    let(:valid_sma_response) do
      {
        results: {
          underlying: {ticker: "AAPL"},
          values: [
            {timestamp: 1704067200000, value: 180.50},
            {timestamp: 1704153600000, value: 181.75},
            {timestamp: 1704240000000, value: 183.20}
          ]
        },
        status: "OK"
      }.to_json
    end

    context "with valid parameters" do
      before do
        stub_request(:get, "https://api.polygon.io/v1/indicators/sma/AAPL")
          .with(
            query: {
              "window" => "20",
              "timespan" => "day",
              "adjusted" => "true",
              "series_type" => "close",
              "limit" => "5000"
            },
            headers: {"Authorization" => "Bearer test_key_123"}
          )
          .to_return(
            status: 200,
            body: valid_sma_response,
            headers: {"Content-Type" => "application/json"}
          )
      end

      it "makes GET request to SMA endpoint" do
        indicators_api.sma("AAPL", window: 20, timespan: "day")

        expect(a_request(:get, "https://api.polygon.io/v1/indicators/sma/AAPL")
          .with(query: {
            "window" => "20",
            "timespan" => "day",
            "adjusted" => "true",
            "series_type" => "close",
            "limit" => "5000"
          })).to have_been_made.once
      end

      it "returns an SMA object" do
        result = indicators_api.sma("AAPL", window: 20, timespan: "day")

        expect(result).to be_a(Polymux::Api::TechnicalIndicators::SMA)
      end

      it "transforms API data correctly" do
        result = indicators_api.sma("AAPL", window: 20, timespan: "day")

        expect(result.ticker).to eq("AAPL")
        expect(result.values.length).to eq(3)
        expect(result.values.first.value).to eq(180.50)
      end

      it "converts ticker to uppercase" do
        stub_request(:get, "https://api.polygon.io/v1/indicators/sma/AAPL")
          .with(
            query: {
              "window" => "20",
              "timespan" => "day",
              "adjusted" => "true",
              "series_type" => "close",
              "limit" => "5000"
            }
          )
          .to_return(status: 200, body: valid_sma_response)

        indicators_api.sma("aapl", window: 20, timespan: "day")

        expect(a_request(:get, "https://api.polygon.io/v1/indicators/sma/AAPL")
          .with(query: {
            "window" => "20",
            "timespan" => "day",
            "adjusted" => "true",
            "series_type" => "close",
            "limit" => "5000"
          })).to have_been_made.once
      end
    end

    context "with additional options" do
      before do
        stub_request(:get, "https://api.polygon.io/v1/indicators/sma/AAPL")
          .with(
            query: {
              "window" => "50",
              "timespan" => "hour",
              "series_type" => "open",
              "adjusted" => "false",
              "limit" => "1000",
              "order" => "desc",
              "timestamp.gte" => "2024-01-01",
              "timestamp.lte" => "2024-12-31"
            }
          )
          .to_return(status: 200, body: valid_sma_response)
      end

      it "passes all options to the API request" do
        indicators_api.sma("AAPL",
          window: 50,
          timespan: "hour",
          series_type: "open",
          adjusted: false,
          limit: 1000,
          order: "desc",
          timestamp_gte: "2024-01-01",
          timestamp_lte: "2024-12-31")

        expect(a_request(:get, "https://api.polygon.io/v1/indicators/sma/AAPL")
          .with(query: {
            "window" => "50",
            "timespan" => "hour",
            "series_type" => "open",
            "adjusted" => "false",
            "limit" => "1000",
            "order" => "desc",
            "timestamp.gte" => "2024-01-01",
            "timestamp.lte" => "2024-12-31"
          })).to have_been_made.once
      end
    end

    context "parameter validation" do
      it "raises ArgumentError for non-string ticker" do
        expect {
          indicators_api.sma(123, window: 20, timespan: "day")
        }.to raise_error(ArgumentError, "Ticker must be a string")

        expect {
          indicators_api.sma(nil, window: 20, timespan: "day")
        }.to raise_error(ArgumentError, "Ticker must be a string")

        expect {
          indicators_api.sma([], window: 20, timespan: "day")
        }.to raise_error(ArgumentError, "Ticker must be a string")
      end

      it "raises ArgumentError for invalid window" do
        expect {
          indicators_api.sma("AAPL", window: "20", timespan: "day")
        }.to raise_error(ArgumentError, "Window must be a positive integer")

        expect {
          indicators_api.sma("AAPL", window: 0, timespan: "day")
        }.to raise_error(ArgumentError, "Window must be a positive integer")

        expect {
          indicators_api.sma("AAPL", window: -5, timespan: "day")
        }.to raise_error(ArgumentError, "Window must be a positive integer")

        expect {
          indicators_api.sma("AAPL", window: nil, timespan: "day")
        }.to raise_error(ArgumentError, "Window must be a positive integer")
      end

      it "raises ArgumentError for invalid timespan" do
        expect {
          indicators_api.sma("AAPL", window: 20, timespan: "invalid")
        }.to raise_error(ArgumentError, "Timespan must be a valid time unit")

        expect {
          indicators_api.sma("AAPL", window: 20, timespan: "daily")
        }.to raise_error(ArgumentError, "Timespan must be a valid time unit")

        expect {
          indicators_api.sma("AAPL", window: 20, timespan: nil)
        }.to raise_error(ArgumentError, "Timespan must be a valid time unit")
      end

      it "accepts all valid timespans" do
        %w[minute hour day week month].each do |timespan|
          stub_request(:get, "https://api.polygon.io/v1/indicators/sma/AAPL")
            .with(query: hash_including("timespan" => timespan))
            .to_return(status: 200, body: valid_sma_response)

          expect {
            indicators_api.sma("AAPL", window: 20, timespan: timespan)
          }.not_to raise_error
        end
      end
    end

    context "error handling" do
      it "raises Polymux::Api::Error on failed HTTP request" do
        stub_request(:get, "https://api.polygon.io/v1/indicators/sma/AAPL")
          .with(query: hash_including({}))
          .to_return(status: 404)

        expect {
          indicators_api.sma("AAPL", window: 20, timespan: "day")
        }.to raise_error(Polymux::Api::Error, "Failed to fetch SMA for AAPL")
      end

      it "raises Polymux::Api::Error on 500 error" do
        stub_request(:get, "https://api.polygon.io/v1/indicators/sma/AAPL")
          .with(query: hash_including({}))
          .to_return(status: 500)

        expect {
          indicators_api.sma("AAPL", window: 20, timespan: "day")
        }.to raise_error(Polymux::Api::Error, "Failed to fetch SMA for AAPL")
      end

      it "raises Faraday::ConnectionFailed on network timeout" do
        stub_request(:get, "https://api.polygon.io/v1/indicators/sma/AAPL")
          .with(query: hash_including({}))
          .to_timeout

        expect {
          indicators_api.sma("AAPL", window: 20, timespan: "day")
        }.to raise_error(Faraday::ConnectionFailed)
      end
    end
  end

  describe "#ema" do
    let(:valid_ema_response) do
      {
        results: {
          underlying: {ticker: "AAPL"},
          values: [
            {timestamp: 1704067200000, value: 179.85},
            {timestamp: 1704153600000, value: 181.20},
            {timestamp: 1704240000000, value: 183.45}
          ]
        },
        status: "OK"
      }.to_json
    end

    context "with valid parameters" do
      before do
        stub_request(:get, "https://api.polygon.io/v1/indicators/ema/AAPL")
          .with(
            query: {
              "window" => "12",
              "timespan" => "day",
              "adjusted" => "true",
              "series_type" => "close",
              "limit" => "5000"
            },
            headers: {"Authorization" => "Bearer test_key_123"}
          )
          .to_return(
            status: 200,
            body: valid_ema_response,
            headers: {"Content-Type" => "application/json"}
          )
      end

      it "makes GET request to EMA endpoint" do
        indicators_api.ema("AAPL", window: 12, timespan: "day")

        expect(a_request(:get, "https://api.polygon.io/v1/indicators/ema/AAPL")
          .with(query: {
            "window" => "12",
            "timespan" => "day",
            "adjusted" => "true",
            "series_type" => "close",
            "limit" => "5000"
          })).to have_been_made.once
      end

      it "returns an EMA object" do
        result = indicators_api.ema("AAPL", window: 12, timespan: "day")

        expect(result).to be_a(Polymux::Api::TechnicalIndicators::EMA)
      end

      it "transforms API data correctly" do
        result = indicators_api.ema("AAPL", window: 12, timespan: "day")

        expect(result.ticker).to eq("AAPL")
        expect(result.values.length).to eq(3)
        expect(result.values.first.value).to eq(179.85)
      end
    end

    context "parameter validation" do
      it "raises ArgumentError for non-string ticker" do
        expect {
          indicators_api.ema(123, window: 12, timespan: "day")
        }.to raise_error(ArgumentError, "Ticker must be a string")
      end

      it "raises ArgumentError for invalid window" do
        expect {
          indicators_api.ema("AAPL", window: 0, timespan: "day")
        }.to raise_error(ArgumentError, "Window must be a positive integer")
      end

      it "raises ArgumentError for invalid timespan" do
        expect {
          indicators_api.ema("AAPL", window: 12, timespan: "invalid")
        }.to raise_error(ArgumentError, "Timespan must be a valid time unit")
      end
    end

    context "error handling" do
      it "raises Polymux::Api::Error on failed HTTP request" do
        stub_request(:get, "https://api.polygon.io/v1/indicators/ema/AAPL")
          .with(query: hash_including({}))
          .to_return(status: 404)

        expect {
          indicators_api.ema("AAPL", window: 12, timespan: "day")
        }.to raise_error(Polymux::Api::Error, "Failed to fetch EMA for AAPL")
      end
    end
  end

  describe "#rsi" do
    let(:valid_rsi_response) do
      {
        results: {
          underlying: {ticker: "AAPL"},
          values: [
            {timestamp: 1704067200000, value: 45.0},
            {timestamp: 1704153600000, value: 52.8},
            {timestamp: 1704240000000, value: 68.5}
          ]
        },
        status: "OK"
      }.to_json
    end

    context "with valid parameters" do
      before do
        stub_request(:get, "https://api.polygon.io/v1/indicators/rsi/AAPL")
          .with(
            query: {
              "window" => "14",
              "timespan" => "day",
              "adjusted" => "true",
              "series_type" => "close",
              "limit" => "5000"
            },
            headers: {"Authorization" => "Bearer test_key_123"}
          )
          .to_return(
            status: 200,
            body: valid_rsi_response,
            headers: {"Content-Type" => "application/json"}
          )
      end

      it "makes GET request to RSI endpoint" do
        indicators_api.rsi("AAPL", window: 14, timespan: "day")

        expect(a_request(:get, "https://api.polygon.io/v1/indicators/rsi/AAPL")
          .with(query: {
            "window" => "14",
            "timespan" => "day",
            "adjusted" => "true",
            "series_type" => "close",
            "limit" => "5000"
          })).to have_been_made.once
      end

      it "returns an RSI object" do
        result = indicators_api.rsi("AAPL", window: 14, timespan: "day")

        expect(result).to be_a(Polymux::Api::TechnicalIndicators::RSI)
      end

      it "transforms API data correctly" do
        result = indicators_api.rsi("AAPL", window: 14, timespan: "day")

        expect(result.ticker).to eq("AAPL")
        expect(result.values.length).to eq(3)
        expect(result.values.first.value).to eq(45.0)
      end
    end

    context "parameter validation" do
      it "raises ArgumentError for non-string ticker" do
        expect {
          indicators_api.rsi(123, window: 14, timespan: "day")
        }.to raise_error(ArgumentError, "Ticker must be a string")
      end

      it "raises ArgumentError for invalid window" do
        expect {
          indicators_api.rsi("AAPL", window: -1, timespan: "day")
        }.to raise_error(ArgumentError, "Window must be a positive integer")

        expect {
          indicators_api.rsi("AAPL", window: 0, timespan: "day")
        }.to raise_error(ArgumentError, "Window must be a positive integer")

        expect {
          indicators_api.rsi("AAPL", window: "invalid", timespan: "day")
        }.to raise_error(ArgumentError, "Window must be a positive integer")
      end

      it "raises ArgumentError for invalid timespan" do
        expect {
          indicators_api.rsi("AAPL", window: 14, timespan: "invalid")
        }.to raise_error(ArgumentError, "Timespan must be a valid time unit")
      end
    end

    context "error handling" do
      it "raises Polymux::Api::Error on failed HTTP request" do
        stub_request(:get, "https://api.polygon.io/v1/indicators/rsi/AAPL")
          .with(query: hash_including({}))
          .to_return(status: 401)

        expect {
          indicators_api.rsi("AAPL", window: 14, timespan: "day")
        }.to raise_error(Polymux::Api::Error, "Failed to fetch RSI for AAPL")
      end
    end
  end

  describe "#macd" do
    let(:valid_macd_response) do
      {
        results: {
          underlying: {ticker: "AAPL"},
          values: [
            {timestamp: 1704067200000, value: -1.25, signal: -0.85, histogram: -0.40},
            {timestamp: 1704153600000, value: -0.75, signal: -0.95, histogram: 0.20},
            {timestamp: 1704240000000, value: 0.45, signal: -0.35, histogram: 0.80}
          ]
        },
        status: "OK"
      }.to_json
    end

    context "with valid parameters" do
      before do
        stub_request(:get, "https://api.polygon.io/v1/indicators/macd/AAPL")
          .with(
            query: {
              "short_window" => "12",
              "long_window" => "26",
              "signal_window" => "9",
              "timespan" => "day",
              "adjusted" => "true",
              "series_type" => "close",
              "limit" => "5000"
            },
            headers: {"Authorization" => "Bearer test_key_123"}
          )
          .to_return(
            status: 200,
            body: valid_macd_response,
            headers: {"Content-Type" => "application/json"}
          )
      end

      it "makes GET request to MACD endpoint" do
        indicators_api.macd("AAPL", short_window: 12, long_window: 26, signal_window: 9, timespan: "day")

        expect(a_request(:get, "https://api.polygon.io/v1/indicators/macd/AAPL")
          .with(query: {
            "short_window" => "12",
            "long_window" => "26",
            "signal_window" => "9",
            "timespan" => "day",
            "adjusted" => "true",
            "series_type" => "close",
            "limit" => "5000"
          })).to have_been_made.once
      end

      it "returns a MACD object" do
        result = indicators_api.macd("AAPL", short_window: 12, long_window: 26, signal_window: 9, timespan: "day")

        expect(result).to be_a(Polymux::Api::TechnicalIndicators::MACD)
      end

      it "transforms API data correctly" do
        result = indicators_api.macd("AAPL", short_window: 12, long_window: 26, signal_window: 9, timespan: "day")

        expect(result.ticker).to eq("AAPL")
        expect(result.values.length).to eq(3)
        expect(result.values.first.value).to eq(-1.25)
      end
    end

    context "parameter validation" do
      it "raises ArgumentError for non-string ticker" do
        expect {
          indicators_api.macd(123, short_window: 12, long_window: 26, signal_window: 9, timespan: "day")
        }.to raise_error(ArgumentError, "Ticker must be a string")
      end

      it "raises ArgumentError for invalid short_window" do
        expect {
          indicators_api.macd("AAPL", short_window: 0, long_window: 26, signal_window: 9, timespan: "day")
        }.to raise_error(ArgumentError, "Short window must be a positive integer")

        expect {
          indicators_api.macd("AAPL", short_window: -1, long_window: 26, signal_window: 9, timespan: "day")
        }.to raise_error(ArgumentError, "Short window must be a positive integer")

        expect {
          indicators_api.macd("AAPL", short_window: "invalid", long_window: 26, signal_window: 9, timespan: "day")
        }.to raise_error(ArgumentError, "Short window must be a positive integer")
      end

      it "raises ArgumentError for invalid long_window" do
        expect {
          indicators_api.macd("AAPL", short_window: 12, long_window: 0, signal_window: 9, timespan: "day")
        }.to raise_error(ArgumentError, "Long window must be a positive integer")

        expect {
          indicators_api.macd("AAPL", short_window: 12, long_window: -5, signal_window: 9, timespan: "day")
        }.to raise_error(ArgumentError, "Long window must be a positive integer")
      end

      it "raises ArgumentError for invalid signal_window" do
        expect {
          indicators_api.macd("AAPL", short_window: 12, long_window: 26, signal_window: 0, timespan: "day")
        }.to raise_error(ArgumentError, "Signal window must be a positive integer")

        expect {
          indicators_api.macd("AAPL", short_window: 12, long_window: 26, signal_window: nil, timespan: "day")
        }.to raise_error(ArgumentError, "Signal window must be a positive integer")
      end

      it "raises ArgumentError when short_window is greater than or equal to long_window" do
        expect {
          indicators_api.macd("AAPL", short_window: 26, long_window: 12, signal_window: 9, timespan: "day")
        }.to raise_error(ArgumentError, "Short window must be less than long window")

        expect {
          indicators_api.macd("AAPL", short_window: 26, long_window: 26, signal_window: 9, timespan: "day")
        }.to raise_error(ArgumentError, "Short window must be less than long window")
      end

      it "raises ArgumentError for invalid timespan" do
        expect {
          indicators_api.macd("AAPL", short_window: 12, long_window: 26, signal_window: 9, timespan: "invalid")
        }.to raise_error(ArgumentError, "Timespan must be a valid time unit")
      end
    end

    context "error handling" do
      it "raises Polymux::Api::Error on failed HTTP request" do
        stub_request(:get, "https://api.polygon.io/v1/indicators/macd/AAPL")
          .with(query: hash_including({}))
          .to_return(status: 500)

        expect {
          indicators_api.macd("AAPL", short_window: 12, long_window: 26, signal_window: 9, timespan: "day")
        }.to raise_error(Polymux::Api::Error, "Failed to fetch MACD for AAPL")
      end
    end
  end

  describe "build_indicator_params (private method)" do
    # Test the private method through the public interface
    context "parameter building behavior" do
      before do
        stub_request(:get, "https://api.polygon.io/v1/indicators/sma/AAPL")
          .with(query: hash_including({}))
          .to_return(status: 200, body: {results: {values: []}, status: "OK"}.to_json)
      end

      it "sets default parameters" do
        indicators_api.sma("AAPL", window: 20, timespan: "day")

        expect(a_request(:get, "https://api.polygon.io/v1/indicators/sma/AAPL")
          .with(query: hash_including({
            "window" => "20",
            "timespan" => "day",
            "adjusted" => "true",
            "series_type" => "close",
            "limit" => "5000"
          }))).to have_been_made.once
      end

      it "handles timestamp parameters correctly" do
        indicators_api.sma("AAPL",
          window: 20,
          timespan: "day",
          timestamp_gte: "2024-01-01",
          timestamp_lte: "2024-12-31")

        expect(a_request(:get, "https://api.polygon.io/v1/indicators/sma/AAPL")
          .with(query: hash_including({
            "window" => "20",
            "timespan" => "day",
            "timestamp.gte" => "2024-01-01",
            "timestamp.lte" => "2024-12-31"
          }))).to have_been_made.once
      end

      it "overrides default parameters with provided options" do
        indicators_api.sma("AAPL",
          window: 20,
          timespan: "day",
          series_type: "open",
          adjusted: false,
          limit: 100,
          order: "desc")

        expect(a_request(:get, "https://api.polygon.io/v1/indicators/sma/AAPL")
          .with(query: hash_including({
            "window" => "20",
            "timespan" => "day",
            "series_type" => "open",
            "adjusted" => "false",
            "limit" => "100",
            "order" => "desc"
          }))).to have_been_made.once
      end

      it "handles MACD-specific parameters" do
        stub_request(:get, "https://api.polygon.io/v1/indicators/macd/AAPL")
          .with(query: hash_including({}))
          .to_return(status: 200, body: {results: {values: []}, status: "OK"}.to_json)

        indicators_api.macd("AAPL",
          short_window: 12,
          long_window: 26,
          signal_window: 9,
          timespan: "day")

        expect(a_request(:get, "https://api.polygon.io/v1/indicators/macd/AAPL")
          .with(query: hash_including({
            "short_window" => "12",
            "long_window" => "26",
            "signal_window" => "9",
            "timespan" => "day"
          }))).to have_been_made.once
      end

      it "does not include nil timestamp parameters" do
        indicators_api.sma("AAPL", window: 20, timespan: "day", timestamp_gte: nil)

        expect(a_request(:get, "https://api.polygon.io/v1/indicators/sma/AAPL")
          .with(query: hash_including(
            "window" => "20",
            "timespan" => "day"
          ))).to have_been_made.once
      end
    end
  end

  describe "edge cases and boundary conditions" do
    context "empty responses" do
      let(:empty_response) do
        {results: {values: []}, status: "OK"}.to_json
      end

      it "handles empty SMA response" do
        stub_request(:get, "https://api.polygon.io/v1/indicators/sma/AAPL")
          .with(query: hash_including({}))
          .to_return(status: 200, body: empty_response)

        result = indicators_api.sma("AAPL", window: 20, timespan: "day")
        expect(result.values).to be_empty
      end
    end

    context "minimum valid parameters" do
      let(:minimal_response) do
        {
          results: {
            underlying: {ticker: "A"},
            values: [{timestamp: 1704067200000, value: 1.0}]
          },
          status: "OK"
        }.to_json
      end

      it "works with minimum window value" do
        stub_request(:get, "https://api.polygon.io/v1/indicators/sma/A")
          .with(query: hash_including({}))
          .to_return(status: 200, body: minimal_response)

        expect {
          indicators_api.sma("A", window: 1, timespan: "minute")
        }.not_to raise_error
      end

      it "works with single character ticker" do
        stub_request(:get, "https://api.polygon.io/v1/indicators/sma/A")
          .with(query: hash_including({}))
          .to_return(status: 200, body: minimal_response)

        result = indicators_api.sma("A", window: 20, timespan: "day")
        expect(result.ticker).to eq("A")
      end
    end

    context "large parameter values" do
      let(:large_response) do
        {results: {values: []}, status: "OK"}.to_json
      end

      it "handles large window values" do
        stub_request(:get, "https://api.polygon.io/v1/indicators/sma/AAPL")
          .with(query: hash_including({}))
          .to_return(status: 200, body: large_response)

        expect {
          indicators_api.sma("AAPL", window: 1000, timespan: "day")
        }.not_to raise_error
      end

      it "handles large MACD window values" do
        stub_request(:get, "https://api.polygon.io/v1/indicators/macd/AAPL")
          .with(query: hash_including({}))
          .to_return(status: 200, body: large_response)

        expect {
          indicators_api.macd("AAPL", short_window: 100, long_window: 200, signal_window: 50, timespan: "day")
        }.not_to raise_error
      end
    end

    context "special characters in ticker" do
      let(:special_ticker_response) do
        {
          results: {
            underlying: {ticker: "BRK.A"},
            values: [{timestamp: 1704067200000, value: 500000.0}]
          },
          status: "OK"
        }.to_json
      end

      it "handles tickers with periods" do
        stub_request(:get, "https://api.polygon.io/v1/indicators/sma/BRK.A")
          .with(query: hash_including({}))
          .to_return(status: 200, body: special_ticker_response)

        result = indicators_api.sma("brk.a", window: 20, timespan: "day")
        expect(result.ticker).to eq("BRK.A")
      end
    end

    context "HTTP response edge cases" do
      it "handles response with missing results" do
        stub_request(:get, "https://api.polygon.io/v1/indicators/sma/AAPL")
          .with(query: hash_including({}))
          .to_return(status: 200, body: '{"status": "OK"}')

        result = indicators_api.sma("AAPL", window: 20, timespan: "day")
        expect(result.values).to be_empty
      end

      it "handles malformed JSON gracefully" do
        stub_request(:get, "https://api.polygon.io/v1/indicators/sma/AAPL")
          .with(query: hash_including({}))
          .to_return(status: 200, body: '{"results":}')

        expect {
          indicators_api.sma("AAPL", window: 20, timespan: "day")
        }.to raise_error(JSON::ParserError)
      end
    end
  end

  describe "data transformation" do
    context "timestamp handling" do
      let(:timestamp_response) do
        {
          results: {
            underlying: {ticker: "AAPL"},
            values: [
              {timestamp: 1704067200000, value: 180.50}, # Integer milliseconds
              {timestamp: "2024-01-02", value: 181.75}    # String date
            ]
          },
          status: "OK"
        }.to_json
      end

      it "handles different timestamp formats" do
        stub_request(:get, "https://api.polygon.io/v1/indicators/sma/AAPL")
          .with(query: hash_including({}))
          .to_return(status: 200, body: timestamp_response)

        result = indicators_api.sma("AAPL", window: 20, timespan: "day")
        expect(result.values.length).to eq(2)
        expect(result.values.first.timestamp).to be_a(Time)
      end
    end

    context "numeric value handling" do
      let(:numeric_response) do
        {
          results: {
            underlying: {ticker: "AAPL"},
            values: [
              {timestamp: 1704067200000, value: 180},      # Integer
              {timestamp: 1704153600000, value: 181.75},   # Float
              {timestamp: 1704240000000, value: "182.50"}  # String number
            ]
          },
          status: "OK"
        }.to_json
      end

      it "converts various numeric formats to Float" do
        stub_request(:get, "https://api.polygon.io/v1/indicators/sma/AAPL")
          .with(query: hash_including({}))
          .to_return(status: 200, body: numeric_response)

        result = indicators_api.sma("AAPL", window: 20, timespan: "day")
        expect(result.values.map(&:value)).to all(be_a(Float))
        expect(result.values.map(&:value)).to eq([180.0, 181.75, 182.5])
      end
    end
  end

  describe "autoload behavior" do
    it "can load SMA class" do
      expect(described_class::SMA).to be_a(Class)
    end

    it "can load EMA class" do
      expect(described_class::EMA).to be_a(Class)
    end

    it "can load RSI class" do
      expect(described_class::RSI).to be_a(Class)
    end

    it "can load MACD class" do
      expect(described_class::MACD).to be_a(Class)
    end
  end
end
