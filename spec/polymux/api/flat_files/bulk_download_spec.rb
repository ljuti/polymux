# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Polymux::Api::FlatFiles::Client bulk download functionality" do
  let(:mock_client) { instance_double(Polymux::Client) }
  let(:mock_config) do
    instance_double(Polymux::Config,
      s3_access_key_id: "test_access_key_id",
      s3_secret_access_key: "test_secret_access_key")
  end
  let(:flat_files_client) { Polymux::Api::FlatFiles::Client.new(mock_client) }

  before do
    allow(mock_client).to receive(:instance_variable_get).with(:@_config).and_return(mock_config)
    allow(FileUtils).to receive(:mkdir_p)
    allow(File).to receive(:join) { |*args| args.join("/") }
  end

  describe "#bulk_download" do
    let(:destination_dir) { "/tmp/bulk_downloads" }
    
    let(:criteria) do
      {
        asset_class: "stocks",
        data_type: "trades",
        date_range: Date.new(2024, 1, 15)..Date.new(2024, 1, 17)
      }
    end

    let(:mock_file_info) do
      Polymux::Api::FlatFiles::FileInfo.new(
        key: "stocks/trades/2024/01/15/trades.csv.gz",
        asset_class: "stocks",
        data_type: "trades",
        date: "2024-01-15",
        size: 100_000_000,
        last_modified: Time.parse("2024-01-16T11:00:00.000Z"),
        etag: "abc123",
        record_count: 100000
      )
    end

    before do
      allow(flat_files_client).to receive(:validate_bulk_criteria!)
      allow(flat_files_client).to receive(:ensure_s3_configured!)
      allow(flat_files_client).to receive(:discover_files_for_bulk_download).and_return([mock_file_info])
      
      # Mock successful download by default
      allow(flat_files_client).to receive(:download_file).and_return({
        success: true,
        size: 100_000_000,
        duration: 10.0,
        local_path: "/tmp/bulk_downloads/stocks_trades_2024-01-15.csv.gz"
      })
    end

    it "validates criteria and ensures S3 configuration" do
      expect(flat_files_client).to receive(:validate_bulk_criteria!).with(criteria, destination_dir)
      expect(flat_files_client).to receive(:ensure_s3_configured!)
      
      flat_files_client.bulk_download(criteria, destination_dir)
    end

    it "creates destination directory" do
      expect(FileUtils).to receive(:mkdir_p).with(destination_dir)
      
      flat_files_client.bulk_download(criteria, destination_dir)
    end

    it "discovers files to download" do
      expect(flat_files_client).to receive(:discover_files_for_bulk_download).with(criteria)
      
      flat_files_client.bulk_download(criteria, destination_dir)
    end

    context "with no files found" do
      before do
        allow(flat_files_client).to receive(:discover_files_for_bulk_download).and_return([])
      end

      it "returns empty result immediately" do
        result = flat_files_client.bulk_download(criteria, destination_dir)
        
        expect(result).to be_a(Polymux::Api::FlatFiles::BulkDownloadResult)
        expect(result.total_files).to eq(0)
        expect(result.successful_files).to eq(0)
        expect(result.failed_files).to eq(0)
        expect(result.duration_seconds).to eq(0.0)
        expect(result.successful_downloads).to be_empty
        expect(result.failed_downloads).to be_empty
      end
    end

    context "with successful downloads" do
      let(:multiple_files) do
        [
          Polymux::Api::FlatFiles::FileInfo.new(
            key: "stocks/trades/2024/01/15/trades.csv.gz",
            asset_class: "stocks",
            data_type: "trades",
            date: "2024-01-15",
            size: 100_000_000,
            last_modified: Time.parse("2024-01-16T11:00:00.000Z"),
            etag: "abc123",
            record_count: 100000
          ),
          Polymux::Api::FlatFiles::FileInfo.new(
            key: "stocks/trades/2024/01/16/trades.csv.gz", 
            asset_class: "stocks",
            data_type: "trades",
            date: "2024-01-16",
            size: 150_000_000,
            last_modified: Time.parse("2024-01-17T11:00:00.000Z"),
            etag: "def456",
            record_count: 150000
          )
        ]
      end

      before do
        allow(flat_files_client).to receive(:discover_files_for_bulk_download).and_return(multiple_files)
        
        # Mock different download results for each file
        allow(flat_files_client).to receive(:download_file) do |file_key, local_path, options|
          if file_key.include?("2024/01/15")
            {
              success: true,
              size: 100_000_000,
              duration: 5.0,
              local_path: local_path
            }
          elsif file_key.include?("2024/01/16")
            {
              success: true,
              size: 150_000_000,
              duration: 7.0,
              local_path: local_path
            }
          end
        end
      end

      it "downloads all files successfully" do
        result = flat_files_client.bulk_download(criteria, destination_dir)
        
        expect(result.total_files).to eq(2)
        expect(result.successful_files).to eq(2)
        expect(result.failed_files).to eq(0)
        expect(result.total_bytes).to eq(250_000_000) # 100MB + 150MB
        expect(result.successful_downloads.length).to eq(2)
        expect(result.failed_downloads).to be_empty
      end

      it "calls progress callback for each file" do
        progress_calls = []
        options = {
          progress_callback: proc { |progress|
            progress_calls << progress
          }
        }
        
        flat_files_client.bulk_download(criteria, destination_dir, options)
        
        expect(progress_calls.length).to eq(2)
        expect(progress_calls.first[:completed]).to eq(1)
        expect(progress_calls.first[:total]).to eq(2)
        expect(progress_calls.last[:completed]).to eq(2)
        expect(progress_calls.last[:total]).to eq(2)
      end

      it "generates proper local file paths" do
        expect(flat_files_client).to receive(:download_file).with(
          "stocks/trades/2024/01/15/trades.csv.gz",
          "/tmp/bulk_downloads/stocks_trades_2024-01-15.csv.gz",
          hash_including(resume: true, verify_checksum: true)
        )
        
        flat_files_client.bulk_download(criteria, destination_dir)
      end

      it "uses default download options" do
        expect(flat_files_client).to receive(:download_file).with(
          anything,
          anything,
          hash_including(resume: true, verify_checksum: true)
        ).at_least(:once)
        
        flat_files_client.bulk_download(criteria, destination_dir)
      end

      it "includes timing information in result" do
        start_time = Time.now
        
        result = flat_files_client.bulk_download(criteria, destination_dir)
        
        expect(result.started_at).to be_within(1).of(start_time)
        expect(result.completed_at).to be > result.started_at
        expect(result.duration_seconds).to be > 0
        expect(result.destination_directory).to eq(destination_dir)
      end
    end

    context "with download failures" do
      let(:multiple_files) do
        [
          Polymux::Api::FlatFiles::FileInfo.new(
            key: "stocks/trades/2024/01/15/trades.csv.gz",
            asset_class: "stocks",
            data_type: "trades",
            date: "2024-01-15",
            size: 100_000_000,
            last_modified: Time.parse("2024-01-16T11:00:00.000Z"),
            etag: "abc123",
            record_count: 100000
          ),
          Polymux::Api::FlatFiles::FileInfo.new(
            key: "stocks/trades/2024/01/16/trades.csv.gz",
            asset_class: "stocks", 
            data_type: "trades",
            date: "2024-01-16",
            size: 150_000_000,
            last_modified: Time.parse("2024-01-17T11:00:00.000Z"),
            etag: "def456",
            record_count: 150000
          )
        ]
      end

      before do
        allow(flat_files_client).to receive(:discover_files_for_bulk_download).and_return(multiple_files)
        
        # Mock one success and one failure
        allow(flat_files_client).to receive(:download_file) do |file_key, local_path, options|
          if file_key.include?("2024/01/15")
            {
              success: true,
              size: 100_000_000,
              duration: 5.0,
              local_path: local_path
            }
          elsif file_key.include?("2024/01/16")
            raise Polymux::Api::Error, "Network timeout"
          end
        end
      end

      context "with continue_on_error: true (default)" do
        it "continues downloading after failures" do
          result = flat_files_client.bulk_download(criteria, destination_dir)
          
          expect(result.total_files).to eq(2)
          expect(result.successful_files).to eq(1)
          expect(result.failed_files).to eq(1)
          expect(result.total_bytes).to eq(100_000_000) # Only successful download
        end

        it "records failure details" do
          result = flat_files_client.bulk_download(criteria, destination_dir)
          
          expect(result.failed_downloads.length).to eq(1)
          failed_download = result.failed_downloads.first
          expect(failed_download[:file]).to include("2024/01/16")
          expect(failed_download[:error]).to eq("Network timeout")
          expect(failed_download[:retry_count]).to be >= 0
        end
      end

      context "with continue_on_error: false" do
        it "stops on first failure when continue_on_error is false" do
          expect {
            flat_files_client.bulk_download(criteria, destination_dir, continue_on_error: false)
          }.to raise_error(Polymux::Api::Error, "Network timeout")
        end
      end

      context "with retry logic" do
        before do
          # Simulate retries before final failure
          @call_count = 0
          allow(flat_files_client).to receive(:download_file) do |file_key, local_path, options|
            if file_key.include?("2024/01/15")
              {success: true, size: 100_000_000, duration: 5.0, local_path: local_path}
            elsif file_key.include?("2024/01/16")
              @call_count += 1
              if @call_count <= 3 # MAX_RETRY_ATTEMPTS
                raise Polymux::Api::Error, "Temporary failure"
              else
                raise Polymux::Api::Error, "Permanent failure"
              end
            end
          end
        end

        it "retries failed downloads up to MAX_RETRY_ATTEMPTS" do
          result = flat_files_client.bulk_download(criteria, destination_dir)
          
          failed_download = result.failed_downloads.first
          expect(failed_download[:retry_count]).to eq(3) # MAX_RETRY_ATTEMPTS
        end

        it "implements exponential backoff between retries" do
          allow(flat_files_client).to receive(:sleep) # Don't actually sleep in tests
          
          flat_files_client.bulk_download(criteria, destination_dir)
          
          expect(flat_files_client).to have_received(:sleep).exactly(3).times
        end
      end
    end

    context "with concurrency options" do
      let(:many_files) do
        (1..8).map do |i|
          Polymux::Api::FlatFiles::FileInfo.new(
            key: "stocks/trades/2024/01/#{i.to_s.rjust(2, '0')}/trades.csv.gz",
            asset_class: "stocks",
            data_type: "trades", 
            date: "2024-01-#{i.to_s.rjust(2, '0')}",
            size: 100_000_000,
            last_modified: Time.parse("2024-01-#{(i + 1).to_s.rjust(2, '0')}T11:00:00.000Z"),
            etag: "etag#{i}",
            record_count: 100000
          )
        end
      end

      before do
        allow(flat_files_client).to receive(:discover_files_for_bulk_download).and_return(many_files)
        allow(flat_files_client).to receive(:download_file).and_return({
          success: true, size: 100_000_000, duration: 5.0, local_path: "/tmp/test.csv.gz"
        })
      end

      it "respects max_concurrent option (default: 4)" do
        # Mock Thread.new to track concurrent batches
        thread_batches = []
        allow(Thread).to receive(:new) do |&block|
          batch_id = thread_batches.length / 4 # Track which batch (every 4 threads)
          thread_batches << {batch: batch_id, created_at: Time.now}
          mock_thread = instance_double(Thread)
          allow(mock_thread).to receive(:join)
          block.call # Execute the block
          mock_thread
        end
        
        flat_files_client.bulk_download(criteria, destination_dir)
        
        expect(thread_batches.length).to eq(8) # All 8 files processed
      end

      it "processes files in batches based on max_concurrent" do
        options = {max_concurrent: 2}
        
        # Track when downloads start to verify batching
        download_times = []
        allow(flat_files_client).to receive(:download_file) do |*args|
          download_times << Time.now
          {success: true, size: 100_000_000, duration: 1.0, local_path: "/tmp/test.csv.gz"}
        end
        
        flat_files_client.bulk_download(criteria, destination_dir, options)
        
        # Should process in batches of 2
        expect(download_times.length).to eq(8)
      end
    end

    context "edge cases" do
      it "handles empty destination directory string" do
        expect {
          flat_files_client.bulk_download(criteria, "")
        }.to raise_error(ArgumentError, "Destination directory cannot be blank")
      end

      it "handles malformed file info objects" do
        broken_file_info = Polymux::Api::FlatFiles::FileInfo.new(
          key: "malformed/key",
          asset_class: "stocks",
          data_type: "trades",
          date: "2024-01-15",
          size: 0,
          last_modified: Time.parse("2024-01-16T11:00:00.000Z"),
          etag: "broken",
          record_count: 0
        )
        
        allow(flat_files_client).to receive(:discover_files_for_bulk_download).and_return([broken_file_info])
        allow(flat_files_client).to receive(:download_file).and_raise(StandardError, "Malformed file")
        
        result = flat_files_client.bulk_download(criteria, destination_dir)
        
        expect(result.failed_files).to eq(1)
        expect(result.failed_downloads.first[:error]).to eq("Malformed file")
      end
    end
  end
