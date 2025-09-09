# frozen_string_literal: true

require "dry/struct"
require "forwardable"
require_relative "../../types"

module Polymux
  module Api
    module FlatFiles
      # Represents metadata information for a Flat Files data file.
      #
      # Contains comprehensive information about a specific flat file including
      # size, modification dates, data coverage, and access details. This
      # structure is returned when listing available files or getting file
      # metadata before download.
      #
      # @example File discovery workflow
      #   files = client.flat_files.list_files("stocks", "trades", "2024-01-15")
      #   file_info = files.first
      #
      #   puts "File: #{file_info.key}"
      #   puts "Size: #{file_info.size_mb.round(2)} MB"
      #   puts "Records: #{file_info.record_count}"
      #   puts "Last modified: #{file_info.last_modified}"
      class FileInfo < Dry::Struct
        transform_keys(&:to_sym)

        # S3 key path for the file
        # @return [String] Full S3 key path (e.g., "stocks/trades/2024/01/15/trades.csv.gz")
        attribute :key, Types::String

        # Asset class for this file
        # @return [String] Asset class ("stocks", "options", "crypto", "forex")
        attribute :asset_class, Types::String

        # Data type contained in this file
        # @return [String] Data type ("trades", "quotes", "aggregates_minute", "aggregates_day")
        attribute :data_type, Types::String

        # Trading date covered by this file
        # @return [String] Date in YYYY-MM-DD format
        attribute :date, Types::String

        # File size in bytes
        # @return [Integer] Size in bytes
        attribute :size, Types::Integer

        # File size in megabytes for human-readable display
        # @return [Float] Size in MB
        def size_mb
          size / 1_048_576.0
        end

        # Last modification timestamp
        # @return [Time, nil] When the file was last modified
        attribute :last_modified, Types.Instance(Time).optional

        # ETag for file integrity verification
        # @return [String, nil] S3 ETag hash
        attribute :etag, Types::String.optional

        # Estimated number of data records in the file
        # @return [Integer, nil] Record count (if available)
        attribute :record_count, Types::Integer.optional

        # Compression format of the file
        # @return [String] Compression type ("gzip", "none")
        def compression
          key.end_with?('.gz') ? 'gzip' : 'none'
        end

        # Generate a human-readable filename for local storage
        # @return [String] Filename for local download
        def suggested_filename
          "#{asset_class}_#{data_type}_#{date}.csv#{compression == 'gzip' ? '.gz' : ''}"
        end

        # Check if file is compressed
        # @return [Boolean] true if file is compressed
        def compressed?
          compression == 'gzip'
        end

        # Create FileInfo object from S3 object data.
        #
        # @param s3_object [Aws::S3::Object] S3 object from AWS SDK
        # @return [FileInfo] Transformed FileInfo object
        # @api private
        def self.from_s3_object(s3_object)
          # Parse key to extract asset_class, data_type, and date
          # Expected format: "stocks/trades/2024/01/15/trades.csv.gz"
          key_parts = s3_object.key.split('/')
          
          new(
            key: s3_object.key,
            asset_class: key_parts[0],
            data_type: key_parts[1],
            date: "#{key_parts[2]}-#{key_parts[3]}-#{key_parts[4]}",
            size: s3_object.size,
            last_modified: s3_object.last_modified,
            etag: s3_object.etag&.gsub('"', ''), # Remove quotes from ETag
            record_count: nil # Would need to be populated from metadata if available
          )
        end
      end

      # Represents the result of a bulk download operation.
      #
      # Contains comprehensive information about the success/failure status
      # of a bulk download, including file-level results, error handling,
      # and performance metrics. Used for tracking multi-file operations.
      #
      # @example Bulk download with error handling
      #   criteria = {
      #     asset_class: "stocks",
      #     data_type: "trades", 
      #     date_range: "2024-01-01..2024-01-05"
      #   }
      #   result = client.flat_files.bulk_download(criteria, "/data/downloads")
      #
      #   puts "Downloaded: #{result.successful_downloads.length}/#{result.total_files}"
      #   puts "Failed: #{result.failed_downloads.length}"
      #   puts "Total size: #{result.total_size_mb.round(2)} MB"
      #
      #   result.failed_downloads.each do |failure|
      #     puts "Failed: #{failure[:file]} - #{failure[:error]}"
      #   end
      class BulkDownloadResult < Dry::Struct
        transform_keys(&:to_sym)

        # Total number of files attempted
        # @return [Integer] Total files in the bulk operation
        attribute :total_files, Types::Integer

        # Number of successfully downloaded files
        # @return [Integer] Count of successful downloads
        attribute :successful_files, Types::Integer

        # Number of failed downloads
        # @return [Integer] Count of failed downloads
        attribute :failed_files, Types::Integer

        # Total bytes downloaded successfully
        # @return [Integer] Total bytes transferred
        attribute :total_bytes, Types::Integer

        # Total download time in seconds
        # @return [Float] Duration of the bulk operation
        attribute :duration_seconds, Types::Float

        # Array of successfully downloaded file details
        # @return [Array<Hash>] Success details with :file, :local_path, :size
        attribute :successful_downloads, Types::Array

        # Array of failed download details
        # @return [Array<Hash>] Failure details with :file, :error, :retry_count
        attribute :failed_downloads, Types::Array

        # Local directory where files were downloaded
        # @return [String] Destination directory path
        attribute :destination_directory, Types::String

        # Timestamp when the bulk operation started
        # @return [Time] Start time
        attribute :started_at, Types.Instance(Time)

        # Timestamp when the bulk operation completed
        # @return [Time] End time
        attribute :completed_at, Types.Instance(Time)

        # Calculate download success rate as percentage
        # @return [Float] Success rate (0.0 to 100.0)
        def success_rate
          return 0.0 if total_files == 0
          (successful_files.to_f / total_files) * 100.0
        end

        # Calculate total downloaded size in megabytes
        # @return [Float] Size in MB
        def total_size_mb
          total_bytes / 1_048_576.0
        end

        # Calculate average download speed in MB/s
        # @return [Float] Speed in MB/s
        def average_speed_mbps
          return 0.0 if duration_seconds == 0
          total_size_mb / duration_seconds
        end

        # Check if the bulk operation was completely successful
        # @return [Boolean] true if all files downloaded successfully
        def success?
          failed_files == 0
        end

        # Check if the bulk operation had any failures
        # @return [Boolean] true if any downloads failed
        def partial_failure?
          failed_files > 0 && successful_files > 0
        end

        # Check if the bulk operation completely failed
        # @return [Boolean] true if no files were downloaded successfully
        def complete_failure?
          successful_files == 0
        end

        # Generate a summary report of the bulk operation
        # @return [String] Human-readable summary
        def summary
          status = if success?
                     "SUCCESS"
                   elsif partial_failure?
                     "PARTIAL"
                   else
                     "FAILED"
                   end

          <<~SUMMARY
            Bulk Download Summary [#{status}]
            ================================
            Total Files: #{total_files}
            Successful: #{successful_files} (#{success_rate.round(1)}%)
            Failed: #{failed_files}
            
            Data Transfer:
            Total Size: #{total_size_mb.round(2)} MB
            Duration: #{duration_seconds.round(2)} seconds
            Average Speed: #{average_speed_mbps.round(2)} MB/s
            
            Destination: #{destination_directory}
            Started: #{started_at}
            Completed: #{completed_at}
          SUMMARY
        end
      end

      # Represents detailed metadata about a specific flat file.
      #
      # Provides comprehensive information about file contents, data quality,
      # and processing details. This structure is returned when requesting
      # detailed metadata for a specific file before download.
      #
      # @example Metadata inspection before download
      #   metadata = client.flat_files.get_file_metadata("stocks/trades/2024/01/15/trades.csv.gz")
      #
      #   puts "Tickers covered: #{metadata.ticker_count}"
      #   puts "Trade records: #{metadata.record_count}"
      #   puts "Time range: #{metadata.first_timestamp} to #{metadata.last_timestamp}"
      #   puts "Data quality: #{metadata.quality_score}/100"
      class FileMetadata < Dry::Struct
        extend Forwardable
        transform_keys(&:to_sym)

        # File information (embedded FileInfo object)
        # @return [FileInfo] Basic file details
        attribute :file_info, FileInfo

        # Total number of records in the file
        # @return [Integer, nil] Record count
        attribute :record_count, Types::Integer.optional

        # Number of unique tickers covered
        # @return [Integer, nil] Ticker count  
        attribute :ticker_count, Types::Integer.optional

        # Earliest timestamp in the dataset
        # @return [Time, nil] First data timestamp
        attribute :first_timestamp, Types.Instance(Time).optional

        # Latest timestamp in the dataset
        # @return [Time, nil] Last data timestamp
        attribute :last_timestamp, Types.Instance(Time).optional

        # Data quality score (0-100)
        # @return [Integer, nil] Quality score
        attribute :quality_score, Types::Integer.optional

        # List of most active tickers in the file
        # @return [Array<String>] Top ticker symbols
        attribute :top_tickers, Types::Array.of(Types::String).optional

        # File processing timestamp
        # @return [Time, nil] When the file was processed/created
        attribute :processed_at, Types.Instance(Time).optional

        # Data completeness percentage
        # @return [Float, nil] Completeness score (0.0 to 100.0)
        attribute :completeness, Types::Float.optional

        # Checksum for data integrity verification
        # @return [String, nil] SHA256 checksum
        attribute :checksum, Types::String.optional

        # Schema version of the data format
        # @return [String, nil] Schema version identifier
        attribute :schema_version, Types::String.optional

        # Delegate basic file operations to embedded FileInfo
        def_delegators :file_info, :key, :asset_class, :data_type, :date, 
                       :size, :size_mb, :last_modified, :etag, :compression,
                       :suggested_filename, :compressed?

        # Calculate data density (records per MB)
        # @return [Float, nil] Records per megabyte
        def records_per_mb
          return nil unless record_count && file_info.size > 0
          record_count / file_info.size_mb
        end

        # Calculate time span covered by the data
        # @return [Float, nil] Duration in hours
        def time_span_hours
          return nil unless first_timestamp && last_timestamp
          (last_timestamp - first_timestamp) / 3600.0
        end

        # Check if metadata indicates high-quality data
        # @return [Boolean] true if quality metrics are good
        def high_quality?
          return false unless quality_score && completeness
          quality_score >= 90 && completeness >= 95.0
        end

        # Return content type for the file
        # @return [String] MIME content type
        def content_type
          "text/csv"
        end

        # Generate a detailed metadata report
        # @return [String] Human-readable metadata summary
        def detailed_report
          <<~REPORT
            File Metadata Report
            ===================
            File: #{key}
            Asset Class: #{asset_class.upcase}
            Data Type: #{data_type.upcase}
            Date: #{date}
            
            File Details:
            Size: #{size_mb.round(2)} MB (#{size.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse} bytes)
            Compression: #{compression.upcase}
            Last Modified: #{last_modified}
            
            Data Details:
            Records: #{record_count&.to_s&.reverse&.gsub(/(\d{3})(?=\d)/, '\\1,')&.reverse || 'N/A'}
            Tickers: #{ticker_count || 'N/A'}
            Density: #{records_per_mb&.round(0) || 'N/A'} records/MB
            
            Quality Metrics:
            Quality Score: #{quality_score || 'N/A'}/100
            Completeness: #{completeness&.round(1) || 'N/A'}%
            Status: #{high_quality? ? 'HIGH QUALITY' : 'STANDARD'}
            
            Time Coverage:
            First: #{first_timestamp}
            Last: #{last_timestamp}
            Span: #{time_span_hours&.round(1) || 'N/A'} hours
          REPORT
        end
      end

      # Represents a data catalog overview.
      #
      # Contains information about available asset classes, data types, 
      # and overall data coverage across the flat files system.
      class DataCatalog < Dry::Struct
        transform_keys(&:to_sym)

        # Available asset classes
        # @return [Array<String>] Asset class names
        attribute :asset_classes, Types::Array.of(Types::String)

        # Available data types
        # @return [Array<String>] Data type names
        attribute :data_types, Types::Array.of(Types::String)

        # Total number of files available
        # @return [Integer] File count
        attribute :total_files, Types::Integer

        # Earliest date with data coverage
        # @return [Date] Coverage start date
        attribute :coverage_start, Types::Date

        # Latest date with data coverage
        # @return [Date] Coverage end date
        attribute :coverage_end, Types::Date
      end

      # Represents file availability information.
      #
      # Contains details about whether a specific file exists and 
      # reasons why it might not be available.
      class FileAvailability < Dry::Struct
        transform_keys(&:to_sym)

        # Whether the file exists
        # @return [Boolean] File existence status
        attribute :exists, Types::Bool

        # Reason why file is not available (if applicable)
        # @return [Symbol, nil] Reason code
        attribute :reason, Types::Symbol.optional

        # Nearest date with available data
        # @return [Date, nil] Alternative date
        attribute :nearest_available_date, Types::Date.optional

        # Latest date through which data is available
        # @return [Date, nil] Data availability boundary
        attribute :data_availability_through, Types::Date.optional
      end

      # Represents trade data downloaded from flat files.
      #
      # Contains parsed trade records with helper methods for analysis.
      class TradeData < Dry::Struct
        transform_keys(&:to_sym)

        # Array of trade records
        # @return [Array] Trade objects
        attribute :trades, Types::Array
      end

      # Represents authentication test results.
      #
      # Contains information about credential validation status.
      class AuthenticationResult < Dry::Struct
        transform_keys(&:to_sym)

        # Whether S3 credentials are valid
        # @return [Boolean] Credential validity
        attribute :s3_credentials_valid, Types::Bool

        # Error details if validation failed
        # @return [String, nil] Error information
        attribute :error_details, Types::String.optional

        # Recommended action to resolve issues
        # @return [String, nil] Resolution steps
        attribute :recommended_action, Types::String.optional
      end

      # Represents data integrity validation results.
      #
      # Contains comprehensive validation information about downloaded data.
      class IntegrityReport < Dry::Struct
        transform_keys(&:to_sym)

        # Whether checksum validation passed
        # @return [Boolean] Checksum validity
        attribute :checksum_valid, Types::Bool

        # Expected checksum value
        # @return [String] Expected checksum
        attribute :expected_checksum, Types::String

        # Actual checksum value
        # @return [String] Calculated checksum
        attribute :actual_checksum, Types::String

        # Expected number of records
        # @return [Integer] Expected record count
        attribute :expected_record_count, Types::Integer

        # Actual number of records found
        # @return [Integer] Actual record count
        attribute :actual_record_count, Types::Integer

        # Whether schema validation passed
        # @return [Boolean] Schema validity
        attribute :schema_valid, Types::Bool

        # List of missing required fields
        # @return [Array<String>] Missing field names
        attribute :missing_fields, Types::Array.of(Types::String)

        # List of invalid records found
        # @return [Array] Invalid record details
        attribute :invalid_records, Types::Array

        # Whether timestamp continuity is maintained
        # @return [Boolean] Timestamp continuity
        attribute :timestamp_continuity, Types::Bool

        # List of issues detected during validation
        # @return [Array<String>] Issue descriptions
        attribute :issues_detected, Types::Array.of(Types::String)

        # Recommended actions to address issues
        # @return [Array<String>] Action recommendations
        attribute :recommended_actions, Types::Array.of(Types::String)

        # Overall validation status
        # @return [Symbol] Status (:valid, :invalid, :warning)
        attribute :overall_status, Types::Symbol

        # When validation was performed
        # @return [Time] Validation timestamp
        attribute :validation_timestamp, Types.Instance(Time)
      end
    end
  end
end