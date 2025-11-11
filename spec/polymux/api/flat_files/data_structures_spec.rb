# frozen_string_literal: true

require "spec_helper"

RSpec.describe Polymux::Api::FlatFiles::FileInfo do
  let(:s3_object_data) do
    OpenStruct.new(
      key: "stocks/trades/2024/01/15/trades.csv.gz",
      size: 85_000_000,
      last_modified: Time.parse("2024-01-16T11:00:00.000Z"),
      etag: '"a1b2c3d4e5f6"'
    )
  end

  let(:file_info) do
    described_class.new(
      key: "stocks/trades/2024/01/15/trades.csv.gz",
      asset_class: "stocks",
      data_type: "trades",
      date: "2024-01-15",
      size: 85_000_000,
      last_modified: Time.parse("2024-01-16T11:00:00.000Z"),
      etag: "a1b2c3d4e5f6",
      record_count: 850_000
    )
  end

  describe ".new" do
    it "creates FileInfo with required attributes" do
      expect(file_info.key).to eq("stocks/trades/2024/01/15/trades.csv.gz")
      expect(file_info.asset_class).to eq("stocks")
      expect(file_info.data_type).to eq("trades")
      expect(file_info.date).to eq("2024-01-15")
      expect(file_info.size).to eq(85_000_000)
    end

    it "handles optional attributes" do
      expect(file_info.last_modified).to eq(Time.parse("2024-01-16T11:00:00.000Z"))
      expect(file_info.etag).to eq("a1b2c3d4e5f6")
      expect(file_info.record_count).to eq(850_000)
    end

    it "accepts nil optional attributes" do
      minimal_info = described_class.new(
        key: "test/key.csv.gz",
        asset_class: "stocks",
        data_type: "trades",
        date: "2024-01-15",
        size: 1000,
        last_modified: nil,
        etag: nil,
        record_count: nil
      )

      expect(minimal_info.last_modified).to be_nil
      expect(minimal_info.etag).to be_nil
      expect(minimal_info.record_count).to be_nil
    end
  end

  describe "#size_mb" do
    it "converts bytes to megabytes" do
      expect(file_info.size_mb).to be_within(0.01).of(81.06) # 85_000_000 / 1_048_576
    end

    it "handles zero size" do
      zero_size_info = described_class.new(
        key: "test.csv.gz",
        asset_class: "stocks",
        data_type: "trades",
        date: "2024-01-15",
        size: 0,
        last_modified: nil,
        etag: nil,
        record_count: nil
      )

      expect(zero_size_info.size_mb).to eq(0.0)
    end

    it "handles small files" do
      small_info = described_class.new(
        key: "test.csv.gz",
        asset_class: "stocks",
        data_type: "trades",
        date: "2024-01-15",
        size: 1024,
        last_modified: nil,
        etag: nil,
        record_count: nil
      )

      expect(small_info.size_mb).to be_within(0.01).of(0.001) # 1024 / 1_048_576
    end
  end

  describe "#compression" do
    it "returns 'gzip' for .gz files" do
      expect(file_info.compression).to eq("gzip")
    end

    it "returns 'none' for uncompressed files" do
      uncompressed_info = described_class.new(
        key: "stocks/trades/2024/01/15/trades.csv",
        asset_class: "stocks",
        data_type: "trades",
        date: "2024-01-15",
        size: 1000,
        last_modified: nil,
        etag: nil,
        record_count: nil
      )

      expect(uncompressed_info.compression).to eq("none")
    end

    it "handles mixed case extensions" do
      mixed_case_info = described_class.new(
        key: "stocks/trades/2024/01/15/trades.CSV.GZ",
        asset_class: "stocks",
        data_type: "trades",
        date: "2024-01-15",
        size: 1000,
        last_modified: nil,
        etag: nil,
        record_count: nil
      )

      expect(mixed_case_info.compression).to eq("gzip")
    end
  end

  describe "#suggested_filename" do
    it "generates human-readable filename for compressed files" do
      expect(file_info.suggested_filename).to eq("stocks_trades_2024-01-15.csv.gz")
    end

    it "generates filename without .gz for uncompressed files" do
      uncompressed_info = described_class.new(
        key: "options/quotes/2024/01/15/quotes.csv",
        asset_class: "options",
        data_type: "quotes",
        date: "2024-01-15",
        size: 1000,
        last_modified: nil,
        etag: nil,
        record_count: nil
      )

      expect(uncompressed_info.suggested_filename).to eq("options_quotes_2024-01-15.csv")
    end

    it "handles different asset classes and data types" do
      crypto_info = described_class.new(
        key: "crypto/aggregates/2024/01/15/aggregates.csv.gz",
        asset_class: "crypto",
        data_type: "aggregates",
        date: "2024-01-15",
        size: 1000,
        last_modified: nil,
        etag: nil,
        record_count: nil
      )

      expect(crypto_info.suggested_filename).to eq("crypto_aggregates_2024-01-15.csv.gz")
    end
  end

  describe "#compressed?" do
    it "returns true for gzipped files" do
      expect(file_info.compressed?).to be true
    end

    it "returns false for uncompressed files" do
      uncompressed_info = described_class.new(
        key: "stocks/trades/2024/01/15/trades.csv",
        asset_class: "stocks",
        data_type: "trades", 
        date: "2024-01-15",
        size: 1000,
        last_modified: nil,
        etag: nil,
        record_count: nil
      )

      expect(uncompressed_info.compressed?).to be false
    end
  end

  describe ".from_s3_object" do
    it "creates FileInfo from S3 object data" do
      result = described_class.from_s3_object(s3_object_data)

      expect(result).to be_a(described_class)
      expect(result.key).to eq("stocks/trades/2024/01/15/trades.csv.gz")
      expect(result.asset_class).to eq("stocks")
      expect(result.data_type).to eq("trades")
      expect(result.date).to eq("2024-01-15")
      expect(result.size).to eq(85_000_000)
      expect(result.last_modified).to eq(Time.parse("2024-01-16T11:00:00.000Z"))
      expect(result.etag).to eq("a1b2c3d4e5f6") # Quotes removed
    end

    it "handles missing etag" do
      s3_data_without_etag = OpenStruct.new(
        key: "stocks/trades/2024/01/15/trades.csv.gz",
        size: 1000,
        last_modified: Time.now,
        etag: nil
      )

      result = described_class.from_s3_object(s3_data_without_etag)
      expect(result.etag).to be_nil
    end

    it "parses complex key structures" do
      complex_s3_data = OpenStruct.new(
        key: "options/aggregates_minute/2024/12/31/aggregates_minute.csv.gz",
        size: 50_000_000,
        last_modified: Time.now,
        etag: '"complex123"'
      )

      result = described_class.from_s3_object(complex_s3_data)
      expect(result.asset_class).to eq("options")
      expect(result.data_type).to eq("aggregates_minute")
      expect(result.date).to eq("2024-12-31")
    end

    it "sets record_count to nil by default" do
      result = described_class.from_s3_object(s3_object_data)
      expect(result.record_count).to be_nil
    end
  end

  describe "transform_keys behavior" do
    it "accepts string keys and converts to symbols" do
      string_key_data = {
        "key" => "test.csv.gz",
        "asset_class" => "stocks",
        "data_type" => "trades",
        "date" => "2024-01-15",
        "size" => 1000,
        "last_modified" => nil,
        "etag" => nil,
        "record_count" => nil
      }

      result = described_class.new(string_key_data)
      expect(result.key).to eq("test.csv.gz")
    end
  end
