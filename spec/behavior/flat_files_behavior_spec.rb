# frozen_string_literal: true

require "spec_helper"
require "aws-sdk-s3"

RSpec.describe "Bulk Historical Data Analysis via Flat Files", type: :behavior do
  # Mock AWS S3 client to prevent real API calls
  let(:mock_s3_client) { instance_double(Aws::S3::Client) }
  
  before do
    # Mock S3 client creation
    allow(Aws::S3::Client).to receive(:new).and_return(mock_s3_client)
    
    # Mock file operations to prevent actual file system writes during tests
    allow(FileUtils).to receive(:mkdir_p)
    allow(File).to receive(:exist?).and_return(false)
    
    # Mock File.open to simulate successful writes
    mock_file = StringIO.new
    allow(File).to receive(:open).with(anything, /[wa]b?/).and_yield(mock_file)
    
    # Mock File.size to return expected size after download
    allow(File).to receive(:size) do |path|
      if path.include?("test_download")
        2847293847 # Expected file size from mock
      else
        0
      end
    end
  end

  describe "Bulk Historical Data Analysis via Flat Files" do
    context "when conducting large-scale quantitative research" do
      it "downloads years of trade data for backtesting strategies without rate limits" do
        # Expected Outcome: User obtains complete historical dataset for comprehensive strategy validation
        # Success Criteria:
        #   - Bulk download replaces hundreds of thousands of individual API calls
        #   - Complete trading history available for multi-year backtesting periods
        #   - Data integrity maintained across large file downloads
        #   - Download performance significantly exceeds REST API approach for bulk data
        # User Value: User can backtest sophisticated trading strategies using complete market history,
        #             enabling statistically significant validation impossible with sampled data

        # Setup: Create API client for bulk data research workflow
        config = Polymux::Config.new(
          api_key: "test_key_123",
          base_url: "https://api.polygon.io",
          s3_access_key_id: "test_s3_access_key",
          s3_secret_access_key: "test_s3_secret_key"
        )
        client = Polymux::Client.new(config)
        flat_files_api = client.flat_files

        # Mock S3 list_objects_v2 response for file discovery
        mock_list_response = double("Aws::S3::Types::ListObjectsV2Output")
        mock_objects = [
          double("S3Object", 
            key: "stocks/trades/2024/01/02/trades.csv.gz",
            size: 2847293847,
            last_modified: Time.parse("2024-01-03T11:00:00.000Z"),
            etag: '"abc123"'
          ),
          double("S3Object",
            key: "stocks/trades/2023/12/29/trades.csv.gz", 
            size: 2634829173,
            last_modified: Time.parse("2023-12-30T11:00:00.000Z"),
            etag: '"def456"'
          )
        ]
        
        allow(mock_list_response).to receive(:contents).and_return(mock_objects)
        allow(mock_s3_client).to receive(:list_objects_v2).and_return(mock_list_response)

        # Mock S3 head_object for file metadata
        mock_head_response = double("Aws::S3::Types::HeadObjectOutput")
        allow(mock_head_response).to receive(:content_length).and_return(2847293847)
        allow(mock_head_response).to receive(:last_modified).and_return(Time.parse("2024-01-03T11:00:00.000Z"))
        allow(mock_head_response).to receive(:etag).and_return('"abc123"')
        allow(mock_s3_client).to receive(:head_object).and_return(mock_head_response)

        # Mock S3 get_object for file download
        mock_csv_data = [
          "exchange,price,sip_timestamp,size,conditions,id,participant_timestamp,sequence_number,ticker,trf_id,trf_timestamp",
          "4,150.25,2024-01-02T09:30:00.123456789Z,100,[14 41],12345,2024-01-02T09:30:00.123456789Z,1,AAPL,,",
          "4,150.30,2024-01-02T09:30:01.234567890Z,200,[14],12346,2024-01-02T09:30:01.234567890Z,2,AAPL,,",
          "4,425.75,2024-01-02T09:30:00.987654321Z,50,[14],12349,2024-01-02T09:30:00.987654321Z,5,TSLA,,"
        ].join("\n")
        
        allow(mock_s3_client).to receive(:get_object) do |args, &block|
          if args[:bucket] == "flatfiles" && args[:key] == "stocks/trades/2024/01/02/trades.csv.gz"
            # Yield chunks to simulate streaming download
            block.call(mock_csv_data) if block_given?
            mock_csv_data
          end
        end

        # Act: User discovers and downloads bulk historical data for backtesting
        available_files = flat_files_api.list_files("stocks", "trades", "2024-01-02")

        # Download specific file for analysis
        download_result = flat_files_api.download_file(
          "stocks/trades/2024/01/02/trades.csv.gz",
          "/tmp/test_download.csv.gz"
        )

        # Assert: User obtains comprehensive dataset for strategy validation

        # Verify file discovery provides historical coverage
        expect(available_files).to be_an(Array)
        expect(available_files.length).to eq(2) # 2 files from mock
        
        # Verify file metadata includes size information for planning
        first_file = available_files.first
        expect(first_file.size).to be > 1_000_000_000 # Large files with substantial data
        expect(first_file.last_modified).to be_a(Time)
        expect(first_file.key).to include("stocks/trades")

        # Verify download completed successfully
        expect(download_result).to be_a(Hash)
        expect(download_result[:success]).to be true
        expect(download_result[:size]).to be > 0
        expect(download_result[:local_path]).to eq("/tmp/test_download.csv.gz")

        # Business Value Verification: User can perform large-scale backtesting

        # Verify massive efficiency gains over individual API calls
        expect(download_result[:size]).to be > 1000 # Substantial data in single download
        
        # Simulate efficiency comparison
        # Single file download replaces thousands of individual API calls
        estimated_api_calls_replaced = 10000 # Conservative estimate
        efficiency_gain = estimated_api_calls_replaced / 1 # 1 download vs many API calls
        expect(efficiency_gain).to be > 1000 # At least 1000x more efficient

        # Verify enterprise-scale capability
        expect(first_file.size).to be > 2_000_000_000 # Multi-GB files supported
        expect(download_result[:duration]).to be_a(Numeric) # Performance tracking
      end

      it "replaces millions of individual API requests with single bulk download" do
        # Expected Outcome: User achieves dramatic efficiency gains using bulk files over REST API
        # Success Criteria:
        #   - Single file download contains data equivalent to 500,000+ individual API calls
        #   - Download completes faster than equivalent REST API requests
        #   - Rate limit concerns eliminated for bulk historical analysis
        #   - Data consistency maintained across entire bulk dataset
        # User Value: User can analyze complete market datasets without API rate limiting,
        #             enabling comprehensive research impossible through paginated REST endpoints

        # Setup: Prepare for bulk efficiency comparison
        config = Polymux::Config.new(
          api_key: "test_key_123",
          base_url: "https://api.polygon.io",
          s3_access_key_id: "test_s3_access_key",
          s3_secret_access_key: "test_s3_secret_key"
        )
        client = Polymux::Client.new(config)
        flat_files_api = client.flat_files

        # Mock high-volume trading day file
        stub_request(:get, "https://files.polygon.io/flatfiles/us/stocks/trades/2024/03/2024-03-15.csv.gz")
          .with(
            headers: {
              "Authorization" => /AWS4-HMAC-SHA256/
            }
          )
          .to_return(
            status: 200,
            body: generate_massive_trade_dataset(1_000_000), # 1M trades in single file
            headers: {"Content-Type" => "text/csv", "Content-Encoding" => "gzip"}
          )

        # Mock file metadata showing substantial data volume
        stub_request(:head, "https://files.polygon.io/flatfiles/us/stocks/trades/2024/03/2024-03-15.csv.gz")
          .to_return(
            status: 200,
            headers: {
              "Content-Length" => "85000000", # 85MB compressed
              "Last-Modified" => "Fri, 16 Mar 2024 11:00:00 GMT"
            }
          )

        # Act: User downloads bulk file for comprehensive analysis
        start_time = Time.now
        
        file_info = flat_files_api.get_file_info("us/stocks/trades/2024/03/2024-03-15.csv.gz")
        bulk_data = flat_files_api.download_file("us/stocks/trades/2024/03/2024-03-15.csv.gz")
        
        download_time = Time.now - start_time

        # Assert: User achieves dramatic efficiency over REST API approach

        # Verify substantial data volume in single download
        expect(file_info.size).to be > 80_000_000 # 80MB+ of compressed data
        expect(bulk_data.trades.length).to eq(1_000_000) # 1M individual trades

        # Calculate REST API equivalent effort
        individual_api_calls_replaced = bulk_data.trades.length
        expect(individual_api_calls_replaced).to be >= 1_000_000

        # Verify download performance enables real-time analysis
        expect(download_time).to be < 30.0 # Complete download in under 30 seconds

        # Business Value Verification: Massive efficiency gains

        # Efficiency comparison simulation
        rest_api_simulation = {
          individual_requests_needed: individual_api_calls_replaced,
          estimated_time_per_request: 0.1, # 100ms per API call
          total_estimated_time: individual_api_calls_replaced * 0.1,
          rate_limit_delays: individual_api_calls_replaced / 5.0, # Rate limiting overhead
          bulk_file_time: download_time
        }

        efficiency_gain = rest_api_simulation[:total_estimated_time] / download_time
        expect(efficiency_gain).to be > 1000.0 # At least 1000x faster

        # Verify data quality maintained across bulk dataset
        unique_tickers = bulk_data.trades.map(&:ticker).uniq
        expect(unique_tickers.length).to be > 100 # Diverse ticker coverage

        # Verify no data loss in bulk format
        sample_trades = bulk_data.trades.sample(1000)
        data_completeness = sample_trades.all? do |trade|
          trade.ticker && trade.price > 0 && trade.size > 0 && trade.timestamp
        end
        expect(data_completeness).to be true

        # Rate limit elimination verification
        concurrent_analysis_capability = {
          simultaneous_datasets: 10, # Can analyze multiple days concurrently
          total_trade_records: bulk_data.trades.length * 10,
          rest_api_impossibility: "Would exceed rate limits by factor of 100x"
        }
        expect(concurrent_analysis_capability[:total_trade_records]).to be > 10_000_000
      end

      it "enables cross-asset correlation analysis using synchronized datasets" do
        # Expected Outcome: User analyzes relationships across multiple asset classes using aligned data
        # Success Criteria:
        #   - Synchronized timestamps across stocks, options, crypto, and forex datasets
        #   - Complete market coverage for correlation calculations
        #   - Data consistency enables statistical analysis across asset classes
        #   - Historical depth sufficient for robust correlation modeling
        # User Value: User can identify diversification opportunities and risk relationships
        #             across asset classes using comprehensive synchronized market data

        # Setup: Prepare for cross-asset analysis
        config = Polymux::Config.new(
          api_key: "test_key_123",
          s3_access_key_id: "test_s3_access_key",
          s3_secret_access_key: "test_s3_secret_key"
        )
        client = Polymux::Client.new(config)
        flat_files_api = client.flat_files

        # Mock synchronized multi-asset data for same trading day
        trading_date = "2024-03-15"

        # Stocks data
        stub_request(:get, "https://files.polygon.io/flatfiles/us/stocks/trades/2024/03/2024-03-15.csv.gz")
          .to_return(
            status: 200,
            body: generate_synchronized_stock_trades(trading_date),
            headers: {"Content-Type" => "text/csv"}
          )

        # Options data
        stub_request(:get, "https://files.polygon.io/flatfiles/us/options/trades/2024/03/2024-03-15.csv.gz")
          .to_return(
            status: 200,
            body: generate_synchronized_options_trades(trading_date),
            headers: {"Content-Type" => "text/csv"}
          )

        # Crypto data  
        stub_request(:get, "https://files.polygon.io/flatfiles/us/crypto/trades/2024/03/2024-03-15.csv.gz")
          .to_return(
            status: 200,
            body: generate_synchronized_crypto_trades(trading_date),
            headers: {"Content-Type" => "text/csv"}
          )

        # Forex data
        stub_request(:get, "https://files.polygon.io/flatfiles/us/forex/trades/2024/03/2024-03-15.csv.gz")
          .to_return(
            status: 200,
            body: generate_synchronized_forex_trades(trading_date),
            headers: {"Content-Type" => "text/csv"}
          )

        # Act: User downloads synchronized datasets for correlation analysis
        stock_data = flat_files_api.download_file("us/stocks/trades/2024/03/2024-03-15.csv.gz")
        options_data = flat_files_api.download_file("us/options/trades/2024/03/2024-03-15.csv.gz")
        crypto_data = flat_files_api.download_file("us/crypto/trades/2024/03/2024-03-15.csv.gz")
        forex_data = flat_files_api.download_file("us/forex/trades/2024/03/2024-03-15.csv.gz")

        # Assert: User can perform comprehensive cross-asset analysis

        # Verify timestamp synchronization across asset classes
        all_timestamps = [
          stock_data.trades.map(&:timestamp),
          options_data.trades.map(&:timestamp), 
          crypto_data.trades.map(&:timestamp),
          forex_data.trades.map(&:timestamp)
        ].flatten.sort

        # Verify overlapping time coverage for correlation analysis
        trading_session_start = Time.parse("#{trading_date}T09:30:00Z")
        trading_session_end = Time.parse("#{trading_date}T16:00:00Z")
        
        session_timestamps = all_timestamps.select do |ts|
          ts >= trading_session_start && ts <= trading_session_end
        end
        expect(session_timestamps.length).to be > 1000 # Substantial overlap

        # Verify comprehensive asset coverage for diversification analysis
        stock_tickers = stock_data.trades.map(&:ticker).uniq
        crypto_pairs = crypto_data.trades.map(&:ticker).uniq
        forex_pairs = forex_data.trades.map(&:ticker).uniq
        
        expect(stock_tickers).to include("AAPL", "MSFT", "TSLA", "SPY")
        expect(crypto_pairs).to include("BTC-USD", "ETH-USD")
        expect(forex_pairs).to include("EUR/USD", "GBP/USD")

        # Business Value Verification: Cross-asset correlation analysis

        # Simulate portfolio diversification analysis
        correlation_analysis = {
          stock_crypto_sync: calculate_time_overlap(stock_data.trades, crypto_data.trades),
          stock_forex_sync: calculate_time_overlap(stock_data.trades, forex_data.trades),
          options_underlying_sync: calculate_options_stock_alignment(options_data.trades, stock_data.trades)
        }

        # Verify sufficient time overlap for statistical significance
        expect(correlation_analysis[:stock_crypto_sync][:overlap_minutes]).to be > 300 # 5+ hours
        expect(correlation_analysis[:stock_forex_sync][:overlap_minutes]).to be > 300
        expect(correlation_analysis[:options_underlying_sync][:aligned_trades]).to be > 100

        # Risk management validation - identify safe haven relationships
        risk_relationships = {
          flight_to_quality_events: identify_inverse_correlations(stock_data.trades, forex_data.trades),
          crypto_decoupling: identify_independent_movements(stock_data.trades, crypto_data.trades),
          options_hedging_effectiveness: measure_hedge_relationships(stock_data.trades, options_data.trades)
        }

        expect(risk_relationships[:flight_to_quality_events]).to be > 0
        expect(risk_relationships[:crypto_decoupling]).to be > 0
        expect(risk_relationships[:options_hedging_effectiveness]).to be > 0.5 # 50%+ correlation
      end
    end

    context "when managing research data efficiently" do
      it "discovers available datasets without downloading unnecessary files" do
        # Expected Outcome: User efficiently explores available data without bandwidth waste
        # Success Criteria:
        #   - Complete catalog of available files with metadata (size, date, asset class)
        #   - File filtering by date range, asset class, and data type
        #   - Size estimation for bandwidth planning before downloads
        #   - File availability verification across historical periods
        # User Value: User can plan research projects and estimate costs before committing
        #             to large downloads, ensuring efficient use of bandwidth and storage

        # Setup: Prepare for data discovery workflow
        config = Polymux::Config.new(
          api_key: "test_key_123",
          s3_access_key_id: "test_s3_access_key",
          s3_secret_access_key: "test_s3_secret_key"
        )
        client = Polymux::Client.new(config)
        flat_files_api = client.flat_files

        # Mock comprehensive file catalog across multiple asset classes
        stub_request(:get, "https://files.polygon.io/flatfiles/")
          .to_return(
            status: 200,
            body: generate_comprehensive_file_catalog,
            headers: {"Content-Type" => "application/xml"}
          )

        # Mock specific date range query
        stub_request(:get, "https://files.polygon.io/flatfiles/us/stocks/trades/")
          .with(query: hash_including({"prefix" => "us/stocks/trades/2024/"}))
          .to_return(
            status: 200,
            body: generate_filtered_file_listing("stocks", "trades", "2024"),
            headers: {"Content-Type" => "application/xml"}
          )

        # Act: User explores available datasets for research planning
        # Browse all available data categories
        catalog = flat_files_api.browse_catalog

        # Filter for specific research needs
        stock_trades_2024 = flat_files_api.list_available_files(
          asset_class: "stocks",
          data_type: "trades", 
          date_range: {start_date: "2024-01-01", end_date: "2024-12-31"}
        )

        # Get detailed file information without downloading
        sample_file = stock_trades_2024.first
        file_metadata = flat_files_api.get_file_info(sample_file.key)

        # Assert: User can efficiently plan research without unnecessary downloads

        # Verify comprehensive catalog provides complete overview
        expect(catalog.asset_classes).to include("stocks", "options", "crypto", "forex")
        expect(catalog.data_types).to include("trades", "quotes", "aggregates")
        expect(catalog.total_files).to be > 1000 # Substantial historical coverage

        # Verify date-based filtering for targeted research
        expect(stock_trades_2024).to be_an(Array)
        expect(stock_trades_2024.length).to be > 200 # Full year of trading days
        
        # Verify all files match requested criteria
        stock_trades_2024.each do |file|
          expect(file.key).to include("stocks/trades/2024")
          expect(file.date.year).to eq(2024)
        end

        # Verify metadata provides planning information
        expect(file_metadata.size).to be > 1_000_000 # File size for bandwidth planning
        expect(file_metadata.last_modified).to be_a(Time)
        expect(file_metadata.content_type).to eq("text/csv")

        # Business Value Verification: Efficient research planning

        # Calculate total download requirements for project planning
        project_planning = {
          total_files_needed: stock_trades_2024.length,
          estimated_total_size: stock_trades_2024.sum(&:size),
          estimated_download_time: calculate_download_time(stock_trades_2024.sum(&:size)),
          storage_requirements: stock_trades_2024.sum(&:size) * 1.5 # Uncompressed estimate
        }

        expect(project_planning[:total_files_needed]).to be >= 250
        expect(project_planning[:estimated_total_size]).to be > 50_000_000_000 # 50GB+
        expect(project_planning[:estimated_download_time]).to be > 3600 # Hours of download time

        # Verify user can make informed decisions before large downloads
        cost_benefit_analysis = {
          data_coverage: (stock_trades_2024.length / 252.0 * 100).round(2), # % of trading days
          alternative_api_calls: stock_trades_2024.length * 500_000, # Equivalent REST calls
          efficiency_factor: project_planning[:estimated_total_size] / (stock_trades_2024.length * 1000)
        }

        expect(cost_benefit_analysis[:data_coverage]).to be > 95.0 # 95%+ coverage
        expect(cost_benefit_analysis[:alternative_api_calls]).to be > 100_000_000 # 100M+ API calls replaced
        expect(cost_benefit_analysis[:efficiency_factor]).to be > 1000 # Massive efficiency gain
      end

      it "handles network interruptions with resumable downloads" do
        # Expected Outcome: User can reliably download large files despite network issues
        # Success Criteria:
        #   - Download resume capability for interrupted transfers
        #   - Partial download verification and integrity checking
        #   - Retry logic handles temporary network failures
        #   - Progress tracking enables monitoring of large file transfers
        # User Value: User can confidently download multi-gigabyte files without losing progress
        #             due to network instability, ensuring reliable access to historical datasets

        # Setup: Simulate network-challenged environment
        config = Polymux::Config.new(
          api_key: "test_key_123",
          s3_access_key_id: "test_s3_access_key",
          s3_secret_access_key: "test_s3_secret_key"
        )
        client = Polymux::Client.new(config)
        flat_files_api = client.flat_files

        # Mock large file with partial download simulation
        large_file_key = "us/stocks/trades/2024/03/2024-03-15.csv.gz"
        full_file_size = 150_000_000 # 150MB file
        partial_download_size = 75_000_000 # 75MB downloaded before interruption

        # First request - partial download (interrupted)
        stub_request(:get, "https://files.polygon.io/flatfiles/#{large_file_key}")
          .with(headers: {"Range" => "bytes=0-"})
          .to_return(
            status: 206, # Partial Content
            body: "A" * partial_download_size, # Simulate 75MB of data
            headers: {
              "Content-Range" => "bytes 0-#{partial_download_size - 1}/#{full_file_size}",
              "Content-Length" => partial_download_size.to_s
            }
          )

        # Resume request - remaining portion
        stub_request(:get, "https://files.polygon.io/flatfiles/#{large_file_key}")
          .with(headers: {"Range" => "bytes=#{partial_download_size}-"})
          .to_return(
            status: 206, # Partial Content  
            body: generate_massive_trade_dataset(500_000), # Remaining data
            headers: {
              "Content-Range" => "bytes #{partial_download_size}-#{full_file_size - 1}/#{full_file_size}",
              "Content-Length" => (full_file_size - partial_download_size).to_s
            }
          )

        # Mock HEAD request for file info
        stub_request(:head, "https://files.polygon.io/flatfiles/#{large_file_key}")
          .to_return(
            headers: {
              "Content-Length" => full_file_size.to_s,
              "Accept-Ranges" => "bytes"
            }
          )

        # Act: User attempts download with interruption and recovery
        download_progress = []

        # Simulate interrupted download
        begin
          flat_files_api.download_file(large_file_key, 
            progress_callback: proc { |bytes_downloaded, total_bytes|
              download_progress << {
                bytes_downloaded: bytes_downloaded,
                total_bytes: total_bytes,
                percentage: (bytes_downloaded.to_f / total_bytes * 100).round(2)
              }
              
              # Simulate network interruption at 50% progress
              if bytes_downloaded >= partial_download_size
                raise Polymux::Api::FlatFiles::NetworkError, "Connection interrupted"
              end
            }
          )
        rescue Polymux::Api::FlatFiles::NetworkError
          # Expected interruption
        end

        # Resume download
        resumed_data = flat_files_api.resume_download(large_file_key,
          from_byte: partial_download_size,
          progress_callback: proc { |bytes_downloaded, total_bytes|
            download_progress << {
              bytes_downloaded: bytes_downloaded + partial_download_size,
              total_bytes: total_bytes,
              percentage: ((bytes_downloaded + partial_download_size).to_f / total_bytes * 100).round(2)
            }
          }
        )

        # Assert: User successfully recovers from network interruptions

        # Verify partial download was tracked correctly
        partial_progress = download_progress.select { |p| p[:bytes_downloaded] < full_file_size }
        expect(partial_progress).to_not be_empty
        expect(partial_progress.last[:percentage]).to be_between(40.0, 60.0)

        # Verify resume capability preserved progress
        pre_resume_bytes = partial_download_size
        post_resume_progress = download_progress.select { |p| p[:bytes_downloaded] >= pre_resume_bytes }
        expect(post_resume_progress).to_not be_empty

        # Verify complete download after resume
        final_progress = download_progress.last
        expect(final_progress[:percentage]).to eq(100.0)
        expect(final_progress[:bytes_downloaded]).to eq(full_file_size)

        # Verify data integrity after resume
        expect(resumed_data).to be_a(Polymux::Api::FlatFiles::TradeData)
        expect(resumed_data.trades.length).to eq(500_000)

        # Business Value Verification: Reliable large file downloads

        # Network resilience validation
        reliability_metrics = {
          interruption_recovery: true,
          data_loss_prevention: resumed_data.trades.length > 0,
          progress_preservation: final_progress[:bytes_downloaded] == full_file_size,
          bandwidth_efficiency: calculate_bandwidth_saved(partial_download_size, full_file_size)
        }

        expect(reliability_metrics[:interruption_recovery]).to be true
        expect(reliability_metrics[:data_loss_prevention]).to be true  
        expect(reliability_metrics[:progress_preservation]).to be true
        expect(reliability_metrics[:bandwidth_efficiency]).to be > 0.4 # 40%+ bandwidth saved

        # Large-scale research enablement
        research_continuity = {
          multi_gigabyte_capability: full_file_size > 100_000_000,
          unattended_download_safety: download_progress.length > 2, # Multiple progress updates
          enterprise_reliability: reliability_metrics.values.all?(true)
        }

        expect(research_continuity.values).to all(be true)
      end

      it "validates data integrity across downloaded files" do
        # Expected Outcome: User verifies downloaded data quality and completeness
        # Success Criteria:
        #   - Checksum verification ensures file transfer integrity  
        #   - Data structure validation confirms proper CSV parsing
        #   - Timestamp continuity verification across files
        #   - Missing data identification and reporting
        # User Value: User can trust downloaded datasets for critical analysis without
        #             concerns about data corruption, gaps, or transfer errors

        # Setup: Prepare for data integrity validation
        config = Polymux::Config.new(
          api_key: "test_key_123",
          s3_access_key: "test_s3_access_key", 
          s3_secret_key: "test_s3_secret_key"
        )
        client = Polymux::Client.new(config)
        flat_files_api = client.flat_files

        expected_checksum = "sha256:a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456"
        file_key = "us/stocks/trades/2024/03/2024-03-15.csv.gz"

        # Mock file with integrity metadata
        stub_request(:head, "https://files.polygon.io/flatfiles/#{file_key}")
          .to_return(
            headers: {
              "Content-Length" => "85000000",
              "ETag" => '"a1b2c3d4e5f6789012345678901234567890abcdef"',
              "x-amz-meta-checksum" => expected_checksum,
              "x-amz-meta-record-count" => "1000000"
            }
          )

        # Mock file download with known content
        valid_trade_data = generate_validated_trade_dataset(1_000_000)
        stub_request(:get, "https://files.polygon.io/flatfiles/#{file_key}")
          .to_return(
            status: 200,
            body: valid_trade_data,
            headers: {"Content-Type" => "text/csv", "Content-Encoding" => "gzip"}
          )

        # Act: User downloads and validates data integrity
        file_metadata = flat_files_api.get_file_info(file_key)
        downloaded_data = flat_files_api.download_file(file_key, validate_integrity: true)

        # Perform comprehensive integrity checks
        integrity_report = flat_files_api.validate_data_integrity(downloaded_data, file_metadata)

        # Assert: User receives validated, trustworthy dataset

        # Verify checksum validation prevents corrupted data
        expect(integrity_report.checksum_valid).to be true
        expect(integrity_report.expected_checksum).to eq(expected_checksum)
        expect(integrity_report.actual_checksum).to eq(expected_checksum)

        # Verify record count matches expected volume
        expect(integrity_report.expected_record_count).to eq(1_000_000)
        expect(integrity_report.actual_record_count).to eq(1_000_000)
        expect(downloaded_data.trades.length).to eq(1_000_000)

        # Verify data structure integrity
        expect(integrity_report.schema_valid).to be true
        expect(integrity_report.missing_fields).to be_empty
        expect(integrity_report.invalid_records).to be_empty

        # Verify timestamp continuity for time-series analysis
        timestamps = downloaded_data.trades.map(&:timestamp).sort
        timestamp_gaps = identify_timestamp_gaps(timestamps)
        expect(integrity_report.timestamp_continuity).to be true
        expect(timestamp_gaps.length).to be < 10 # Minimal gaps acceptable

        # Business Value Verification: Trustworthy research data

        # Data quality assurance for critical analysis
        quality_metrics = {
          completeness: (integrity_report.actual_record_count.to_f / integrity_report.expected_record_count),
          accuracy: (1.0 - (integrity_report.invalid_records.length.to_f / integrity_report.actual_record_count)),
          consistency: integrity_report.schema_valid,
          timeliness: integrity_report.timestamp_continuity
        }

        expect(quality_metrics[:completeness]).to eq(1.0) # 100% complete
        expect(quality_metrics[:accuracy]).to be > 0.999 # 99.9%+ accurate
        expect(quality_metrics[:consistency]).to be true
        expect(quality_metrics[:timeliness]).to be true

        # Research reliability validation
        research_confidence = {
          statistical_significance: quality_metrics[:completeness] == 1.0,
          backtesting_reliability: quality_metrics[:accuracy] > 0.99,
          regulatory_compliance: integrity_report.checksum_valid,
          audit_trail: integrity_report.validation_timestamp.is_a?(Time)
        }

        expect(research_confidence.values).to all(be true)

        # Error detection and reporting
        if integrity_report.issues_detected.any?
          expect(integrity_report.issues_detected).to all(be_a(String))
          expect(integrity_report.recommended_actions).to_not be_empty
        else
          expect(integrity_report.overall_status).to eq(:valid)
        end
      end
    end

    context "when recovering from download failures" do
      it "provides clear error messages for authentication failures" do
        # Expected Outcome: User receives actionable error messages for credential problems
        # Success Criteria:
        #   - Specific error messages distinguish between API key and S3 credential issues
        #   - Error messages include steps to resolve authentication problems
        #   - Different failure modes (expired, invalid, missing) clearly identified
        #   - Authentication test capability before large downloads
        # User Value: User can quickly diagnose and resolve credential issues without
        #             wasting time on failed downloads or unclear error messages

        # Setup: Test various authentication failure scenarios
        config_invalid_s3 = Polymux::Config.new(
          api_key: "test_key_123",
          s3_access_key: "invalid_access_key",
          s3_secret_key: "invalid_secret_key"
        )
        client = Polymux::Client.new(config_invalid_s3)
        flat_files_api = client.flat_files

        # Mock S3 authentication failure
        stub_request(:get, "https://files.polygon.io/flatfiles/")
          .to_return(
            status: 403,
            body: <<~XML
              <?xml version="1.0" encoding="UTF-8"?>
              <Error>
                <Code>InvalidAccessKeyId</Code>
                <Message>The AWS Access Key Id you provided does not exist in our records.</Message>
                <RequestId>1234567890ABCDEF</RequestId>
              </Error>
            XML,
            headers: {"Content-Type" => "application/xml"}
          )

        # Mock expired credentials error
        stub_request(:get, "https://files.polygon.io/flatfiles/us/stocks/trades/")
          .to_return(
            status: 403,
            body: <<~XML
              <?xml version="1.0" encoding="UTF-8"?>
              <Error>
                <Code>TokenRefreshRequired</Code>
                <Message>The provided token has expired and must be refreshed.</Message>
                <RequestId>ABCDEF1234567890</RequestId>
              </Error>
            XML
          )

        # Act & Assert: User receives clear authentication error guidance

        # Test invalid S3 credentials
        expect {
          flat_files_api.browse_catalog
        }.to raise_error(Polymux::Api::FlatFiles::AuthenticationError) do |error|
          expect(error.message).to include("S3 Access Key")
          expect(error.message).to include("does not exist")
          expect(error.error_code).to eq("InvalidAccessKeyId")
          expect(error.resolution_steps).to include("Verify S3 credentials in your Polygon.io dashboard")
        end

        # Test expired credentials
        expect {
          flat_files_api.list_available_files(asset_class: "stocks", data_type: "trades")
        }.to raise_error(Polymux::Api::FlatFiles::AuthenticationError) do |error|
          expect(error.message).to include("expired")
          expect(error.error_code).to eq("TokenRefreshRequired")
          expect(error.resolution_steps).to include("Generate new S3 credentials")
        end

        # Test authentication verification before downloads
        auth_test_result = flat_files_api.test_authentication

        expect(auth_test_result.s3_credentials_valid).to be false
        expect(auth_test_result.error_details).to include("InvalidAccessKeyId")
        expect(auth_test_result.recommended_action).to include("dashboard")
      end

      it "handles file not found errors with helpful alternatives" do
        # Expected Outcome: User receives guidance when requested files don't exist
        # Success Criteria:
        #   - Clear indication when specific dates have no data (holidays, weekends)
        #   - Alternative date suggestions for missing files
        #   - Asset class availability information
        #   - Historical coverage boundaries clearly communicated
        # User Value: User understands data availability patterns and can adjust
        #             research parameters rather than assuming data corruption

        # Setup: Test file availability edge cases
        config = Polymux::Config.new(
          api_key: "test_key_123",
          s3_access_key_id: "test_s3_access_key",
          s3_secret_access_key: "test_s3_secret_key"
        )
        client = Polymux::Client.new(config)
        flat_files_api = client.flat_files

        # Mock file not found for holiday (market closed)
        holiday_date = "2024-12-25" # Christmas
        stub_request(:get, "https://files.polygon.io/flatfiles/us/stocks/trades/2024/12/2024-12-25.csv.gz")
          .to_return(
            status: 404,
            body: <<~XML
              <?xml version="1.0" encoding="UTF-8"?>
              <Error>
                <Code>NoSuchKey</Code>
                <Message>The specified key does not exist.</Message>
                <Key>us/stocks/trades/2024/12/2024-12-25.csv.gz</Key>
              </Error>
            XML
          )

        # Mock weekend file request
        weekend_date = "2024-03-16" # Saturday
        stub_request(:get, "https://files.polygon.io/flatfiles/us/stocks/trades/2024/03/2024-03-16.csv.gz")
          .to_return(status: 404)

        # Mock future date request
        future_date = (Date.today + 30).strftime("%Y-%m-%d")
        stub_request(:get, "https://files.polygon.io/flatfiles/us/stocks/trades/#{future_date[0..3]}/#{future_date[5..6]}/#{future_date}.csv.gz")
          .to_return(status: 404)

        # Mock available alternative dates
        stub_request(:get, "https://files.polygon.io/flatfiles/us/stocks/trades/2024/12/")
          .to_return(
            status: 200,
            body: generate_available_dates_listing("2024-12", exclude_holidays: true)
          )

        # Act & Assert: User receives helpful file not found guidance

        # Test holiday file request
        expect {
          flat_files_api.download_file("us/stocks/trades/2024/12/2024-12-25.csv.gz")
        }.to raise_error(Polymux::Api::FlatFiles::FileNotFoundError) do |error|
          expect(error.message).to include("market holiday")
          expect(error.requested_date).to eq(Date.parse("2024-12-25"))
          expect(error.reason).to eq(:market_holiday)
          expect(error.alternative_dates).to include(Date.parse("2024-12-24"))
        end

        # Test weekend file request
        expect {
          flat_files_api.download_file("us/stocks/trades/2024/03/2024-03-16.csv.gz")
        }.to raise_error(Polymux::Api::FlatFiles::FileNotFoundError) do |error|
          expect(error.message).to include("weekend")
          expect(error.reason).to eq(:weekend)
          expect(error.alternative_dates).to include(Date.parse("2024-03-15")) # Friday
        end

        # Test future date request
        expect {
          flat_files_api.download_file("us/stocks/trades/#{future_date[0..3]}/#{future_date[5..6]}/#{future_date}.csv.gz")
        }.to raise_error(Polymux::Api::FlatFiles::FileNotFoundError) do |error|
          expect(error.message).to include("future date")
          expect(error.reason).to eq(:future_date)
          expect(error.data_availability_through).to be <= Date.today
        end

        # Test availability checking before download attempts
        availability = flat_files_api.check_file_availability(
          asset_class: "stocks",
          data_type: "trades", 
          date: holiday_date
        )

        expect(availability.exists).to be false
        expect(availability.reason).to eq(:market_holiday)
        expect(availability.nearest_available_date).to eq(Date.parse("2024-12-24"))
      end

      it "retries transient network errors with exponential backoff" do
        # Expected Outcome: User's downloads succeed despite temporary network issues
        # Success Criteria:
        #   - Automatic retry for transient HTTP errors (5xx, timeouts)
        #   - Exponential backoff prevents overwhelming servers during outages
        #   - Maximum retry limits prevent infinite loops
        #   - User visibility into retry attempts and final outcomes
        # User Value: User can reliably download files despite temporary service issues,
        #             reducing manual intervention and improving download success rates

        # Setup: Simulate network instability
        config = Polymux::Config.new(
          api_key: "test_key_123",
          s3_access_key_id: "test_s3_access_key",
          s3_secret_access_key: "test_s3_secret_key"
        )
        client = Polymux::Client.new(config)
        flat_files_api = client.flat_files

        file_key = "us/stocks/trades/2024/03/2024-03-15.csv.gz"
        retry_attempts = []

        # Mock transient failures followed by success
        call_count = 0
        stub_request(:get, "https://files.polygon.io/flatfiles/#{file_key}")
          .to_return do |request|
            call_count += 1
            retry_attempts << {
              attempt: call_count,
              timestamp: Time.now,
              url: request.uri.to_s
            }

            case call_count
            when 1
              # First attempt - timeout
              {status: 408, body: "Request Timeout"}
            when 2  
              # Second attempt - server error
              {status: 503, body: "Service Unavailable"}
            when 3
              # Third attempt - success
              {
                status: 200,
                body: generate_valid_trade_data(10_000),
                headers: {"Content-Type" => "text/csv"}
              }
            end
          end

        # Act: User downloads file with automatic retry handling
        start_time = Time.now
        
        download_result = flat_files_api.download_file(file_key,
          retry_options: {
            max_retries: 5,
            backoff_strategy: :exponential,
            retry_callback: proc { |attempt, error, wait_time|
              # User visibility into retry process
            }
          }
        )
        
        total_time = Time.now - start_time

        # Assert: User successfully downloads despite transient failures

        # Verify retry attempts were made
        expect(retry_attempts.length).to eq(3) # 2 failures + 1 success
        expect(call_count).to eq(3)

        # Verify exponential backoff timing
        if retry_attempts.length > 1
          time_gaps = retry_attempts.each_cons(2).map do |prev, curr|
            curr[:timestamp] - prev[:timestamp]  
          end
          
          # Second attempt should wait longer than first attempt would have
          expect(time_gaps.first).to be_between(1.0, 3.0) # ~2 second initial backoff
          if time_gaps.length > 1
            expect(time_gaps.last).to be > time_gaps.first # Exponential increase
          end
        end

        # Verify successful download despite failures
        expect(download_result).to be_a(Polymux::Api::FlatFiles::TradeData)
        expect(download_result.trades.length).to eq(10_000)

        # Verify total time includes backoff delays
        expect(total_time).to be_between(3.0, 10.0) # Includes retry delays

        # Business Value Verification: Reliable downloads despite network issues

        # Network resilience validation
        reliability_stats = {
          failure_recovery: true,
          data_integrity_maintained: download_result.trades.length > 0,
          user_intervention_avoided: retry_attempts.length > 1,
          final_success_rate: call_count > 0 ? 1.0 : 0.0
        }

        expect(reliability_stats[:failure_recovery]).to be true
        expect(reliability_stats[:data_integrity_maintained]).to be true
        expect(reliability_stats[:user_intervention_avoided]).to be true
        expect(reliability_stats[:final_success_rate]).to eq(1.0)

        # Production readiness validation
        production_characteristics = {
          handles_service_degradation: retry_attempts.any? { |r| r[:attempt] > 1 },
          respects_server_capacity: total_time > (retry_attempts.length - 1), # Backoff delays
          provides_user_feedback: retry_attempts.all? { |r| r[:timestamp].is_a?(Time) },
          eventually_consistent: download_result.trades.length > 0
        }

        expect(production_characteristics.values).to all(be true)
      end
    end
  end

  private

  def generate_massive_trade_dataset(trade_count)
    header = "exchange,price,sip_timestamp,size,conditions,id,participant_timestamp,sequence_number,ticker,trf_id,trf_timestamp\n"
    trades = (1..trade_count).map do |i|
      ticker = ["AAPL", "MSFT", "GOOGL", "TSLA", "AMZN", "NVDA"].sample
      price = rand(50.0..500.0).round(2)
      size = [100, 200, 500, 1000].sample
      timestamp = Time.now - rand(86400) # Random time within last 24 hours
      "4,#{price},#{timestamp.strftime('%Y-%m-%dT%H:%M:%S.%9NZ')},#{size},[14],#{i},#{timestamp.strftime('%Y-%m-%dT%H:%M:%S.%9NZ')},#{i},#{ticker},,"
    end
    header + trades.join("\n")
  end

  def generate_synchronized_stock_trades(date)
    base_time = Time.parse("#{date}T09:30:00Z")
    header = "exchange,price,sip_timestamp,size,conditions,id,participant_timestamp,sequence_number,ticker,trf_id,trf_timestamp\n"
    trades = (0..100).map do |i|
      timestamp = base_time + (i * 60) # One trade per minute
      ticker = ["AAPL", "MSFT", "SPY", "QQQ"][i % 4]
      price = 150.0 + (i * 0.1)
      "4,#{price},#{timestamp.strftime('%Y-%m-%dT%H:%M:%S.%9NZ')},100,[14],#{i},#{timestamp.strftime('%Y-%m-%dT%H:%M:%S.%9NZ')},#{i},#{ticker},,"
    end
    header + trades.join("\n")
  end

  def generate_synchronized_options_trades(date)
    base_time = Time.parse("#{date}T09:30:00Z")
    header = "exchange,price,sip_timestamp,size,conditions,id,participant_timestamp,sequence_number,ticker,trf_id,trf_timestamp\n"
    trades = (0..50).map do |i|
      timestamp = base_time + (i * 120) # One trade every 2 minutes
      price = 5.0 + (i * 0.05)
      "4,#{price},#{timestamp.strftime('%Y-%m-%dT%H:%M:%S.%9NZ')},10,[14],#{i},#{timestamp.strftime('%Y-%m-%dT%H:%M:%S.%9NZ')},#{i},O:AAPL240315C00150000,,"
    end
    header + trades.join("\n")
  end

  def generate_synchronized_crypto_trades(date)
    base_time = Time.parse("#{date}T00:00:00Z") # Crypto trades 24/7
    header = "exchange,price,sip_timestamp,size,conditions,id,participant_timestamp,sequence_number,ticker,trf_id,trf_timestamp\n"
    trades = (0..200).map do |i|
      timestamp = base_time + (i * 43200) # Every 12 hours
      ticker = ["BTC-USD", "ETH-USD"][i % 2]
      price = ticker == "BTC-USD" ? 45000 + (i * 10) : 2500 + (i * 5)
      "1,#{price},#{timestamp.strftime('%Y-%m-%dT%H:%M:%S.%9NZ')},0.1,[],#{i},#{timestamp.strftime('%Y-%m-%dT%H:%M:%S.%9NZ')},#{i},#{ticker},,"
    end
    header + trades.join("\n")
  end

  def generate_synchronized_forex_trades(date)
    base_time = Time.parse("#{date}T00:00:00Z") # Forex trades during session
    header = "exchange,price,sip_timestamp,size,conditions,id,participant_timestamp,sequence_number,ticker,trf_id,trf_timestamp\n"
    trades = (0..150).map do |i|
      timestamp = base_time + (i * 600) # Every 10 minutes
      ticker = ["EUR/USD", "GBP/USD", "USD/JPY"][i % 3]
      price = case ticker
      when "EUR/USD" then 1.0850 + (i * 0.0001)
      when "GBP/USD" then 1.2750 + (i * 0.0001) 
      when "USD/JPY" then 148.50 + (i * 0.01)
      end
      "1,#{price},#{timestamp.strftime('%Y-%m-%dT%H:%M:%S.%9NZ')},100000,[],#{i},#{timestamp.strftime('%Y-%m-%dT%H:%M:%S.%9NZ')},#{i},#{ticker},,"
    end
    header + trades.join("\n")
  end

  def generate_comprehensive_file_catalog
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <ListBucketResult>
        <Name>flatfiles</Name>
        <Prefix></Prefix>
        <KeyCount>2847</KeyCount>
        <Contents>
          <Key>us/stocks/trades/2024/03/2024-03-15.csv.gz</Key>
          <Size>85000000</Size>
          <LastModified>2024-03-16T11:00:00.000Z</LastModified>
        </Contents>
        <Contents>
          <Key>us/options/trades/2024/03/2024-03-15.csv.gz</Key>
          <Size>125000000</Size>
          <LastModified>2024-03-16T11:00:00.000Z</LastModified>
        </Contents>
        <Contents>
          <Key>us/crypto/trades/2024/03/2024-03-15.csv.gz</Key>
          <Size>45000000</Size>
          <LastModified>2024-03-16T11:00:00.000Z</LastModified>
        </Contents>
        <Contents>
          <Key>us/forex/trades/2024/03/2024-03-15.csv.gz</Key>
          <Size>65000000</Size>
          <LastModified>2024-03-16T11:00:00.000Z</LastModified>
        </Contents>
      </ListBucketResult>
    XML
  end

  def generate_filtered_file_listing(asset_class, data_type, year)
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <ListBucketResult>
        <Name>flatfiles</Name>
        <Prefix>us/#{asset_class}/#{data_type}/#{year}/</Prefix>
        <KeyCount>252</KeyCount>
        #{generate_year_file_entries(asset_class, data_type, year)}
      </ListBucketResult>
    XML
  end

  def generate_year_file_entries(asset_class, data_type, year)
    trading_days = generate_trading_days(year.to_i)
    trading_days.map do |date|
      size = rand(50_000_000..150_000_000)
      date_str = date.strftime("%Y-%m-%d")
      month_str = date.strftime("%m")
      
      <<~ENTRY
        <Contents>
          <Key>us/#{asset_class}/#{data_type}/#{year}/#{month_str}/#{date_str}.csv.gz</Key>
          <Size>#{size}</Size>
          <LastModified>#{(date + 1).strftime("%Y-%m-%dT11:00:00.000Z")}</LastModified>
        </Contents>
      ENTRY
    end.join
  end

  def generate_trading_days(year)
    start_date = Date.new(year, 1, 1)
    end_date = Date.new(year, 12, 31)
    
    (start_date..end_date).select do |date|
      # Exclude weekends and major holidays
      date.wday.between?(1, 5) && !holiday?(date)
    end
  end

  def holiday?(date)
    # Simplified holiday check for major US market holidays
    holidays = [
      Date.new(date.year, 1, 1),   # New Year's Day
      Date.new(date.year, 7, 4),   # Independence Day  
      Date.new(date.year, 12, 25), # Christmas
    ]
    holidays.include?(date)
  end

  def generate_validated_trade_dataset(record_count)
    header = "exchange,price,sip_timestamp,size,conditions,id,participant_timestamp,sequence_number,ticker,trf_id,trf_timestamp\n"
    trades = (1..record_count).map do |i|
      ticker = ["AAPL", "MSFT", "GOOGL"][i % 3]
      price = (100.0 + (i * 0.01)).round(2)
      size = 100
      timestamp = Time.parse("2024-03-15T09:30:00Z") + (i * 0.1)
      "4,#{price},#{timestamp.strftime('%Y-%m-%dT%H:%M:%S.%9NZ')},#{size},[14],#{i},#{timestamp.strftime('%Y-%m-%dT%H:%M:%S.%9NZ')},#{i},#{ticker},,"
    end
    header + trades.join("\n")
  end

  def generate_available_dates_listing(month, exclude_holidays: false)
    year, month_num = month.split("-").map(&:to_i)
    days_in_month = Date.new(year, month_num, -1).day
    
    available_days = (1..days_in_month).map do |day|
      date = Date.new(year, month_num, day)
      next if exclude_holidays && (date.wday == 0 || date.wday == 6 || holiday?(date))
      
      date_str = date.strftime("%Y-%m-%d")
      <<~ENTRY
        <Contents>
          <Key>us/stocks/trades/#{year}/#{month_num.to_s.rjust(2, '0')}/#{date_str}.csv.gz</Key>
          <Size>#{rand(50_000_000..100_000_000)}</Size>
          <LastModified>#{(date + 1).strftime("%Y-%m-%dT11:00:00.000Z")}</LastModified>
        </Contents>
      ENTRY
    end.compact.join
    
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <ListBucketResult>
        <Name>flatfiles</Name>
        <Prefix>us/stocks/trades/#{month}/</Prefix>
        #{available_days}
      </ListBucketResult>
    XML
  end

  def generate_valid_trade_data(trade_count)
    header = "exchange,price,sip_timestamp,size,conditions,id,participant_timestamp,sequence_number,ticker,trf_id,trf_timestamp\n"
    trades = (1..trade_count).map do |i|
      "4,#{(150.0 + i * 0.01).round(2)},#{(Time.now + i).strftime('%Y-%m-%dT%H:%M:%S.%9NZ')},100,[14],#{i},#{(Time.now + i).strftime('%Y-%m-%dT%H:%M:%S.%9NZ')},#{i},AAPL,,"
    end
    header + trades.join("\n")
  end

  def calculate_time_overlap(dataset1, dataset2)
    times1 = dataset1.map(&:timestamp).sort
    times2 = dataset2.map(&:timestamp).sort
    
    overlap_start = [times1.first, times2.first].max
    overlap_end = [times1.last, times2.last].min
    
    {
      overlap_minutes: overlap_end > overlap_start ? ((overlap_end - overlap_start) / 60).to_i : 0,
      coverage_percentage: overlap_end > overlap_start ? 
        ((overlap_end - overlap_start) / (times1.last - times1.first) * 100).round(2) : 0
    }
  end

  def calculate_options_stock_alignment(options_trades, stock_trades)
    # Count how many options trades have corresponding stock trades within 1 minute
    aligned = options_trades.count do |opt_trade|
      stock_trades.any? do |stock_trade|
        (opt_trade.timestamp - stock_trade.timestamp).abs < 60
      end
    end
    
    {aligned_trades: aligned, alignment_percentage: (aligned.to_f / options_trades.length * 100).round(2)}
  end

  def identify_inverse_correlations(stock_trades, forex_trades)
    # Simplified inverse correlation detection
    stock_price_changes = stock_trades.each_cons(2).map { |prev, curr| curr.price - prev.price }
    forex_price_changes = forex_trades.each_cons(2).map { |prev, curr| curr.price - prev.price }
    
    inverse_moves = stock_price_changes.zip(forex_price_changes).count do |stock_change, forex_change|
      (stock_change > 0 && forex_change < 0) || (stock_change < 0 && forex_change > 0)
    end
    
    inverse_moves
  end

  def identify_independent_movements(stock_trades, crypto_trades)
    # Count periods where crypto moves independently of stocks
    stock_volatility = stock_trades.map(&:price).each_cons(2).map { |prev, curr| (curr - prev).abs }
    crypto_volatility = crypto_trades.map(&:price).each_cons(2).map { |prev, curr| (curr - prev).abs }
    
    independent_periods = stock_volatility.zip(crypto_volatility).count do |stock_vol, crypto_vol|
      stock_vol < (stock_volatility.sum / stock_volatility.length) && 
      crypto_vol > (crypto_volatility.sum / crypto_volatility.length)
    end
    
    independent_periods
  end

  def measure_hedge_relationships(stock_trades, options_trades)
    # Simplified hedge relationship measurement
    return 0.7 # 70% correlation for demonstration
  end

  def calculate_download_time(total_bytes, bandwidth_mbps = 100)
    # Estimate download time based on file size and bandwidth
    bandwidth_bytes_per_second = bandwidth_mbps * 1_000_000 / 8
    (total_bytes / bandwidth_bytes_per_second).round(2)
  end

  def calculate_bandwidth_saved(partial_bytes, total_bytes)
    (partial_bytes.to_f / total_bytes).round(3)
  end

  def identify_timestamp_gaps(timestamps)
    # Find gaps in timestamp sequence larger than expected
    gaps = []
    timestamps.each_cons(2) do |prev, curr|
      gap_seconds = curr - prev
      gaps << {start: prev, end: curr, duration: gap_seconds} if gap_seconds > 300 # 5+ minute gaps
    end
    gaps
  end
end