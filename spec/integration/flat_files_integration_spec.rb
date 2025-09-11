# frozen_string_literal: true

require "spec_helper"

# Integration tests that require real S3 credentials
# These tests will be skipped unless POLYGON_S3_ACCESS_KEY_ID and POLYGON_S3_SECRET_ACCESS_KEY are set
RSpec.describe Polymux::Api::FlatFiles, :integration, type: :integration do
  let(:s3_access_key_id) { ENV["POLYGON_S3_ACCESS_KEY_ID"] }
  let(:s3_secret_access_key) { ENV["POLYGON_S3_SECRET_ACCESS_KEY"] }

  before do
    skip "Integration tests require POLYGON_S3_ACCESS_KEY_ID and POLYGON_S3_SECRET_ACCESS_KEY" unless s3_access_key_id && s3_secret_access_key
  end

  describe "S3 connectivity" do
    it "can connect to Polygon.io S3 endpoint and list files" do
      config = Polymux::Config.new(
        api_key: "test_key", # Not needed for S3 operations
        s3_access_key_id: s3_access_key_id,
        s3_secret_access_key: s3_secret_access_key
      )

      client = Polymux::Client.new(config)
      flat_files = client.flat_files

      # Try to list files for a recent date
      recent_date = (Date.today - 7).strftime("%Y-%m-%d")

      begin
        files = flat_files.list_files("stocks", "trades", recent_date)
        # If we get here, S3 connection is working
        expect(files).to be_an(Array)
        puts "✅ S3 connectivity test passed - found #{files.length} files"
      rescue Polymux::Api::Error => e
        # This is expected if no files exist for the date
        if e.message.include?("No files found") || e.message.include?("NoSuchKey")
          puts "✅ S3 connectivity test passed - no files found for #{recent_date} (expected)"
          expect(true).to be true
        else
          # Re-raise unexpected errors
          raise e
        end
      end
    end

    it "provides helpful error messages for authentication failures" do
      config = Polymux::Config.new(
        api_key: "test_key",
        s3_access_key_id: "invalid_key",
        s3_secret_access_key: "invalid_secret"
      )

      client = Polymux::Client.new(config)
      flat_files = client.flat_files

      expect {
        flat_files.list_files("stocks", "trades", "2024-01-01")
      }.to raise_error(Polymux::Api::Error) do |error|
        expect(error.message.downcase).to include("access").or include("credentials").or include("authentication")
      end
    end
  end
end