end

RSpec.describe Polymux::Api::FlatFiles::BulkDownloadResult do
  let(:start_time) { Time.parse("2024-01-15T10:00:00Z") }
  let(:end_time) { Time.parse("2024-01-15T10:15:00Z") }
  
  let(:bulk_result) do
    described_class.new(
      total_files: 10,
      successful_files: 8,
      failed_files: 2,
      total_bytes: 850_000_000, # ~810 MB
      duration_seconds: 900.0, # 15 minutes
      successful_downloads: [
        {file: "file1.csv.gz", local_path: "/tmp/file1.csv.gz", size: 100_000_000},
        {file: "file2.csv.gz", local_path: "/tmp/file2.csv.gz", size: 200_000_000}
      ],
      failed_downloads: [
        {file: "file3.csv.gz", error: "Network timeout", retry_count: 3},
        {file: "file4.csv.gz", error: "File not found", retry_count: 0}
      ],
      destination_directory: "/tmp/downloads",
      started_at: start_time,
      completed_at: end_time
    )
  end

  describe ".new" do
    it "creates BulkDownloadResult with all attributes" do
      expect(bulk_result.total_files).to eq(10)
      expect(bulk_result.successful_files).to eq(8)
      expect(bulk_result.failed_files).to eq(2)
      expect(bulk_result.total_bytes).to eq(850_000_000)
      expect(bulk_result.duration_seconds).to eq(900.0)
      expect(bulk_result.destination_directory).to eq("/tmp/downloads")
      expect(bulk_result.started_at).to eq(start_time)
      expect(bulk_result.completed_at).to eq(end_time)
    end

    it "handles arrays of download details" do
      expect(bulk_result.successful_downloads).to be_an(Array)
      expect(bulk_result.successful_downloads.length).to eq(2)
      expect(bulk_result.failed_downloads).to be_an(Array)
      expect(bulk_result.failed_downloads.length).to eq(2)
    end
  end

  describe "#success_rate" do
    it "calculates percentage success rate" do
      expect(bulk_result.success_rate).to eq(80.0) # 8/10 * 100
    end

    it "handles zero files" do
      empty_result = described_class.new(
        total_files: 0,
        successful_files: 0,
        failed_files: 0,
        total_bytes: 0,
        duration_seconds: 0.0,
        successful_downloads: [],
        failed_downloads: [],
        destination_directory: "/tmp",
        started_at: Time.now,
        completed_at: Time.now
      )

      expect(empty_result.success_rate).to eq(0.0)
    end

    it "handles perfect success rate" do
      perfect_result = described_class.new(
        total_files: 5,
        successful_files: 5,
        failed_files: 0,
        total_bytes: 1000,
        duration_seconds: 10.0,
        successful_downloads: [],
        failed_downloads: [],
        destination_directory: "/tmp",
        started_at: Time.now,
        completed_at: Time.now
      )

      expect(perfect_result.success_rate).to eq(100.0)
    end
  end

  describe "#total_size_mb" do
    it "converts bytes to megabytes" do
      expect(bulk_result.total_size_mb).to be_within(0.1).of(810.6) # 850_000_000 / 1_048_576
    end

    it "handles zero bytes" do
      zero_result = described_class.new(
        total_files: 0,
        successful_files: 0,
        failed_files: 0,
        total_bytes: 0,
        duration_seconds: 0.0,
        successful_downloads: [],
        failed_downloads: [],
        destination_directory: "/tmp",
        started_at: Time.now,
        completed_at: Time.now
      )

      expect(zero_result.total_size_mb).to eq(0.0)
    end
  end

  describe "#average_speed_mbps" do
    it "calculates average download speed" do
      # 810.6 MB / 900 seconds ≈ 0.9 MB/s
      expect(bulk_result.average_speed_mbps).to be_within(0.1).of(0.9)
    end

    it "handles zero duration" do
      instant_result = described_class.new(
        total_files: 1,
        successful_files: 1,
        failed_files: 0,
        total_bytes: 1000,
        duration_seconds: 0.0,
        successful_downloads: [],
        failed_downloads: [],
        destination_directory: "/tmp",
        started_at: Time.now,
        completed_at: Time.now
      )

      expect(instant_result.average_speed_mbps).to eq(0.0)
    end
  end

  describe "#success?" do
    it "returns true when all files downloaded successfully" do
      perfect_result = described_class.new(
        total_files: 5,
        successful_files: 5,
        failed_files: 0,
        total_bytes: 1000,
        duration_seconds: 10.0,
        successful_downloads: [],
        failed_downloads: [],
        destination_directory: "/tmp",
        started_at: Time.now,
        completed_at: Time.now
      )

      expect(perfect_result.success?).to be true
    end

    it "returns false when some files failed" do
      expect(bulk_result.success?).to be false
    end
  end

  describe "#partial_failure?" do
    it "returns true when some files succeeded and some failed" do
      expect(bulk_result.partial_failure?).to be true
    end

    it "returns false when all files succeeded" do
      perfect_result = described_class.new(
        total_files: 5,
        successful_files: 5,
        failed_files: 0,
        total_bytes: 1000,
        duration_seconds: 10.0,
        successful_downloads: [],
        failed_downloads: [],
        destination_directory: "/tmp",
        started_at: Time.now,
        completed_at: Time.now
      )

      expect(perfect_result.partial_failure?).to be false
    end

    it "returns false when all files failed" do
      complete_failure = described_class.new(
        total_files: 5,
        successful_files: 0,
        failed_files: 5,
        total_bytes: 0,
        duration_seconds: 10.0,
        successful_downloads: [],
        failed_downloads: [],
        destination_directory: "/tmp",
        started_at: Time.now,
        completed_at: Time.now
      )

      expect(complete_failure.partial_failure?).to be false
    end
  end

  describe "#complete_failure?" do
    it "returns true when no files downloaded successfully" do
      complete_failure = described_class.new(
        total_files: 5,
        successful_files: 0,
        failed_files: 5,
        total_bytes: 0,
        duration_seconds: 10.0,
        successful_downloads: [],
        failed_downloads: [],
        destination_directory: "/tmp",
        started_at: Time.now,
        completed_at: Time.now
      )

      expect(complete_failure.complete_failure?).to be true
    end

    it "returns false when some files succeeded" do
      expect(bulk_result.complete_failure?).to be false
    end
  end

  describe "#summary" do
    it "generates comprehensive summary report" do
      summary = bulk_result.summary

      expect(summary).to include("Bulk Download Summary [PARTIAL]")
      expect(summary).to include("Total Files: 10")
      expect(summary).to include("Successful: 8 (80.0%)")
      expect(summary).to include("Failed: 2")
      expect(summary).to include("810.6 MB") # Total size
      expect(summary).to include("900.0 seconds") # Duration
      expect(summary).to include("0.9 MB/s") # Speed
      expect(summary).to include("/tmp/downloads") # Destination
    end

    it "shows SUCCESS status for perfect downloads" do
      perfect_result = described_class.new(
        total_files: 5,
        successful_files: 5,
        failed_files: 0,
        total_bytes: 1000,
        duration_seconds: 10.0,
        successful_downloads: [],
        failed_downloads: [],
        destination_directory: "/tmp",
        started_at: Time.now,
        completed_at: Time.now
      )

      summary = perfect_result.summary
      expect(summary).to include("Bulk Download Summary [SUCCESS]")
      expect(summary).to include("Successful: 5 (100.0%)")
    end

    it "shows FAILED status for complete failures" do
      complete_failure = described_class.new(
        total_files: 5,
        successful_files: 0,
        failed_files: 5,
        total_bytes: 0,
        duration_seconds: 10.0,
        successful_downloads: [],
        failed_downloads: [],
        destination_directory: "/tmp",
        started_at: Time.now,
        completed_at: Time.now
      )

      summary = complete_failure.summary
      expect(summary).to include("Bulk Download Summary [FAILED]")
      expect(summary).to include("Successful: 0 (0.0%)")
    end
  end
