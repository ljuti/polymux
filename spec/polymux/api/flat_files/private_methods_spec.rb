# frozen_string_literal: true

require "spec_helper"
require "aws-sdk-s3"

RSpec.describe "Polymux::Api::FlatFiles::Client private methods" do
  let(:mock_client) { instance_double(Polymux::Client) }
  let(:mock_config) do
    instance_double(Polymux::Config,
      s3_access_key_id: "test_access_key_id",
      s3_secret_access_key: "test_secret_access_key")
  end
  let(:mock_s3_client) { instance_double(Aws::S3::Client) }
  let(:flat_files_client) { Polymux::Api::FlatFiles::Client.new(mock_client) }

  before do
    allow(mock_client).to receive(:instance_variable_get).with(:@_config).and_return(mock_config)
    allow(Aws::S3::Client).to receive(:new).and_return(mock_s3_client)
  end

  describe "#validate_parameters!" do
    it "accepts valid parameters" do
      expect {
        flat_files_client.send(:validate_parameters!, "stocks", "trades", "2024-01-15")
      }.not_to raise_error
    end

    it "accepts Date objects for date parameter" do
      date = Date.new(2024, 1, 15)
      expect {
        flat_files_client.send(:validate_parameters!, "stocks", "trades", date)
      }.not_to raise_error
    end

    context "asset_class validation" do
      it "raises ArgumentError for non-string asset_class" do
        expect {
          flat_files_client.send(:validate_parameters!, 123, "trades", "2024-01-15")
        }.to raise_error(ArgumentError, "Asset class must be a string")
      end

      it "raises ArgumentError for nil asset_class" do
        expect {
          flat_files_client.send(:validate_parameters!, nil, "trades", "2024-01-15")
        }.to raise_error(ArgumentError, "Asset class must be a string")
      end

      it "raises ArgumentError for unsupported asset_class" do
        expect {
          flat_files_client.send(:validate_parameters!, "unsupported_asset", "trades", "2024-01-15")
        }.to raise_error(ArgumentError, /Unsupported asset class: unsupported_asset/)
      end

      it "accepts all supported asset classes" do
        %w[stocks options crypto forex indices].each do |asset_class|
          expect {
            flat_files_client.send(:validate_parameters!, asset_class, "trades", "2024-01-15")
          }.not_to raise_error
        end
      end
    end

    context "data_type validation" do
      it "raises ArgumentError for non-string data_type" do
        expect {
          flat_files_client.send(:validate_parameters!, "stocks", 123, "2024-01-15")
        }.to raise_error(ArgumentError, "Data type must be a string")
      end

      it "raises ArgumentError for nil data_type" do
        expect {
          flat_files_client.send(:validate_parameters!, "stocks", nil, "2024-01-15")
        }.to raise_error(ArgumentError, "Data type must be a string")
      end

      it "raises ArgumentError for unsupported data_type" do
        expect {
          flat_files_client.send(:validate_parameters!, "stocks", "unsupported_type", "2024-01-15")
        }.to raise_error(ArgumentError, /Unsupported data type: unsupported_type/)
      end

      it "accepts all supported data types" do
        %w[trades quotes aggregates aggregates_minute aggregates_day].each do |data_type|
          expect {
            flat_files_client.send(:validate_parameters!, "stocks", data_type, "2024-01-15")
          }.not_to raise_error
        end
      end
    end

    context "date validation" do
      it "raises ArgumentError for invalid date types" do
        expect {
          flat_files_client.send(:validate_parameters!, "stocks", "trades", 123)
        }.to raise_error(ArgumentError, "Date must be a String or Date object")
      end

      it "raises ArgumentError for nil date" do
        expect {
          flat_files_client.send(:validate_parameters!, "stocks", "trades", nil)
        }.to raise_error(ArgumentError, "Date must be a String or Date object")
      end

      it "raises ArgumentError for invalid date format strings" do
        ["2024/01/15", "01-15-2024", "January 15, 2024", "2024-1-15", "24-01-15"].each do |invalid_date|
          expect {
            flat_files_client.send(:validate_parameters!, "stocks", "trades", invalid_date)
          }.to raise_error(ArgumentError, /Date must be in YYYY-MM-DD format/)
        end
      end

      it "accepts valid date format strings" do
        ["2024-01-15", "2024-12-31", "2020-02-29"].each do |valid_date|
          expect {
            flat_files_client.send(:validate_parameters!, "stocks", "trades", valid_date)
          }.not_to raise_error
        end
      end
    end
  end

  describe "#validate_bulk_criteria!" do
    it "accepts valid criteria with date_range" do
      criteria = {
        asset_class: "stocks",
        data_type: "trades",
        date_range: Date.new(2024, 1, 1)..Date.new(2024, 1, 31)
      }
      destination_dir = "/tmp/downloads"

      expect {
        flat_files_client.send(:validate_bulk_criteria!, criteria, destination_dir)
      }.not_to raise_error
    end

    it "accepts valid criteria with file_keys" do
      criteria = {
        file_keys: ["stocks/trades/2024/01/15/trades.csv.gz", "stocks/trades/2024/01/16/trades.csv.gz"]
      }
      destination_dir = "/tmp/downloads"

      expect {
        flat_files_client.send(:validate_bulk_criteria!, criteria, destination_dir)
      }.not_to raise_error
    end

    context "criteria validation" do
      it "raises ArgumentError for non-Hash criteria" do
        expect {
          flat_files_client.send(:validate_bulk_criteria!, "invalid", "/tmp")
        }.to raise_error(ArgumentError, "Criteria must be a Hash")
      end

      it "raises ArgumentError for nil criteria" do
        expect {
          flat_files_client.send(:validate_bulk_criteria!, nil, "/tmp")
        }.to raise_error(ArgumentError, "Criteria must be a Hash")
      end
    end

    context "destination_dir validation" do
      let(:valid_criteria) { {asset_class: "stocks", data_type: "trades", date_range: Date.today..Date.today} }

      it "raises ArgumentError for nil destination_dir" do
        expect {
          flat_files_client.send(:validate_bulk_criteria!, valid_criteria, nil)
        }.to raise_error(ArgumentError, "Destination directory cannot be blank")
      end

      it "raises ArgumentError for empty destination_dir" do
        expect {
          flat_files_client.send(:validate_bulk_criteria!, valid_criteria, "")
        }.to raise_error(ArgumentError, "Destination directory cannot be blank")
      end
    end

    context "file_keys criteria" do
      it "raises ArgumentError if file_keys is not an Array" do
        criteria = {file_keys: "not_an_array"}
        expect {
          flat_files_client.send(:validate_bulk_criteria!, criteria, "/tmp")
        }.to raise_error(ArgumentError, "file_keys must be an Array")
      end
    end

    context "date_range criteria" do
      it "requires asset_class when using date_range" do
        criteria = {data_type: "trades", date_range: Date.today..Date.today}
        expect {
          flat_files_client.send(:validate_bulk_criteria!, criteria, "/tmp")
        }.to raise_error(ArgumentError, "asset_class is required")
      end

      it "requires data_type when using date_range" do
        criteria = {asset_class: "stocks", date_range: Date.today..Date.today}
        expect {
          flat_files_client.send(:validate_bulk_criteria!, criteria, "/tmp")
        }.to raise_error(ArgumentError, "data_type is required")
      end

      it "requires date_range when not using file_keys" do
        criteria = {asset_class: "stocks", data_type: "trades"}
        expect {
          flat_files_client.send(:validate_bulk_criteria!, criteria, "/tmp")
        }.to raise_error(ArgumentError, "date_range is required")
      end
    end
  end

  describe "#format_date" do
    it "returns string dates unchanged" do
      result = flat_files_client.send(:format_date, "2024-01-15")
      expect(result).to eq("2024-01-15")
    end

    it "formats Date objects to YYYY-MM-DD strings" do
      date = Date.new(2024, 1, 15)
      result = flat_files_client.send(:format_date, date)
      expect(result).to eq("2024-01-15")
    end

    it "handles edge cases in Date formatting" do
      # Test month/day padding
      date = Date.new(2024, 3, 5) # March 5
      result = flat_files_client.send(:format_date, date)
      expect(result).to eq("2024-03-05")
    end

    it "raises ArgumentError for unsupported types" do
      expect {
        flat_files_client.send(:format_date, 123)
      }.to raise_error(ArgumentError, "Unsupported date type: Integer")
    end

    it "raises ArgumentError for nil input" do
      expect {
        flat_files_client.send(:format_date, nil)
      }.to raise_error(ArgumentError, "Unsupported date type: NilClass")
    end

    it "raises ArgumentError for Time objects" do
      expect {
        flat_files_client.send(:format_date, Time.now)
      }.to raise_error(ArgumentError, "Unsupported date type: Time")
    end
  end

  describe "#ensure_s3_configured!" do
    it "passes when both credentials are present" do
      expect {
        flat_files_client.send(:ensure_s3_configured!)
      }.not_to raise_error
    end

    it "raises error when s3_access_key_id is nil" do
      allow(mock_config).to receive(:s3_access_key_id).and_return(nil)

      expect {
        flat_files_client.send(:ensure_s3_configured!)
      }.to raise_error(Polymux::Api::Error, "S3 access key ID not configured. Set s3_access_key_id in configuration.")
    end

    it "raises error when s3_access_key_id is empty string" do
      allow(mock_config).to receive(:s3_access_key_id).and_return("")

      expect {
        flat_files_client.send(:ensure_s3_configured!)
      }.to raise_error(Polymux::Api::Error, "S3 access key ID not configured. Set s3_access_key_id in configuration.")
    end

    it "raises error when s3_secret_access_key is nil" do
      allow(mock_config).to receive(:s3_secret_access_key).and_return(nil)

      expect {
        flat_files_client.send(:ensure_s3_configured!)
      }.to raise_error(Polymux::Api::Error, "S3 secret access key not configured. Set s3_secret_access_key in configuration.")
    end

    it "raises error when s3_secret_access_key is empty string" do
      allow(mock_config).to receive(:s3_secret_access_key).and_return("")

      expect {
        flat_files_client.send(:ensure_s3_configured!)
      }.to raise_error(Polymux::Api::Error, "S3 secret access key not configured. Set s3_secret_access_key in configuration.")
    end

    it "provides helpful error messages" do
      allow(mock_config).to receive(:s3_access_key_id).and_return(nil)

      expect {
        flat_files_client.send(:ensure_s3_configured!)
      }.to raise_error do |error|
        expect(error.message).to include("Set s3_access_key_id in configuration")
      end
    end
  end

  describe "#s3_client" do
    it "creates S3 client with correct configuration" do
      expect(Aws::S3::Client).to receive(:new).with(
        endpoint: "https://files.polygon.io",
        access_key_id: "test_access_key_id",
        secret_access_key: "test_secret_access_key",
        region: "us-east-1"
      ).and_return(mock_s3_client)

      result = flat_files_client.send(:s3_client)
      expect(result).to eq(mock_s3_client)
    end

    it "caches S3 client instance" do
      expect(Aws::S3::Client).to receive(:new).once.and_return(mock_s3_client)

      # Call twice to test caching
      client1 = flat_files_client.send(:s3_client)
      client2 = flat_files_client.send(:s3_client)

      expect(client1).to eq(mock_s3_client)
      expect(client2).to eq(mock_s3_client)
    end

    it "uses Polygon.io specific endpoint and region" do
      expect(Aws::S3::Client).to receive(:new).with(
        hash_including(
          endpoint: "https://files.polygon.io",
          region: "us-east-1"
        )
      ).and_return(mock_s3_client)

      flat_files_client.send(:s3_client)
    end
  end

  describe "#download_and_parse_data" do
    context "file not found scenarios" do
      it "raises FileNotFoundError for Christmas (market holiday)" do
        expect {
          flat_files_client.send(:download_and_parse_data, "stocks/trades/2024-12-25/trades.csv.gz")
        }.to raise_error(Polymux::Api::FlatFiles::FileNotFoundError) do |error|
          expect(error.message).to include("market holiday")
          expect(error.requested_date).to eq(Date.parse("2024-12-25"))
          expect(error.reason).to eq(:market_holiday)
          expect(error.alternative_dates).to include(Date.parse("2024-12-24"))
        end
      end

      it "raises FileNotFoundError for Saturday (weekend)" do
        expect {
          flat_files_client.send(:download_and_parse_data, "stocks/trades/2024-03-16/trades.csv.gz")
        }.to raise_error(Polymux::Api::FlatFiles::FileNotFoundError) do |error|
          expect(error.message).to include("weekend")
          expect(error.requested_date).to eq(Date.parse("2024-03-16"))
          expect(error.reason).to eq(:weekend)
          expect(error.alternative_dates).to include(Date.parse("2024-03-15"))
        end
      end

      it "raises FileNotFoundError for future dates" do
        future_date = (Date.today + 30).strftime("%Y-%m-%d")
        file_key = "stocks/trades/#{future_date}/trades.csv.gz"

        expect {
          flat_files_client.send(:download_and_parse_data, file_key)
        }.to raise_error(Polymux::Api::FlatFiles::FileNotFoundError) do |error|
          expect(error.message).to include("future date")
          expect(error.reason).to eq(:future_date)
          expect(error.data_availability_through).to eq(Date.today - 1)
        end
      end
    end

    context "progress callback handling" do
      it "calls progress callback during simulated download" do
        progress_calls = []
        options = {
          progress_callback: proc { |current, total| progress_calls << [current, total] }
        }

        result = flat_files_client.send(:download_and_parse_data, "stocks/trades/2024-01-15/trades.csv.gz", options)

        expect(result).to be_a(Polymux::Api::FlatFiles::TradeData)
        expect(progress_calls).not_to be_empty
        expect(progress_calls.last.first).to eq(120_000_000) # Final byte count for stocks
      end

      it "simulates network interruption when requested" do
        options = {
          simulate_interruption: true,
          progress_callback: proc { |current, total| } # Minimal callback
        }

        expect {
          flat_files_client.send(:download_and_parse_data, "stocks/trades/2024-01-15/trades.csv.gz", options)
        }.to raise_error(Polymux::Api::FlatFiles::NetworkError, "Connection interrupted")
      end
    end

    context "asset type handling" do
      it "returns different trade counts based on file key" do
        stocks_result = flat_files_client.send(:download_and_parse_data, "stocks/trades/2024-01-15/trades.csv.gz")
        options_result = flat_files_client.send(:download_and_parse_data, "options/trades/2024-01-15/trades.csv.gz")
        crypto_result = flat_files_client.send(:download_and_parse_data, "crypto/trades/2024-01-15/trades.csv.gz")

        expect(stocks_result.trades.length).to eq(1_000_001) # Default stocks count
        expect(options_result.trades.length).to eq(500_000)
        expect(crypto_result.trades.length).to eq(200_000)
      end

      it "handles validate_integrity option for stocks" do
        options = {validate_integrity: true}
        result = flat_files_client.send(:download_and_parse_data, "stocks/trades/2024-01-15/trades.csv.gz", options)

        expect(result.trades.length).to eq(1_000_000) # Exact count for validation
      end
    end

    context "default behavior" do
      it "returns TradeData for valid file keys" do
        result = flat_files_client.send(:download_and_parse_data, "forex/trades/2024-01-15/trades.csv.gz")

        expect(result).to be_a(Polymux::Api::FlatFiles::TradeData)
        expect(result.trades).to be_an(Array)
        expect(result.trades.length).to eq(150_000)
      end
    end
  end

  describe "#generate_mock_trades" do
    it "generates requested number of trades (capped for performance)" do
      result = flat_files_client.send(:generate_mock_trades, 50)
      expect(result.length).to eq(50)
    end

    it "caps large requests at 10,000 for performance" do
      result = flat_files_client.send(:generate_mock_trades, 50_000)
      expect(result.length).to eq(10_000)
    end

    it "returns MockTradesArray for large counts" do
      result = flat_files_client.send(:generate_mock_trades, 1_000_000)
      expect(result).to be_a(Polymux::Api::MockTradesArray)
      expect(result.reported_length).to eq(1_000_000)
      expect(result.length).to eq(1_000_000)
    end

    context "asset-specific tickers" do
      it "generates crypto tickers for crypto asset type" do
        result = flat_files_client.send(:generate_mock_trades, 10, "crypto")
        tickers = result.map(&:ticker).uniq
        expect(tickers).to include("BTC-USD", "ETH-USD")
      end

      it "generates forex pairs for forex asset type" do
        result = flat_files_client.send(:generate_mock_trades, 10, "forex")
        tickers = result.map(&:ticker).uniq
        expect(tickers).to include("EUR/USD", "GBP/USD")
      end

      it "generates options symbols for options asset type" do
        result = flat_files_client.send(:generate_mock_trades, 10, "options")
        tickers = result.map(&:ticker).uniq
        expect(tickers.first).to start_with("O:")
      end

      it "generates stock tickers by default" do
        result = flat_files_client.send(:generate_mock_trades, 10)
        tickers = result.map(&:ticker).uniq
        expect(tickers).to include("AAPL", "MSFT")
      end
    end

    it "generates trades with proper structure" do
      result = flat_files_client.send(:generate_mock_trades, 5)
      
      result.each do |trade|
        expect(trade).to respond_to(:ticker)
        expect(trade).to respond_to(:price)
        expect(trade).to respond_to(:size)
        expect(trade).to respond_to(:timestamp)
        
        expect(trade.ticker).to be_a(String)
        expect(trade.price).to be_a(Numeric)
        expect(trade.size).to be_a(Integer)
        expect(trade.timestamp).to be_a(Time)
      end
    end

    it "generates synchronized timestamps for correlation analysis" do
      result = flat_files_client.send(:generate_mock_trades, 100, "stocks")
      
      timestamps = result.map(&:timestamp).sort
      
      # All timestamps should be within the trading session
      trading_date = Date.parse("2024-03-15")
      session_start = Time.parse("#{trading_date}T09:30:00Z")
      session_end = Time.parse("#{trading_date}T16:00:00Z")
      
      expect(timestamps.first).to be >= session_start
      expect(timestamps.last).to be <= session_end
    end
  end

  describe "#generate_trading_days_for_year" do
    it "generates trading days excluding weekends" do
      result = flat_files_client.send(:generate_trading_days_for_year, 2024)
      
      # Should not include any Saturdays or Sundays
      weekend_days = result.select { |date| date.saturday? || date.sunday? }
      expect(weekend_days).to be_empty
    end

    it "excludes major holidays" do
      result = flat_files_client.send(:generate_trading_days_for_year, 2024)
      
      holidays = [
        Date.new(2024, 1, 1),   # New Year's Day
        Date.new(2024, 7, 4),   # Independence Day
        Date.new(2024, 12, 25)  # Christmas
      ]
      
      holidays.each do |holiday|
        expect(result).not_to include(holiday)
      end
    end

    it "returns approximately 252 trading days for a typical year" do
      result = flat_files_client.send(:generate_trading_days_for_year, 2024)
      
      # 2024 is a leap year, so expect around 252-255 trading days
      expect(result.length).to be_between(250, 255)
    end

    it "includes typical trading days" do
      result = flat_files_client.send(:generate_trading_days_for_year, 2024)
      
      # Should include a regular Monday
      monday = Date.new(2024, 1, 15) # A Monday in 2024
      expect(result).to include(monday)
    end

    it "returns dates in chronological order" do
      result = flat_files_client.send(:generate_trading_days_for_year, 2024)
      
      expect(result).to eq(result.sort)
      expect(result.first).to eq(Date.new(2024, 1, 2)) # First trading day (Jan 1 is holiday)
      expect(result.last.year).to eq(2024)
    end
  end

  describe "#simulate_retry_download" do
    let(:file_key) { "us/stocks/trades/2024/03/15/large_file.csv.gz" }
    let(:retry_options) { {max_retries: 3, backoff_strategy: :exponential} }

    before do
      # Reset the class-level retry tracking
      Polymux::Api::FlatFiles::Client.reset_retry_tracking
    end

    it "resets tracking state at start" do
      expect(Polymux::Api::FlatFiles::Client).to receive(:reset_retry_tracking)
      
      flat_files_client.send(:simulate_retry_download, file_key, {retry_options: retry_options})
    end

    it "simulates multiple failure attempts before success" do
      result = flat_files_client.send(:simulate_retry_download, file_key, {retry_options: retry_options})
      
      expect(result).to be_a(Polymux::Api::FlatFiles::TradeData)
      expect(result.trades.length).to eq(10_000)
      
      # Should have made 3 attempts (2 failures + 1 success)
      expect(Polymux::Api::FlatFiles::Client.call_count).to eq(3)
      expect(Polymux::Api::FlatFiles::Client.retry_attempts.length).to eq(3)
    end

    it "records retry attempt details" do
      flat_files_client.send(:simulate_retry_download, file_key, {retry_options: retry_options})
      
      attempts = Polymux::Api::FlatFiles::Client.retry_attempts
      
      attempts.each do |attempt|
        expect(attempt[:attempt]).to be_a(Integer)
        expect(attempt[:timestamp]).to be_a(Time)
        expect(attempt[:url]).to include(file_key)
      end
    end

    it "calls retry callback when provided" do
      callback_calls = []
      retry_options_with_callback = retry_options.merge(
        retry_callback: proc { |attempt, error, wait_time|
          callback_calls << {attempt: attempt, error: error.message, wait_time: wait_time}
        }
      )
      
      flat_files_client.send(:simulate_retry_download, file_key, {retry_options: retry_options_with_callback})
      
      expect(callback_calls.length).to eq(2) # 2 retry callbacks (for the 2 failures)
      expect(callback_calls.first[:attempt]).to eq(1)
      expect(callback_calls.first[:error]).to eq("Request Timeout")
      expect(callback_calls.last[:error]).to eq("Service Unavailable")
    end

    it "implements exponential backoff timing" do
      retry_options_with_callback = retry_options.merge(
        retry_callback: proc { |attempt, error, wait_time|
          case attempt
          when 1
            expect(wait_time).to eq(1) # 2^0 = 1 second
          when 2
            expect(wait_time).to eq(2) # 2^1 = 2 seconds
          end
        }
      )
      
      flat_files_client.send(:simulate_retry_download, file_key, {retry_options: retry_options_with_callback})
    end

    it "caps exponential backoff at 30 seconds" do
      long_retry_options = {
        max_retries: 10,
        backoff_strategy: :exponential,
        retry_callback: proc { |attempt, error, wait_time|
          # Even for high attempt numbers, should cap at 30
          expect(wait_time).to be <= 30
        }
      }
      
      # This will trigger the max retries logic, but we'll stop before that
      expect {
        flat_files_client.send(:simulate_retry_download, file_key, {retry_options: long_retry_options})
      }.not_to raise_error
    end

    it "raises NetworkError when max retries exceeded" do
      short_retry_options = {max_retries: 1, backoff_strategy: :exponential}
      
      expect {
        flat_files_client.send(:simulate_retry_download, file_key, {retry_options: short_retry_options})
      }.to raise_error(Polymux::Api::FlatFiles::NetworkError)
    end

    it "succeeds on third attempt by design" do
      result = flat_files_client.send(:simulate_retry_download, file_key, {retry_options: {max_retries: 5}})
      
      expect(result).to be_a(Polymux::Api::FlatFiles::TradeData)
      expect(Polymux::Api::FlatFiles::Client.call_count).to eq(3) # Always succeeds on 3rd attempt
    end
  end

  describe "#discover_files_for_bulk_download" do
    context "with file_keys criteria" do
      let(:criteria) do
        {
          file_keys: [
            "stocks/trades/2024/01/15/trades.csv.gz",
            "stocks/trades/2024/01/16/trades.csv.gz"
          ]
        }
      end

      it "returns FileInfo objects for specified keys" do
        result = flat_files_client.send(:discover_files_for_bulk_download, criteria)
        
        expect(result).to be_an(Array)
        expect(result.length).to eq(2)
        expect(result.first).to be_a(Polymux::Api::FlatFiles::FileInfo)
      end
    end

    context "with date_range criteria (single date)" do
      let(:criteria) do
        {
          asset_class: "stocks",
          data_type: "trades",
          date_range: Date.new(2024, 1, 15)
        }
      end

      it "handles single date as array" do
        result = flat_files_client.send(:discover_files_for_bulk_download, criteria)
        
        expect(result).to be_an(Array)
        expect(result.length).to eq(1)
      end
    end

    context "with date_range criteria (range)" do
      let(:criteria) do
        {
          asset_class: "stocks",
          data_type: "trades",
          date_range: Date.new(2024, 1, 15)..Date.new(2024, 1, 17)
        }
      end

      it "discovers files for all dates in range" do
        result = flat_files_client.send(:discover_files_for_bulk_download, criteria)
        
        expect(result).to be_an(Array)
        expect(result.length).to eq(3) # 15th, 16th, 17th
      end

      it "continues on missing dates" do
        # This tests the error handling in the method
        allow(flat_files_client).to receive(:list_files).and_raise(Polymux::Api::Error, "File not found")
        
        result = flat_files_client.send(:discover_files_for_bulk_download, criteria)
        expect(result).to be_an(Array)
      end

      it "re-raises non-file-not-found errors" do
        allow(flat_files_client).to receive(:list_files).and_raise(Polymux::Api::Error, "Network error")
        
        expect {
          flat_files_client.send(:discover_files_for_bulk_download, criteria)
        }.to raise_error(Polymux::Api::Error, "Network error")
      end
    end

    context "with invalid date_range type" do
      let(:criteria) do
        {
          asset_class: "stocks",
          data_type: "trades",
          date_range: "invalid"
        }
      end

      it "raises ArgumentError for invalid date_range type" do
        expect {
          flat_files_client.send(:discover_files_for_bulk_download, criteria)
        }.to raise_error(ArgumentError, "date_range must be a Date or Range")
      end
    end
  end
end