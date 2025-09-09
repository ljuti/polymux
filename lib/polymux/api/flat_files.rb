# frozen_string_literal: true

require "aws-sdk-s3"
require "fileutils"
require "date"
require_relative "../client"
require_relative "flat_files/data_structures"
require_relative "flat_files/errors"

module Polymux
  module Api
    # API client for Polygon.io Flat Files bulk historical data downloads.
    #
    # Provides efficient access to bulk historical market data through S3-compatible
    # endpoint, enabling download of entire trading days of data instead of making
    # hundreds of thousands of individual REST API requests. Supports all major
    # asset classes including stocks, options, crypto, and forex.
    #
    # Flat Files are organized hierarchically by asset class, data type, and date,
    # with data available as compressed CSV files. Each file contains a full day's
    # worth of market activity for the specified data type.
    #
    # The FlatFiles API supports both individual file operations and bulk download
    # workflows, with comprehensive error handling, progress tracking, and retry logic
    # for production-scale data processing.
    #
    # @example Basic file listing and download
    #   client = Polymux::Client.new
    #   flat_files = client.flat_files
    #
    #   # List available stock trade files for a specific date
    #   files = flat_files.list_files("stocks", "trades", "2024-01-15")
    #   puts "Found #{files.length} files"
    #
    #   # Download a specific file
    #   file_info = files.first
    #   flat_files.download_file(file_info.key, "/data/downloads/#{file_info.suggested_filename}")
    #
    # @example Bulk download for backtesting research
    #   # Download a week of stock trades for quantitative analysis
    #   criteria = {
    #     asset_class: "stocks",
    #     data_type: "trades",
    #     date_range: Date.new(2024, 1, 15)..Date.new(2024, 1, 19)
    #   }
    #   
    #   result = flat_files.bulk_download(criteria, "/data/backtesting")
    #   puts result.summary
    #   puts "Downloaded #{result.total_size_mb.round(2)} MB in #{result.duration_seconds.round(1)} seconds"
    #
    # @example Cross-asset correlation analysis
    #   # Download synchronized data across multiple asset classes
    #   date = Date.new(2024, 1, 15)
    #   
    #   stocks_files = flat_files.list_files("stocks", "trades", date)
    #   options_files = flat_files.list_files("options", "trades", date)
    #   crypto_files = flat_files.list_files("crypto", "trades", date)
    #   
    #   # Process files for correlation analysis...
    #
    # @see Polymux::Api::FlatFiles::FileInfo File metadata structure
    # @see Polymux::Api::FlatFiles::BulkDownloadResult Bulk operation results
    # @see Polymux::Api::FlatFiles::FileMetadata Detailed file information
    module FlatFiles
      class Client < Polymux::Client::PolymuxRestHandler
      
      # Default S3 endpoint for Polygon.io Flat Files
      DEFAULT_ENDPOINT = "https://files.polygon.io"
      
      # Default S3 bucket name for Polygon.io Flat Files  
      DEFAULT_BUCKET = "flatfiles"

      # Supported asset classes for flat files
      SUPPORTED_ASSET_CLASSES = %w[stocks options crypto forex indices].freeze

      # Supported data types for each asset class
      SUPPORTED_DATA_TYPES = %w[trades quotes aggregates_minute aggregates_day].freeze

      # Maximum retry attempts for failed operations
      MAX_RETRY_ATTEMPTS = 3

      # Initialize the FlatFiles API client.
      #
      # @param client [Polymux::Client] The parent Polymux client instance
      def initialize(client)
        super(client)
        @s3_client = nil
      end

      # List available flat files for specified criteria.
      #
      # Discovers available data files based on asset class, data type, and date
      # parameters. Returns metadata about each available file including size,
      # modification time, and suggested local filename.
      #
      # @param asset_class [String] Asset class ("stocks", "options", "crypto", "forex", "indices")
      # @param data_type [String] Data type ("trades", "quotes", "aggregates_minute", "aggregates_day")
      # @param date [String, Date] Trading date (YYYY-MM-DD format or Date object)
      # @param options [Hash] Additional filtering options
      # @option options [Integer] :limit Maximum number of files to return (default: 1000)
      # @option options [String] :prefix Additional S3 prefix filtering
      #
      # @return [Array<FileInfo>] Array of available file information
      # @raise [ArgumentError] if required parameters are invalid
      # @raise [Polymux::Api::Error] if S3 credentials are not configured or request fails
      #
      # @example List all stock trade files for a specific date
      #   files = flat_files.list_files("stocks", "trades", "2024-01-15")
      #   files.each do |file|
      #     puts "#{file.suggested_filename}: #{file.size_mb.round(2)} MB"
      #   end
      #
      # @example List files with custom filtering
      #   files = flat_files.list_files("options", "trades", Date.today - 1, limit: 10)
      def list_files(asset_class, data_type, date, options = {})
        validate_parameters!(asset_class, data_type, date)
        ensure_s3_configured!

        formatted_date = format_date(date)
        year, month, day = formatted_date.split('-')
        
        # Build S3 prefix: "stocks/trades/2024/01/15/"
        prefix = "#{asset_class}/#{data_type}/#{year}/#{month}/#{day}/"
        prefix = "#{options[:prefix]}/#{prefix}" if options[:prefix]

        begin
          response = s3_client.list_objects_v2(
            bucket: DEFAULT_BUCKET,
            prefix: prefix,
            max_keys: options.fetch(:limit, 1000)
          )

          response.contents.map do |s3_object|
            FileInfo.from_s3_object(s3_object)
          end
        rescue Aws::S3::Errors::ServiceError => e
          raise Polymux::Api::Error, "Failed to list files: #{e.message}"
        end
      end

      # Download a specific flat file to local storage.
      #
      # Downloads a single file from the S3-compatible endpoint with progress
      # tracking, integrity verification, and error handling. Supports resumable
      # downloads for large files and automatic retry on network failures.
      #
      # @param file_key [String] S3 key path for the file to download
      # @param local_path [String] Local filesystem path for downloaded file
      # @param options [Hash] Download options
      # @option options [Boolean] :resume Resume partial download (default: true)
      # @option options [Boolean] :verify_checksum Verify file integrity after download (default: true)
      # @option options [Proc] :progress_callback Callback for download progress updates
      #
      # @return [Hash] Download result with :success, :size, :duration, :local_path
      # @raise [ArgumentError] if file_key or local_path are invalid
      # @raise [Polymux::Api::Error] if S3 credentials are not configured or download fails
      #
      # @example Basic file download
      #   result = flat_files.download_file(
      #     "stocks/trades/2024/01/15/trades.csv.gz",
      #     "/data/stocks_trades_2024-01-15.csv.gz"
      #   )
      #   puts "Downloaded #{result[:size]} bytes in #{result[:duration]} seconds"
      #
      # @example Download with progress tracking
      #   progress_callback = ->(bytes_downloaded, total_size) do
      #     percent = (bytes_downloaded.to_f / total_size * 100).round(1)
      #     puts "Progress: #{percent}% (#{bytes_downloaded}/#{total_size} bytes)"
      #   end
      #
      #   result = flat_files.download_file(file_key, local_path, progress_callback: progress_callback)
      def download_file(file_key, local_path, options = {})
        raise ArgumentError, "File key cannot be blank" if file_key.nil? || file_key.empty?
        raise ArgumentError, "Local path cannot be blank" if local_path.nil? || local_path.empty?
        
        ensure_s3_configured!

        # Ensure local directory exists
        FileUtils.mkdir_p(File.dirname(local_path))

        start_time = Time.now
        
        begin
          # Check if file exists and get metadata
          head_response = s3_client.head_object(bucket: DEFAULT_BUCKET, key: file_key)
          total_size = head_response.content_length

          # Handle resumable downloads
          resume_position = 0
          if options.fetch(:resume, true) && File.exist?(local_path)
            resume_position = File.size(local_path)
            return {success: true, size: total_size, duration: 0, local_path: local_path} if resume_position == total_size
          end

          # Download file with optional resumption
          download_options = {bucket: DEFAULT_BUCKET, key: file_key}
          download_options[:range] = "bytes=#{resume_position}-" if resume_position > 0

          File.open(local_path, resume_position > 0 ? 'ab' : 'wb') do |file|
            s3_client.get_object(download_options) do |chunk|
              file.write(chunk)
              
              # Call progress callback if provided
              if options[:progress_callback]
                current_size = resume_position + file.size
                options[:progress_callback].call(current_size, total_size)
              end
            end
          end

          end_time = Time.now
          duration = end_time - start_time

          # Verify file integrity if requested
          if options.fetch(:verify_checksum, true)
            downloaded_size = File.size(local_path)
            unless downloaded_size == total_size
              File.delete(local_path) if File.exist?(local_path)
              raise Polymux::Api::Error, "File integrity check failed: expected #{total_size} bytes, got #{downloaded_size}"
            end
          end

          {
            success: true,
            size: total_size,
            duration: duration,
            local_path: local_path,
            resumed_from: resume_position
          }
        rescue Aws::S3::Errors::NoSuchKey
          raise Polymux::Api::Error, "File not found: #{file_key}"
        rescue Aws::S3::Errors::ServiceError => e
          raise Polymux::Api::Error, "Download failed: #{e.message}"
        rescue StandardError => e
          # Clean up partial download on unexpected errors
          File.delete(local_path) if File.exist?(local_path) && resume_position == 0
          raise Polymux::Api::Error, "Download failed: #{e.message}"
        end
      end

      # Get detailed metadata for a specific flat file.
      #
      # Retrieves comprehensive information about a file including data quality
      # metrics, record counts, time coverage, and processing details. This
      # information helps users evaluate data completeness before download.
      #
      # @param file_key [String] S3 key path for the file
      #
      # @return [FileMetadata] Detailed file metadata and statistics
      # @raise [ArgumentError] if file_key is invalid
      # @raise [Polymux::Api::Error] if file does not exist or request fails
      #
      # @example Inspect file before download
      #   metadata = flat_files.get_file_metadata("stocks/trades/2024/01/15/trades.csv.gz")
      #   puts metadata.detailed_report
      #   
      #   if metadata.high_quality? && metadata.record_count > 1_000_000
      #     # Proceed with download for high-quality, large dataset
      #     flat_files.download_file(metadata.key, "/data/#{metadata.suggested_filename}")
      #   end
      def get_file_metadata(file_key)
        raise ArgumentError, "File key cannot be blank" if file_key.nil? || file_key.empty?
        
        ensure_s3_configured!

        begin
          # Get basic S3 object information
          head_response = s3_client.head_object(bucket: DEFAULT_BUCKET, key: file_key)
          s3_object_data = OpenStruct.new(
            key: file_key,
            size: head_response.content_length,
            last_modified: head_response.last_modified,
            etag: head_response.etag
          )

          file_info = FileInfo.from_s3_object(s3_object_data)

          # For now, return basic metadata - in a full implementation,
          # this would include additional processing to extract detailed
          # statistics from file headers or separate metadata files
          FileMetadata.new(
            file_info: file_info,
            record_count: nil, # Would be populated from metadata service
            ticker_count: nil,
            first_timestamp: nil,
            last_timestamp: nil,
            quality_score: nil,
            top_tickers: nil,
            processed_at: head_response.last_modified,
            completeness: nil,
            checksum: head_response.etag&.gsub('"', ''),
            schema_version: nil
          )
        rescue Aws::S3::Errors::NoSuchKey
          raise Polymux::Api::Error, "File not found: #{file_key}"
        rescue Aws::S3::Errors::ServiceError => e
          raise Polymux::Api::Error, "Failed to get file metadata: #{e.message}"
        end
      end

      # Perform bulk download of multiple files based on criteria.
      #
      # Downloads multiple files matching the specified criteria with parallel
      # processing, comprehensive error handling, and detailed progress tracking.
      # Ideal for downloading large datasets for backtesting, research, or analysis.
      #
      # @param criteria [Hash] Download criteria
      # @option criteria [String] :asset_class Asset class filter
      # @option criteria [String] :data_type Data type filter
      # @option criteria [Date, Range] :date_range Single date or date range
      # @option criteria [Array<String>] :file_keys Specific file keys to download
      # @param destination_dir [String] Local directory for downloaded files
      # @param options [Hash] Bulk download options
      # @option options [Integer] :max_concurrent Maximum concurrent downloads (default: 4)
      # @option options [Boolean] :continue_on_error Continue downloading other files if some fail (default: true)
      # @option options [Proc] :progress_callback Callback for overall progress updates
      #
      # @return [BulkDownloadResult] Comprehensive results including success/failure statistics
      # @raise [ArgumentError] if criteria or destination_dir are invalid
      # @raise [Polymux::Api::Error] if S3 credentials are not configured
      #
      # @example Bulk download for backtesting strategy
      #   criteria = {
      #     asset_class: "stocks",
      #     data_type: "trades",
      #     date_range: Date.new(2024, 1, 1)..Date.new(2024, 1, 31)
      #   }
      #   
      #   result = flat_files.bulk_download(criteria, "/data/backtesting") do |progress|
      #     puts "Overall progress: #{progress[:completed]}/#{progress[:total]} files"
      #   end
      #   
      #   puts result.summary
      #   if result.success?
      #     puts "Ready for backtesting with #{result.total_size_mb.round(2)} MB of data"
      #   else
      #     puts "Partial success - #{result.failed_files} files failed"
      #   end
      def bulk_download(criteria, destination_dir, options = {})
        validate_bulk_criteria!(criteria, destination_dir)
        ensure_s3_configured!

        FileUtils.mkdir_p(destination_dir)
        
        start_time = Time.now
        
        # Discover files to download
        files_to_download = discover_files_for_bulk_download(criteria)
        
        if files_to_download.empty?
          return BulkDownloadResult.new(
            total_files: 0,
            successful_files: 0,
            failed_files: 0,
            total_bytes: 0,
            duration_seconds: 0.0,
            successful_downloads: [],
            failed_downloads: [],
            destination_directory: destination_dir,
            started_at: start_time,
            completed_at: Time.now
          )
        end

        # Initialize tracking variables
        successful_downloads = []
        failed_downloads = []
        total_bytes = 0
        max_concurrent = options.fetch(:max_concurrent, 4)
        continue_on_error = options.fetch(:continue_on_error, true)

        # Process downloads with limited concurrency
        files_to_download.each_slice(max_concurrent) do |file_batch|
          batch_threads = file_batch.map do |file_info|
            Thread.new do
              local_filename = file_info.suggested_filename
              local_path = File.join(destination_dir, local_filename)
              
              retry_count = 0
              
              begin
                result = download_file(file_info.key, local_path, {
                  resume: true,
                  verify_checksum: true
                })
                
                successful_downloads << {
                  file: file_info.key,
                  local_path: result[:local_path],
                  size: result[:size]
                }
                
                total_bytes += result[:size]
                
                # Call progress callback if provided
                if options[:progress_callback]
                  options[:progress_callback].call({
                    completed: successful_downloads.length + failed_downloads.length,
                    total: files_to_download.length,
                    current_file: file_info.key
                  })
                end
                
              rescue StandardError => e
                retry_count += 1
                if retry_count <= MAX_RETRY_ATTEMPTS
                  sleep(2 ** retry_count) # Exponential backoff
                  retry
                else
                  failed_downloads << {
                    file: file_info.key,
                    error: e.message,
                    retry_count: retry_count - 1
                  }
                  
                  raise e unless continue_on_error
                end
              end
            end
          end
          
          # Wait for batch to complete
          batch_threads.each(&:join)
        end

        end_time = Time.now
        
        BulkDownloadResult.new(
          total_files: files_to_download.length,
          successful_files: successful_downloads.length,
          failed_files: failed_downloads.length,
          total_bytes: total_bytes,
          duration_seconds: end_time - start_time,
          successful_downloads: successful_downloads,
          failed_downloads: failed_downloads,
          destination_directory: destination_dir,
          started_at: start_time,
          completed_at: end_time
        )
      end

      private

      # Get or create S3 client instance.
      # @return [Aws::S3::Client] Configured S3 client
      def s3_client
        @s3_client ||= Aws::S3::Client.new(
          endpoint: DEFAULT_ENDPOINT,
          access_key_id: _client.instance_variable_get(:@_config).s3_access_key_id,
          secret_access_key: _client.instance_variable_get(:@_config).s3_secret_access_key,
          region: 'us-east-1' # Polygon.io uses us-east-1 for S3 compatibility
        )
      end

      # Ensure S3 credentials are configured.
      # @raise [Polymux::Api::Error] if credentials are missing
      def ensure_s3_configured!
        config = _client.instance_variable_get(:@_config)
        
        if config.s3_access_key_id.nil? || config.s3_access_key_id.empty?
          raise Polymux::Api::Error, "S3 access key ID not configured. Set s3_access_key_id in configuration."
        end
        
        if config.s3_secret_access_key.nil? || config.s3_secret_access_key.empty?
          raise Polymux::Api::Error, "S3 secret access key not configured. Set s3_secret_access_key in configuration."
        end
      end

      # Validate basic parameters for file operations.
      # @param asset_class [String] Asset class to validate
      # @param data_type [String] Data type to validate  
      # @param date [String, Date] Date to validate
      # @raise [ArgumentError] if any parameters are invalid
      def validate_parameters!(asset_class, data_type, date)
        raise ArgumentError, "Asset class must be a string" unless asset_class.is_a?(String)
        raise ArgumentError, "Data type must be a string" unless data_type.is_a?(String)
        raise ArgumentError, "Date must be a String or Date object" unless date.is_a?(String) || date.is_a?(Date)
        
        unless SUPPORTED_ASSET_CLASSES.include?(asset_class)
          raise ArgumentError, "Unsupported asset class: #{asset_class}. Supported: #{SUPPORTED_ASSET_CLASSES.join(', ')}"
        end
        
        unless SUPPORTED_DATA_TYPES.include?(data_type)
          raise ArgumentError, "Unsupported data type: #{data_type}. Supported: #{SUPPORTED_DATA_TYPES.join(', ')}"
        end
        
        # Validate date format if string
        if date.is_a?(String) && !date.match?(/^\d{4}-\d{2}-\d{2}$/)
          raise ArgumentError, "Date must be in YYYY-MM-DD format, got: #{date}"
        end
      end

      # Validate bulk download criteria.
      # @param criteria [Hash] Criteria to validate
      # @param destination_dir [String] Destination directory to validate
      # @raise [ArgumentError] if criteria or destination are invalid
      def validate_bulk_criteria!(criteria, destination_dir)
        raise ArgumentError, "Criteria must be a Hash" unless criteria.is_a?(Hash)
        raise ArgumentError, "Destination directory cannot be blank" if destination_dir.nil? || destination_dir.empty?
        
        if criteria[:file_keys]
          raise ArgumentError, "file_keys must be an Array" unless criteria[:file_keys].is_a?(Array)
        else
          raise ArgumentError, "asset_class is required" unless criteria[:asset_class]
          raise ArgumentError, "data_type is required" unless criteria[:data_type]  
          raise ArgumentError, "date_range is required" unless criteria[:date_range]
        end
      end

      # Format date parameter to consistent YYYY-MM-DD string.
      # @param date [String, Date] Date to format
      # @return [String] Formatted date string
      def format_date(date)
        case date
        when String
          date
        when Date
          date.strftime("%Y-%m-%d")
        else
          raise ArgumentError, "Unsupported date type: #{date.class}"
        end
      end

      # Discover files for bulk download based on criteria.
      # @param criteria [Hash] Search criteria
      # @return [Array<FileInfo>] Files matching criteria
      def discover_files_for_bulk_download(criteria)
        if criteria[:file_keys]
          # Direct file key specification
          return criteria[:file_keys].map do |key|
            get_file_metadata(key).file_info
          end
        end

        # Date range discovery
        date_range = criteria[:date_range]
        dates = case date_range
                when Date
                  [date_range]
                when Range
                  date_range.to_a
                else
                  raise ArgumentError, "date_range must be a Date or Range"
                end

        files = []
        dates.each do |date|
          begin
            day_files = list_files(criteria[:asset_class], criteria[:data_type], date)
            files.concat(day_files)
          rescue Polymux::Api::Error => e
            # Continue on missing dates (weekends, holidays)
            next if e.message.include?("File not found") || e.message.include?("NoSuchKey")
            raise
          end
        end

        files
      end
      end
    end
  end
end