end

RSpec.describe Polymux::Api::FlatFiles::FileMetadata do
  let(:file_info) do
    Polymux::Api::FlatFiles::FileInfo.new(
      key: "stocks/trades/2024/01/15/trades.csv.gz",
      asset_class: "stocks",
      data_type: "trades",
      date: "2024-01-15",
      size: 85_000_000,
      last_modified: Time.parse("2024-01-16T11:00:00.000Z"),
      etag: "a1b2c3d4e5f6"
    )
  end

  let(:metadata) do
    described_class.new(
      file_info: file_info,
      record_count: 850_000,
      ticker_count: 1000,
      first_timestamp: Time.parse("2024-01-15T09:30:00Z"),
      last_timestamp: Time.parse("2024-01-15T16:00:00Z"),
      quality_score: 95,
      top_tickers: ["AAPL", "MSFT", "GOOGL"],
      processed_at: Time.parse("2024-01-16T11:00:00Z"),
      completeness: 99.8,
      checksum: "a1b2c3d4e5f6789012345678901234567890abcdef",
      schema_version: "1.0"
    )
  end

  describe ".new" do
    it "creates FileMetadata with file_info and additional details" do
      expect(metadata.file_info).to eq(file_info)
      expect(metadata.record_count).to eq(850_000)
      expect(metadata.ticker_count).to eq(1000)
      expect(metadata.quality_score).to eq(95)
      expect(metadata.completeness).to eq(99.8)
    end

    it "handles optional attributes" do
      minimal_metadata = described_class.new(file_info: file_info)

      expect(minimal_metadata.record_count).to be_nil
      expect(minimal_metadata.ticker_count).to be_nil
      expect(minimal_metadata.quality_score).to be_nil
    end
  end

  describe "delegated methods" do
    it "delegates file operations to embedded FileInfo" do
      expect(metadata.key).to eq("stocks/trades/2024/01/15/trades.csv.gz")
      expect(metadata.asset_class).to eq("stocks")
      expect(metadata.data_type).to eq("trades")
      expect(metadata.date).to eq("2024-01-15")
      expect(metadata.size).to eq(85_000_000)
      expect(metadata.size_mb).to be_within(0.1).of(81.06)
      expect(metadata.compression).to eq("gzip")
      expect(metadata.suggested_filename).to eq("stocks_trades_2024-01-15.csv.gz")
      expect(metadata.compressed?).to be true
    end
  end

  describe "#records_per_mb" do
    it "calculates data density" do
      # 850_000 records / 81.06 MB ≈ 10_485 records per MB
      expect(metadata.records_per_mb).to be_within(100).of(10_485)
    end

    it "returns nil when record_count is missing" do
      no_records_metadata = described_class.new(file_info: file_info, record_count: nil)
      expect(no_records_metadata.records_per_mb).to be_nil
    end

    it "returns nil when file size is zero" do
      zero_size_info = Polymux::Api::FlatFiles::FileInfo.new(
        key: "test.csv.gz",
        asset_class: "stocks",
        data_type: "trades",
        date: "2024-01-15",
        size: 0
      )
      zero_metadata = described_class.new(file_info: zero_size_info, record_count: 1000)
      expect(zero_metadata.records_per_mb).to be_nil
    end
  end

  describe "#time_span_hours" do
    it "calculates time coverage in hours" do
      # 2024-01-15 09:30:00Z to 16:00:00Z = 6.5 hours
      expect(metadata.time_span_hours).to eq(6.5)
    end

    it "returns nil when timestamps are missing" do
      no_time_metadata = described_class.new(
        file_info: file_info,
        first_timestamp: nil,
        last_timestamp: nil
      )
      expect(no_time_metadata.time_span_hours).to be_nil
    end

    it "handles single timestamp" do
      single_time_metadata = described_class.new(
        file_info: file_info,
        first_timestamp: Time.parse("2024-01-15T09:30:00Z"),
        last_timestamp: nil
      )
      expect(single_time_metadata.time_span_hours).to be_nil
    end
  end

  describe "#high_quality?" do
    it "returns true for high quality data" do
      expect(metadata.high_quality?).to be true
    end

    it "returns false when quality score is too low" do
      low_quality_metadata = described_class.new(
        file_info: file_info,
        quality_score: 85, # Below 90
        completeness: 99.8
      )
      expect(low_quality_metadata.high_quality?).to be false
    end

    it "returns false when completeness is too low" do
      incomplete_metadata = described_class.new(
        file_info: file_info,
        quality_score: 95,
        completeness: 90.0 # Below 95.0
      )
      expect(incomplete_metadata.high_quality?).to be false
    end

    it "returns false when quality metrics are missing" do
      no_quality_metadata = described_class.new(
        file_info: file_info,
        quality_score: nil,
        completeness: nil
      )
      expect(no_quality_metadata.high_quality?).to be false
    end
  end

  describe "#content_type" do
    it "returns CSV content type" do
      expect(metadata.content_type).to eq("text/csv")
    end
  end

  describe "#detailed_report" do
    it "generates comprehensive metadata report" do
      report = metadata.detailed_report

      expect(report).to include("File Metadata Report")
      expect(report).to include("stocks/trades/2024/01/15/trades.csv.gz")
      expect(report).to include("STOCKS") # Uppercase asset class
      expect(report).to include("TRADES") # Uppercase data type
      expect(report).to include("2024-01-15")
      expect(report).to include("81.06 MB") # Size in MB
      expect(report).to include("81,132,813 bytes") # Formatted byte size
      expect(report).to include("GZIP") # Uppercase compression
      expect(report).to include("850,000") # Formatted record count
      expect(report).to include("1,000") # Formatted ticker count
      expect(report).to include("10,485 records/MB") # Data density
      expect(report).to include("95/100") # Quality score
      expect(report).to include("99.8%") # Completeness
      expect(report).to include("HIGH QUALITY") # Quality status
      expect(report).to include("6.5 hours") # Time span
    end

    it "handles missing optional data gracefully" do
      minimal_metadata = described_class.new(
        file_info: file_info,
        record_count: nil,
        quality_score: nil,
        completeness: nil
      )

      report = minimal_metadata.detailed_report

      expect(report).to include("Records: N/A")
      expect(report).to include("Quality Score: N/A/100")
      expect(report).to include("Completeness: N/A%")
      expect(report).to include("Status: STANDARD")
    end

    it "formats large numbers with commas" do
      large_metadata = described_class.new(
        file_info: file_info,
        record_count: 50_000_000,
        ticker_count: 25_000
      )

      report = large_metadata.detailed_report

      expect(report).to include("50,000,000") # Large record count
      expect(report).to include("25,000") # Large ticker count
    end
  end