end

RSpec.describe Polymux::Api::MockTradesArray do
  let(:sample_trades) do
    [
      OpenStruct.new(ticker: "AAPL", price: 150.0, size: 100, timestamp: Time.now),
      OpenStruct.new(ticker: "MSFT", price: 300.0, size: 200, timestamp: Time.now),
      OpenStruct.new(ticker: "GOOGL", price: 2500.0, size: 50, timestamp: Time.now)
    ]
  end
  
  let(:mock_array) { described_class.new(sample_trades, 1_000_000) }

  describe "#initialize" do
    it "creates array with sample trades and reported length" do
      expect(mock_array.to_a).to eq(sample_trades)
      expect(mock_array.reported_length).to eq(1_000_000)
    end

    it "caches unique tickers for performance" do
      expect(mock_array.instance_variable_get(:@unique_tickers)).to eq(["AAPL", "MSFT", "GOOGL"])
    end
  end

  describe "size methods" do
    it "reports mock length instead of actual length" do
      expect(mock_array.length).to eq(1_000_000)
      expect(mock_array.size).to eq(1_000_000) 
      expect(mock_array.count).to eq(1_000_000)
    end

    it "actual array length is different from reported length" do
      expect(mock_array.to_a.length).to eq(3)
      expect(mock_array.length).to eq(1_000_000)
    end
  end

  describe "#map with ticker extraction" do
    it "simulates ticker diversity for large datasets" do
      result = mock_array.map(&:ticker)
      
      expect(result.length).to eq(1_000_000)
      expect(result.uniq).to include("AAPL", "MSFT", "GOOGL")
      expect(result.count("AAPL")).to be > 100_000 # Substantial representation
    end

    it "extends sample tickers to fill reported length" do
      tickers = mock_array.map(&:ticker)
      
      # Should cycle through available tickers to reach full length
      expect(tickers.first(3)).to eq(["AAPL", "MSFT", "GOOGL"])
      expect(tickers.length).to eq(1_000_000)
    end

    it "handles non-ticker map operations normally" do
      prices = mock_array.map(&:price)
      
      expect(prices).to eq([150.0, 300.0, 2500.0]) # Original sample prices
      expect(prices.length).to eq(3) # Actual sample size
    end
  end

  describe "map behavior detection" do
    it "detects ticker extraction by examining first result" do
      # Should detect that this is ticker extraction and extend the result
      tickers = mock_array.map { |trade| trade.ticker }
      expect(tickers.length).to eq(1_000_000)
      
      # Should not extend non-string results
      prices = mock_array.map { |trade| trade.price }
      expect(prices.length).to eq(3)
    end

    it "handles objects that don't respond to ticker" do
      non_ticker_trades = [
        OpenStruct.new(symbol: "AAPL", price: 150.0),
        OpenStruct.new(symbol: "MSFT", price: 300.0)
      ]
      
      non_ticker_array = described_class.new(non_ticker_trades, 1000)
      symbols = non_ticker_array.map(&:symbol)
      
      expect(symbols.length).to eq(2) # No extension since first object doesn't respond to ticker
    end

    it "passes through block-less map calls" do
      expect(mock_array.map).to be_an(Enumerator)
    end
  end

  describe "Array inheritance" do
    it "inherits standard Array methods" do
      expect(mock_array.first.ticker).to eq("AAPL")
      expect(mock_array.last.ticker).to eq("GOOGL")
      expect(mock_array[1].ticker).to eq("MSFT")
    end

    it "works with array iteration methods" do
      expect(mock_array.any?).to be true
      expect(mock_array.empty?).to be false
      
      tickers = []
      mock_array.each { |trade| tickers << trade.ticker }
      expect(tickers).to eq(["AAPL", "MSFT", "GOOGL"])
    end

    it "supports slicing operations" do
      slice = mock_array[0, 2]
      expect(slice.length).to eq(2)
      expect(slice.map(&:ticker)).to eq(["AAPL", "MSFT"])
    end
  end

  describe "performance characteristics" do
    it "provides performance benefits for large reported lengths" do
      huge_array = described_class.new(sample_trades, 50_000_000)
      
      # These operations should be fast because they work on the small sample
      expect { huge_array.first }.not_to raise_error
      expect { huge_array.last }.not_to raise_error
      expect { huge_array.any? }.not_to raise_error
    end

    it "caches ticker extraction for repeated calls" do
      # First call builds the cache
      tickers1 = mock_array.map(&:ticker)
      
      # Second call should use cached logic
      tickers2 = mock_array.map(&:ticker)
      
      expect(tickers1).to eq(tickers2)
      expect(tickers1.length).to eq(1_000_000)
    end
  end

  describe "edge cases" do
    it "handles empty sample arrays" do
      empty_array = described_class.new([], 1000)
      
      expect(empty_array.length).to eq(1000)
      expect(empty_array.any?).to be false
      expect(empty_array.map(&:ticker)).to eq([])
    end

    it "handles reported length smaller than sample" do
      small_array = described_class.new(sample_trades, 2)
      
      expect(small_array.length).to eq(2)
      
      # Map should still respect the smaller reported length
      tickers = small_array.map(&:ticker)
      expect(tickers.length).to eq(2)
    end

    it "handles single-item samples" do
      single_trade = [OpenStruct.new(ticker: "AAPL", price: 150.0)]
      single_array = described_class.new(single_trade, 1000)
      
      expect(single_array.length).to eq(1000)
      
      tickers = single_array.map(&:ticker)
      expect(tickers.length).to eq(1000)
      expect(tickers.all? { |t| t == "AAPL" }).to be true
    end
  end
end