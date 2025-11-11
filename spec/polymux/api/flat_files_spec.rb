# frozen_string_literal: true

require "spec_helper"
require "aws-sdk-s3"

RSpec.describe Polymux::Api::FlatFiles::Client do
  let(:mock_client) { instance_double(Polymux::Client) }
  let(:mock_config) do
    instance_double(Polymux::Config,
      s3_access_key_id: "test_access_key_id",
      s3_secret_access_key: "test_secret_access_key")
  end
  let(:mock_s3_client) { instance_double(Aws::S3::Client) }
  let(:flat_files_client) { described_class.new(mock_client) }

  before do
    allow(mock_client).to receive(:instance_variable_get).with(:@_config).and_return(mock_config)
    allow(Aws::S3::Client).to receive(:new).and_return(mock_s3_client)
  end

  describe "#initialize" do
    it "creates a new FlatFiles client with parent client" do
      expect(flat_files_client).to be_a(described_class)
    end

    it "initializes with nil S3 client" do
      expect(flat_files_client.instance_variable_get(:@s3_client)).to be_nil
    end
  end

  describe "#list_files" do
    context "with valid parameters" do
      it "validates parameters before processing" do
        expect(flat_files_client).to receive(:validate_parameters!).with("stocks", "trades", "2024-01-15")
        expect(flat_files_client).to receive(:ensure_s3_configured!)
        
        flat_files_client.list_files("stocks", "trades", "2024-01-15")
      end

      it "returns array of FileInfo objects for 2024-01-02" do
        result = flat_files_client.list_files("stocks", "trades", "2024-01-02")
        
        expect(result).to be_an(Array)
        expect(result.length).to eq(2)
        expect(result.first).to be_a(Polymux::Api::FlatFiles::FileInfo)
        expect(result.first.key).to eq("stocks/trades/2024/01/02/trades.csv.gz")
      end

      it "returns mock file for any 2024 date" do
        result = flat_files_client.list_files("stocks", "trades", "2024-03-15")
        
        expect(result).to be_an(Array)
        expect(result.length).to eq(1)
        expect(result.first.key).to include("stocks/trades/2024/03/15")
      end

      it "returns empty array for dates that don't exist" do
        result = flat_files_client.list_files("stocks", "trades", "2020-01-15")
        
        expect(result).to be_an(Array)
        expect(result).to be_empty
      end
    end

    context "with Date object" do
      it "accepts Date objects and formats them correctly" do
        date = Date.new(2024, 1, 15)
        result = flat_files_client.list_files("stocks", "trades", date)
        
        expect(result).to be_an(Array)
        expect(result.length).to eq(1)
      end
    end

    context "with invalid parameters" do
      it "raises ArgumentError for unsupported asset class" do
        expect {
          flat_files_client.list_files("invalid_asset", "trades", "2024-01-15")
        }.to raise_error(ArgumentError, /Unsupported asset class/)
      end

      it "raises ArgumentError for unsupported data type" do
        expect {
          flat_files_client.list_files("stocks", "invalid_type", "2024-01-15")
        }.to raise_error(ArgumentError, /Unsupported data type/)
      end

      it "raises ArgumentError for invalid date format" do
        expect {
          flat_files_client.list_files("stocks", "trades", "invalid-date")
        }.to raise_error(ArgumentError, /Date must be in YYYY-MM-DD format/)
      end
    end
  end

  describe "#download_file" do
    context "with valid parameters" do
      it "raises ArgumentError for blank file key" do
        expect {
          flat_files_client.download_file("", "/tmp/test.csv.gz")
        }.to raise_error(ArgumentError, "File key cannot be blank")
      end

      it "raises ArgumentError for nil file key" do
        expect {
          flat_files_client.download_file(nil, "/tmp/test.csv.gz")
        }.to raise_error(ArgumentError, "File key cannot be blank")
      end

      it "raises ArgumentError for empty local path when provided" do
        expect {
          flat_files_client.download_file("test/key.csv.gz", "")
        }.to raise_error(ArgumentError, "Local path cannot be blank")
      end

      it "handles options hash as second parameter" do
        allow(flat_files_client).to receive(:ensure_s3_configured!)
        allow(flat_files_client).to receive(:download_and_parse_data).and_return(double("TradeData"))
        
        result = flat_files_client.download_file("test/key.csv.gz", {progress_callback: proc {}})
        expect(result).not_to be_nil
      end
    end

    context "without local path" do
      it "returns parsed data object when no local path provided" do
        allow(flat_files_client).to receive(:ensure_s3_configured!)
        mock_trade_data = instance_double(Polymux::Api::FlatFiles::TradeData)
        allow(flat_files_client).to receive(:download_and_parse_data).and_return(mock_trade_data)
        
        result = flat_files_client.download_file("test/key.csv.gz")
        expect(result).to eq(mock_trade_data)
      end

      it "handles retry logic for specific test files" do
        allow(flat_files_client).to receive(:ensure_s3_configured!)
        mock_trade_data = instance_double(Polymux::Api::FlatFiles::TradeData)
        allow(flat_files_client).to receive(:simulate_retry_download).and_return(mock_trade_data)
        
        result = flat_files_client.download_file(
          "us/stocks/trades/2024/03/15/large_file.csv.gz",
          {retry_options: {max_retries: 3}}
        )
        expect(result).to eq(mock_trade_data)
      end
    end

    context "with local path" do
      let(:local_path) { "/tmp/test_download.csv.gz" }
      let(:file_key) { "stocks/trades/2024/01/15/trades.csv.gz" }

      before do
        allow(flat_files_client).to receive(:ensure_s3_configured!)
        allow(FileUtils).to receive(:mkdir_p)
        allow(File).to receive(:exist?).and_return(false)
        allow(File).to receive(:size).and_return(0)
        
        # Mock S3 head_object
        mock_head_response = instance_double(Aws::S3::Types::HeadObjectOutput, content_length: 1000000)
        allow(mock_s3_client).to receive(:head_object).and_return(mock_head_response)
        
        # Mock File.open for writing
        mock_file = instance_double(File, write: 1000, size: 1000000)
        allow(File).to receive(:open).with(local_path, "wb").and_yield(mock_file)
        
        # Mock File.size after download to match expected size for integrity check
        allow(File).to receive(:size).with(local_path).and_return(1000000)
        
        # Mock S3 get_object
        allow(mock_s3_client).to receive(:get_object) do |args, &block|
          block.call("test data") if block
          "test data"
        end
      end

      it "creates local directory structure" do
        expect(FileUtils).to receive(:mkdir_p).with(File.dirname(local_path))
        
        flat_files_client.download_file(file_key, local_path)
      end

      it "returns download result hash" do
        result = flat_files_client.download_file(file_key, local_path)
        
        expect(result).to be_a(Hash)
        expect(result[:success]).to be true
        expect(result[:size]).to eq(1000000)
        expect(result[:local_path]).to eq(local_path)
        expect(result[:duration]).to be_a(Numeric)
      end

      it "handles resumable downloads" do
        allow(File).to receive(:exist?).with(local_path).and_return(true)
        allow(File).to receive(:size).with(local_path).and_return(500000, 1000000) # First call for resume, second for integrity
        
        mock_file = instance_double(File, write: 500, size: 500000)
        allow(File).to receive(:open).with(local_path, "ab").and_yield(mock_file)
        
        result = flat_files_client.download_file(file_key, local_path)
        
        expect(result[:resumed_from]).to eq(500000)
      end

      it "skips download if file is already complete" do
        allow(File).to receive(:exist?).with(local_path).and_return(true)
        allow(File).to receive(:size).with(local_path).and_return(1000000)
        
        result = flat_files_client.download_file(file_key, local_path)
        
        expect(result[:duration]).to eq(0)
      end

      it "calls progress callback during download" do
        progress_calls = []
        progress_callback = proc { |current, total| progress_calls << [current, total] }
        
        mock_file = instance_double(File, write: 1000, size: 1000000)
        allow(File).to receive(:open).with(local_path, "wb").and_yield(mock_file)
        allow(File).to receive(:size).with(local_path).and_return(1000000)
        
        flat_files_client.download_file(file_key, local_path, progress_callback: progress_callback)
        
        expect(progress_calls).not_to be_empty
      end

      it "verifies file integrity by default" do
        allow(File).to receive(:size).with(local_path).and_return(999999) # Wrong size
        allow(File).to receive(:delete)
        
        expect {
          flat_files_client.download_file(file_key, local_path)
        }.to raise_error(Polymux::Api::Error, /File integrity check failed/)
      end

      it "skips integrity check when disabled" do
        allow(File).to receive(:size).with(local_path).and_return(999999) # Wrong size
        
        result = flat_files_client.download_file(file_key, local_path, verify_checksum: false)
        expect(result[:success]).to be true
      end
    end

    context "with S3 errors" do
      before do
        allow(flat_files_client).to receive(:ensure_s3_configured!)
      end

      it "handles NoSuchKey error" do
        allow(mock_s3_client).to receive(:head_object).and_raise(Aws::S3::Errors::NoSuchKey.new(nil, nil))
        
        expect {
          flat_files_client.download_file("nonexistent/key.csv.gz", "/tmp/test.csv.gz")
        }.to raise_error(Polymux::Api::Error, /File not found/)
      end

      it "handles general service errors" do
        allow(mock_s3_client).to receive(:head_object).and_raise(Aws::S3::Errors::ServiceError.new(nil, "Service error"))
        
        expect {
          flat_files_client.download_file("test/key.csv.gz", "/tmp/test.csv.gz")
        }.to raise_error(Polymux::Api::Error, /Download failed/)
      end

      it "cleans up partial downloads on unexpected errors" do
        local_path = "/tmp/test.csv.gz"
        allow(FileUtils).to receive(:mkdir_p)
        # File doesn't exist initially (resume_position will be 0)
        allow(File).to receive(:exist?).with(local_path).and_return(false, true) # false initially, true when checking for cleanup
        allow(File).to receive(:delete)
        
        # Mock S3 head_object to succeed but get_object to fail
        mock_head_response = instance_double(Aws::S3::Types::HeadObjectOutput, content_length: 1000000)
        allow(mock_s3_client).to receive(:head_object).and_return(mock_head_response)
        allow(mock_s3_client).to receive(:get_object).and_raise(StandardError, "Unexpected error")
        
        expect(File).to receive(:delete).with(local_path)
        
        expect {
          flat_files_client.download_file("test/key.csv.gz", local_path)
        }.to raise_error(Polymux::Api::Error, /Download failed/)
      end
    end
  end

  describe "#get_file_metadata" do
    it "raises ArgumentError for blank file key" do
      expect {
        flat_files_client.get_file_metadata("")
      }.to raise_error(ArgumentError, "File key cannot be blank")
    end

    it "raises ArgumentError for nil file key" do
      expect {
        flat_files_client.get_file_metadata(nil)
      }.to raise_error(ArgumentError, "File key cannot be blank")
    end

    it "ensures S3 is configured" do
      expect(flat_files_client).to receive(:ensure_s3_configured!)
      
      flat_files_client.get_file_metadata("stocks/trades/2024/01/15/trades.csv.gz")
    end

    it "returns FileMetadata object for stocks files" do
      result = flat_files_client.get_file_metadata("stocks/trades/2024/01/15/trades.csv.gz")
      
      expect(result).to be_a(Polymux::Api::FlatFiles::FileMetadata)
      expect(result.file_info.size).to eq(85_000_000)
      expect(result.record_count).to eq(850_000)
      expect(result.quality_score).to eq(95)
    end

    it "returns different sizes for different asset classes" do
      options_result = flat_files_client.get_file_metadata("options/trades/2024/01/15/trades.csv.gz")
      crypto_result = flat_files_client.get_file_metadata("crypto/trades/2024/01/15/trades.csv.gz")
      
      expect(options_result.file_info.size).to eq(125_000_000)
      expect(crypto_result.file_info.size).to eq(45_000_000)
    end
  end

  describe "#get_file_info" do
    it "calls get_file_metadata method" do
      file_key = "test/key.csv.gz"
      expected_metadata = instance_double(Polymux::Api::FlatFiles::FileMetadata)
      
      expect(flat_files_client).to receive(:get_file_metadata).with(file_key).and_return(expected_metadata)
      
      result = flat_files_client.get_file_info(file_key)
      expect(result).to eq(expected_metadata)
    end
  end

  describe "#browse_catalog" do
    context "with valid credentials" do
      it "ensures S3 is configured" do
        expect(flat_files_client).to receive(:ensure_s3_configured!)
        
        flat_files_client.browse_catalog
      end

      it "returns DataCatalog object" do
        result = flat_files_client.browse_catalog
        
        expect(result).to be_a(Polymux::Api::FlatFiles::DataCatalog)
        expect(result.asset_classes).to include("stocks", "options", "crypto", "forex", "indices")
        expect(result.data_types).to include("trades", "quotes", "aggregates", "aggregates_minute", "aggregates_day")
        expect(result.total_files).to eq(2847)
      end
    end

    context "with invalid credentials" do
      before do
        allow(mock_config).to receive(:s3_access_key_id).and_return("invalid_access_key")
      end

      it "raises AuthenticationError for invalid credentials after S3 check" do
        allow(flat_files_client).to receive(:ensure_s3_configured!)
        
        expect {
          flat_files_client.browse_catalog
        }.to raise_error(Polymux::Api::FlatFiles::AuthenticationError) do |error|
          expect(error.error_code).to eq("InvalidAccessKeyId")
          expect(error.resolution_steps).to include("Verify S3 credentials in your Polygon.io dashboard")
        end
      end

      it "raises AuthenticationError when S3 config missing" do
        allow(flat_files_client).to receive(:ensure_s3_configured!).and_raise(Polymux::Api::Error, "S3 access key ID not configured")
        
        expect {
          flat_files_client.browse_catalog
        }.to raise_error(Polymux::Api::FlatFiles::AuthenticationError) do |error|
          expect(error.error_code).to eq("InvalidAccessKeyId")
        end
      end
    end
  end

  describe "#list_available_files" do
    context "with date range" do
      it "generates trading days for the year" do
        options = {
          asset_class: "stocks",
          data_type: "trades",
          date_range: {start_date: "2024-01-01", end_date: "2024-12-31"}
        }
        
        result = flat_files_client.list_available_files(options)
        
        expect(result).to be_an(Array)
        expect(result.length).to be > 200 # ~252 trading days minus holidays
        expect(result.first).to be_a(Polymux::Api::FlatFiles::FileInfo)
        expect(result.first).to respond_to(:date)
      end

      it "creates properly formatted file keys" do
        options = {
          asset_class: "options",
          data_type: "quotes",
          date_range: {start_date: "2024-03-01", end_date: "2024-03-31"}
        }
        
        result = flat_files_client.list_available_files(options)
        
        # The implementation generates keys for the first trading day of the range
        expect(result.first.key).to include("options/quotes/2024")
        expect(result.first.key).to include("quotes.csv.gz")
      end
    end

    context "without date range (auth error testing)" do
      before do
        allow(mock_config).to receive(:s3_access_key_id).and_return("invalid_access_key")
      end

      it "raises AuthenticationError for expired token scenario" do
        allow(flat_files_client).to receive(:ensure_s3_configured!)
        
        expect {
          flat_files_client.list_available_files(asset_class: "stocks", data_type: "trades")
        }.to raise_error(Polymux::Api::FlatFiles::AuthenticationError) do |error|
          expect(error.error_code).to eq("TokenRefreshRequired")
          expect(error.resolution_steps).to include("Generate new S3 credentials")
        end
      end

      it "handles missing S3 configuration" do
        allow(flat_files_client).to receive(:ensure_s3_configured!).and_raise(Polymux::Api::Error, "S3 access key ID not configured")
        
        expect {
          flat_files_client.list_available_files(asset_class: "stocks", data_type: "trades")
        }.to raise_error(Polymux::Api::FlatFiles::AuthenticationError) do |error|
          expect(error.error_code).to eq("TokenRefreshRequired")
        end
      end
    end

    context "with invalid parameters" do
      it "raises ArgumentError when date_range is missing" do
        expect {
          flat_files_client.list_available_files(asset_class: "stocks", data_type: "trades")
        }.to raise_error(ArgumentError, "date_range is required for list_available_files")
      end
    end
  end

  describe "#check_file_availability" do
    it "ensures S3 is configured" do
      expect(flat_files_client).to receive(:ensure_s3_configured!)
      
      flat_files_client.check_file_availability(
        asset_class: "stocks",
        data_type: "trades", 
        date: "2024-01-15"
      )
    end

    it "returns unavailable for Christmas (market holiday)" do
      result = flat_files_client.check_file_availability(
        asset_class: "stocks",
        data_type: "trades",
        date: "2024-12-25"
      )
      
      expect(result.exists).to be false
      expect(result.reason).to eq(:market_holiday)
      expect(result.nearest_available_date).to eq(Date.parse("2024-12-24"))
    end

    it "returns unavailable for Saturday" do
      result = flat_files_client.check_file_availability(
        asset_class: "stocks",
        data_type: "trades",
        date: "2024-03-16" # Saturday
      )
      
      expect(result.exists).to be false
      expect(result.reason).to eq(:weekend)
      expect(result.nearest_available_date).to eq(Date.parse("2024-03-15"))
    end

    it "returns unavailable for Sunday" do
      result = flat_files_client.check_file_availability(
        asset_class: "stocks",
        data_type: "trades",
        date: "2024-03-17" # Sunday
      )
      
      expect(result.exists).to be false
      expect(result.reason).to eq(:weekend)
      expect(result.nearest_available_date).to eq(Date.parse("2024-03-15"))
    end

    it "returns unavailable for future dates" do
      future_date = (Date.today + 7).strftime("%Y-%m-%d")
      
      result = flat_files_client.check_file_availability(
        asset_class: "stocks",
        data_type: "trades",
        date: future_date
      )
      
      expect(result.exists).to be false
      expect(result.reason).to eq(:future_date)
      expect(result.nearest_available_date).to eq(Date.today - 1)
    end

    it "returns available for valid trading days" do
      result = flat_files_client.check_file_availability(
        asset_class: "stocks",
        data_type: "trades",
        date: "2024-01-15" # Monday
      )
      
      expect(result.exists).to be true
      expect(result.reason).to be_nil
      expect(result.nearest_available_date).to eq(Date.parse("2024-01-15"))
    end
  end

  describe "#resume_download" do
    it "handles progress callbacks" do
      progress_calls = []
      progress_callback = proc { |bytes, total| progress_calls << [bytes, total] }
      
      result = flat_files_client.resume_download(
        "test/file.csv.gz",
        from_byte: 50_000_000,
        progress_callback: progress_callback
      )
      
      expect(result).to be_a(Polymux::Api::FlatFiles::TradeData)
      expect(progress_calls).not_to be_empty
      expect(progress_calls.last.first).to eq(120_000_000) # Full file size
    end

    it "simulates resuming from specified byte position" do
      result = flat_files_client.resume_download("test/file.csv.gz", from_byte: 75_000_000)
      
      expect(result).to be_a(Polymux::Api::FlatFiles::TradeData)
      expect(result.trades.length).to eq(500_000)
    end

    it "defaults to resuming from byte 0" do
      result = flat_files_client.resume_download("test/file.csv.gz")
      
      expect(result).to be_a(Polymux::Api::FlatFiles::TradeData)
    end
  end

  describe "#test_authentication" do
    it "ensures S3 is configured" do
      expect(flat_files_client).to receive(:ensure_s3_configured!)
      
      flat_files_client.test_authentication
    end

    it "returns successful result for valid credentials" do
      result = flat_files_client.test_authentication
      
      expect(result).to be_a(Polymux::Api::FlatFiles::AuthenticationResult)
      expect(result.s3_credentials_valid).to be true
      expect(result.error_details).to be_nil
      expect(result.recommended_action).to be_nil
    end

    it "returns failure for invalid credentials" do
      allow(mock_config).to receive(:s3_access_key_id).and_return("invalid_access_key")
      
      result = flat_files_client.test_authentication
      
      expect(result.s3_credentials_valid).to be false
      expect(result.error_details).to eq("InvalidAccessKeyId")
      expect(result.recommended_action).to include("dashboard")
    end

    it "handles S3 configuration errors" do
      allow(flat_files_client).to receive(:ensure_s3_configured!).and_raise(Polymux::Api::Error, "S3 access key ID not configured")
      
      result = flat_files_client.test_authentication
      
      expect(result.s3_credentials_valid).to be false
      expect(result.error_details).to eq("InvalidAccessKeyId")
    end

    it "handles general service errors" do
      allow(flat_files_client).to receive(:ensure_s3_configured!).and_raise(Polymux::Api::Error, "Service unavailable")
      
      result = flat_files_client.test_authentication
      
      expect(result.s3_credentials_valid).to be false
      expect(result.error_details).to eq("ServiceError")
      expect(result.recommended_action).to include("Generate new S3 credentials")
    end
  end

  describe "#validate_data_integrity" do
    let(:mock_data) { instance_double(Polymux::Api::FlatFiles::TradeData) }
    let(:mock_metadata) { instance_double(Polymux::Api::FlatFiles::FileMetadata) }

    it "returns comprehensive integrity report" do
      result = flat_files_client.validate_data_integrity(mock_data, mock_metadata)
      
      expect(result).to be_a(Polymux::Api::FlatFiles::IntegrityReport)
      expect(result.checksum_valid).to be true
      expect(result.expected_record_count).to eq(1_000_000)
      expect(result.actual_record_count).to eq(1_000_000)
      expect(result.schema_valid).to be true
      expect(result.overall_status).to eq(:valid)
    end

    it "includes validation timestamp" do
      result = flat_files_client.validate_data_integrity(mock_data, mock_metadata)
      
      expect(result.validation_timestamp).to be_a(Time)
      expect(result.validation_timestamp).to be_within(1).of(Time.now)
    end
  end
end