end

RSpec.describe Polymux::Api::FlatFiles::DataCatalog do
  let(:catalog) do
    described_class.new(
      asset_classes: ["stocks", "options", "crypto", "forex"],
      data_types: ["trades", "quotes", "aggregates"],
      total_files: 15_000,
      coverage_start: Date.new(2020, 1, 1),
      coverage_end: Date.new(2024, 3, 15)
    )
  end

  describe ".new" do
    it "creates DataCatalog with all attributes" do
      expect(catalog.asset_classes).to eq(["stocks", "options", "crypto", "forex"])
      expect(catalog.data_types).to eq(["trades", "quotes", "aggregates"])
      expect(catalog.total_files).to eq(15_000)
      expect(catalog.coverage_start).to eq(Date.new(2020, 1, 1))
      expect(catalog.coverage_end).to eq(Date.new(2024, 3, 15))
    end
  end

  describe "attribute access" do
    it "provides read access to all attributes" do
      expect(catalog).to respond_to(:asset_classes)
      expect(catalog).to respond_to(:data_types)
      expect(catalog).to respond_to(:total_files)
      expect(catalog).to respond_to(:coverage_start)
      expect(catalog).to respond_to(:coverage_end)
    end
  end
end

RSpec.describe Polymux::Api::FlatFiles::FileAvailability do
  describe "when file exists" do
    let(:available_file) do
      described_class.new(
        exists: true,
        reason: nil,
        nearest_available_date: Date.new(2024, 1, 15),
        data_availability_through: Date.new(2024, 3, 15)
      )
    end

    it "creates availability info for existing files" do
      expect(available_file.exists).to be true
      expect(available_file.reason).to be_nil
      expect(available_file.nearest_available_date).to eq(Date.new(2024, 1, 15))
      expect(available_file.data_availability_through).to eq(Date.new(2024, 3, 15))
    end
  end

  describe "when file doesn't exist" do
    let(:unavailable_file) do
      described_class.new(
        exists: false,
        reason: :market_holiday,
        nearest_available_date: Date.new(2024, 12, 24),
        data_availability_through: Date.new(2024, 12, 31)
      )
    end

    it "creates availability info with reason" do
      expect(unavailable_file.exists).to be false
      expect(unavailable_file.reason).to eq(:market_holiday)
      expect(unavailable_file.nearest_available_date).to eq(Date.new(2024, 12, 24))
    end

    it "handles weekend reasons" do
      weekend_file = described_class.new(
        exists: false,
        reason: :weekend,
        nearest_available_date: Date.new(2024, 3, 15)
      )

      expect(weekend_file.reason).to eq(:weekend)
    end

    it "handles future date reasons" do
      future_file = described_class.new(
        exists: false,
        reason: :future_date,
        data_availability_through: Date.today - 1
      )

      expect(future_file.reason).to eq(:future_date)
    end
  end
end

RSpec.describe Polymux::Api::FlatFiles::TradeData do
  let(:mock_trades) do
    [
      OpenStruct.new(ticker: "AAPL", price: 150.25, size: 100, timestamp: Time.now),
      OpenStruct.new(ticker: "MSFT", price: 300.50, size: 200, timestamp: Time.now),
      OpenStruct.new(ticker: "GOOGL", price: 2500.75, size: 50, timestamp: Time.now)
    ]
  end

  let(:trade_data) { described_class.new(trades: mock_trades) }

  describe ".new" do
    it "creates TradeData with trades array" do
      expect(trade_data.trades).to eq(mock_trades)
      expect(trade_data.trades.length).to eq(3)
    end

    it "accepts empty trades array" do
      empty_data = described_class.new(trades: [])
      expect(empty_data.trades).to eq([])
    end
  end

  describe "trades access" do
    it "provides access to individual trades" do
      expect(trade_data.trades.first.ticker).to eq("AAPL")
      expect(trade_data.trades.first.price).to eq(150.25)
    end

    it "supports array operations on trades" do
      tickers = trade_data.trades.map(&:ticker)
      expect(tickers).to eq(["AAPL", "MSFT", "GOOGL"])
    end
  end
end

RSpec.describe Polymux::Api::FlatFiles::AuthenticationResult do
  describe "successful authentication" do
    let(:success_result) do
      described_class.new(
        s3_credentials_valid: true,
        error_details: nil,
        recommended_action: nil
      )
    end

    it "creates result for valid credentials" do
      expect(success_result.s3_credentials_valid).to be true
      expect(success_result.error_details).to be_nil
      expect(success_result.recommended_action).to be_nil
    end
  end

  describe "failed authentication" do
    let(:failure_result) do
      described_class.new(
        s3_credentials_valid: false,
        error_details: "InvalidAccessKeyId",
        recommended_action: "Verify S3 credentials in dashboard"
      )
    end

    it "creates result for invalid credentials" do
      expect(failure_result.s3_credentials_valid).to be false
      expect(failure_result.error_details).to eq("InvalidAccessKeyId")
      expect(failure_result.recommended_action).to eq("Verify S3 credentials in dashboard")
    end
  end
end

RSpec.describe Polymux::Api::FlatFiles::IntegrityReport do
  let(:valid_report) do
    described_class.new(
      checksum_valid: true,
      expected_checksum: "sha256:abc123",
      actual_checksum: "sha256:abc123",
      expected_record_count: 1_000_000,
      actual_record_count: 1_000_000,
      schema_valid: true,
      missing_fields: [],
      invalid_records: [],
      timestamp_continuity: true,
      issues_detected: [],
      recommended_actions: [],
      overall_status: :valid,
      validation_timestamp: Time.now
    )
  end

  let(:invalid_report) do
    described_class.new(
      checksum_valid: false,
      expected_checksum: "sha256:abc123",
      actual_checksum: "sha256:def456",
      expected_record_count: 1_000_000,
      actual_record_count: 999_999,
      schema_valid: false,
      missing_fields: ["timestamp"],
      invalid_records: [{record_id: 1, error: "Invalid price"}],
      timestamp_continuity: false,
      issues_detected: ["Checksum mismatch", "Missing timestamp field"],
      recommended_actions: ["Re-download file", "Check data pipeline"],
      overall_status: :invalid,
      validation_timestamp: Time.now
    )
  end

  describe "valid report" do
    it "creates report for valid data" do
      expect(valid_report.checksum_valid).to be true
      expect(valid_report.expected_record_count).to eq(1_000_000)
      expect(valid_report.actual_record_count).to eq(1_000_000)
      expect(valid_report.schema_valid).to be true
      expect(valid_report.missing_fields).to be_empty
      expect(valid_report.overall_status).to eq(:valid)
    end
  end

  describe "invalid report" do
    it "creates report for corrupted data" do
      expect(invalid_report.checksum_valid).to be false
      expect(invalid_report.expected_checksum).to eq("sha256:abc123")
      expect(invalid_report.actual_checksum).to eq("sha256:def456")
      expect(invalid_report.expected_record_count).to eq(1_000_000)
      expect(invalid_report.actual_record_count).to eq(999_999)
      expect(invalid_report.missing_fields).to include("timestamp")
      expect(invalid_report.issues_detected).to include("Checksum mismatch")
      expect(invalid_report.overall_status).to eq(:invalid)
    end

    it "provides actionable recommendations" do
      expect(invalid_report.recommended_actions).to include("Re-download file")
      expect(invalid_report.recommended_actions).to include("Check data pipeline")
    end
  end

  describe "validation timestamp" do
    it "includes when validation was performed" do
      expect(valid_report.validation_timestamp).to be_a(Time)
      expect(valid_report.validation_timestamp).to be_within(1).of(Time.now)
    end
  end
end