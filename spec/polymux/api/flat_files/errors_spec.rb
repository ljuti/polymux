# frozen_string_literal: true

require "spec_helper"

RSpec.describe Polymux::Api::FlatFiles::Error do
  it "is a subclass of StandardError" do
    expect(described_class).to be < StandardError
  end

  it "can be raised with a message" do
    expect { raise described_class, "Test error" }.to raise_error(described_class, "Test error")
  end
end

RSpec.describe Polymux::Api::FlatFiles::AuthenticationError do
  it "is a subclass of FlatFiles::Error" do
    expect(described_class).to be < Polymux::Api::FlatFiles::Error
  end

  describe "#initialize" do
    it "accepts message only" do
      error = described_class.new("Authentication failed")
      
      expect(error.message).to eq("Authentication failed")
      expect(error.error_code).to be_nil
      expect(error.resolution_steps).to eq([])
    end

    it "accepts message with error code" do
      error = described_class.new("Authentication failed", error_code: "InvalidAccessKeyId")
      
      expect(error.message).to eq("Authentication failed")
      expect(error.error_code).to eq("InvalidAccessKeyId")
      expect(error.resolution_steps).to eq([])
    end

    it "accepts message with resolution steps" do
      steps = ["Check your credentials", "Regenerate keys"]
      error = described_class.new("Authentication failed", resolution_steps: steps)
      
      expect(error.message).to eq("Authentication failed")
      expect(error.error_code).to be_nil
      expect(error.resolution_steps).to eq(steps)
    end

    it "accepts all parameters" do
      steps = ["Check dashboard", "Contact support"]
      error = described_class.new(
        "Token expired",
        error_code: "TokenExpired",
        resolution_steps: steps
      )
      
      expect(error.message).to eq("Token expired")
      expect(error.error_code).to eq("TokenExpired")
      expect(error.resolution_steps).to eq(steps)
    end
  end

  describe "attribute readers" do
    let(:error) do
      described_class.new(
        "Test error",
        error_code: "TestCode",
        resolution_steps: ["Step 1", "Step 2"]
      )
    end

    it "provides error_code reader" do
      expect(error.error_code).to eq("TestCode")
    end

    it "provides resolution_steps reader" do
      expect(error.resolution_steps).to eq(["Step 1", "Step 2"])
    end
  end

  describe "inheritance behavior" do
    it "can be rescued as FlatFiles::Error" do
      expect {
        begin
          raise described_class, "Auth error"
        rescue Polymux::Api::FlatFiles::Error => e
          expect(e).to be_a(described_class)
          raise "caught correctly"
        end
      }.to raise_error("caught correctly")
    end

    it "can be rescued as StandardError" do
      expect {
        begin
          raise described_class, "Auth error"
        rescue StandardError => e
          expect(e).to be_a(described_class)
          raise "caught correctly"
        end
      }.to raise_error("caught correctly")
    end
  end
end

RSpec.describe Polymux::Api::FlatFiles::FileNotFoundError do
  it "is a subclass of FlatFiles::Error" do
    expect(described_class).to be < Polymux::Api::FlatFiles::Error
  end

  describe "#initialize" do
    it "accepts message only" do
      error = described_class.new("File not found")
      
      expect(error.message).to eq("File not found")
      expect(error.requested_date).to be_nil
      expect(error.reason).to be_nil
      expect(error.alternative_dates).to eq([])
      expect(error.data_availability_through).to be_nil
    end

    it "accepts message with requested_date" do
      date = Date.new(2024, 12, 25)
      error = described_class.new("Holiday file not found", requested_date: date)
      
      expect(error.message).to eq("Holiday file not found")
      expect(error.requested_date).to eq(date)
      expect(error.reason).to be_nil
      expect(error.alternative_dates).to eq([])
      expect(error.data_availability_through).to be_nil
    end

    it "accepts message with reason" do
      error = described_class.new("Weekend file not found", reason: :weekend)
      
      expect(error.message).to eq("Weekend file not found")
      expect(error.requested_date).to be_nil
      expect(error.reason).to eq(:weekend)
      expect(error.alternative_dates).to eq([])
      expect(error.data_availability_through).to be_nil
    end

    it "accepts message with alternative dates" do
      alternatives = [Date.new(2024, 12, 24), Date.new(2024, 12, 26)]
      error = described_class.new("File not found", alternative_dates: alternatives)
      
      expect(error.message).to eq("File not found")
      expect(error.requested_date).to be_nil
      expect(error.reason).to be_nil
      expect(error.alternative_dates).to eq(alternatives)
      expect(error.data_availability_through).to be_nil
    end

    it "accepts message with data availability boundary" do
      boundary = Date.new(2024, 3, 15)
      error = described_class.new("Future date", data_availability_through: boundary)
      
      expect(error.message).to eq("Future date")
      expect(error.requested_date).to be_nil
      expect(error.reason).to be_nil
      expect(error.alternative_dates).to eq([])
      expect(error.data_availability_through).to eq(boundary)
    end

    it "accepts all parameters" do
      requested = Date.new(2024, 12, 25)
      alternatives = [Date.new(2024, 12, 24)]
      boundary = Date.new(2024, 12, 31)
      
      error = described_class.new(
        "Christmas file not found",
        requested_date: requested,
        reason: :market_holiday,
        alternative_dates: alternatives,
        data_availability_through: boundary
      )
      
      expect(error.message).to eq("Christmas file not found")
      expect(error.requested_date).to eq(requested)
      expect(error.reason).to eq(:market_holiday)
      expect(error.alternative_dates).to eq(alternatives)
      expect(error.data_availability_through).to eq(boundary)
    end
  end

  describe "attribute readers" do
    let(:error) do
      described_class.new(
        "Test file not found",
        requested_date: Date.new(2024, 1, 15),
        reason: :test_reason,
        alternative_dates: [Date.new(2024, 1, 14)],
        data_availability_through: Date.new(2024, 1, 31)
      )
    end

    it "provides requested_date reader" do
      expect(error.requested_date).to eq(Date.new(2024, 1, 15))
    end

    it "provides reason reader" do
      expect(error.reason).to eq(:test_reason)
    end

    it "provides alternative_dates reader" do
      expect(error.alternative_dates).to eq([Date.new(2024, 1, 14)])
    end

    it "provides data_availability_through reader" do
      expect(error.data_availability_through).to eq(Date.new(2024, 1, 31))
    end
  end

  describe "common use cases" do
    it "handles market holiday scenario" do
      error = described_class.new(
        "File not found: market holiday on 2024-12-25",
        requested_date: Date.parse("2024-12-25"),
        reason: :market_holiday,
        alternative_dates: [Date.parse("2024-12-24")]
      )
      
      expect(error.requested_date).to eq(Date.parse("2024-12-25"))
      expect(error.reason).to eq(:market_holiday)
      expect(error.alternative_dates).to include(Date.parse("2024-12-24"))
    end

    it "handles weekend scenario" do
      error = described_class.new(
        "File not found: weekend date 2024-03-16",
        requested_date: Date.parse("2024-03-16"),
        reason: :weekend,
        alternative_dates: [Date.parse("2024-03-15")]
      )
      
      expect(error.requested_date).to eq(Date.parse("2024-03-16"))
      expect(error.reason).to eq(:weekend)
      expect(error.alternative_dates).to include(Date.parse("2024-03-15"))
    end

    it "handles future date scenario" do
      error = described_class.new(
        "File not found: future date requested",
        reason: :future_date,
        data_availability_through: Date.today - 1
      )
      
      expect(error.reason).to eq(:future_date)
      expect(error.data_availability_through).to eq(Date.today - 1)
    end
  end

  describe "inheritance behavior" do
    it "can be rescued as FlatFiles::Error" do
      expect {
        begin
          raise described_class, "File not found"
        rescue Polymux::Api::FlatFiles::Error => e
          expect(e).to be_a(described_class)
          raise "caught correctly"
        end
      }.to raise_error("caught correctly")
    end
  end
end

RSpec.describe Polymux::Api::FlatFiles::NetworkError do
  it "is a subclass of FlatFiles::Error" do
    expect(described_class).to be < Polymux::Api::FlatFiles::Error
  end

  it "can be raised with a message" do
    expect { raise described_class, "Network timeout" }.to raise_error(described_class, "Network timeout")
  end

  it "can be raised without a message" do
    expect { raise described_class }.to raise_error(described_class)
  end

  describe "inheritance behavior" do
    it "can be rescued as FlatFiles::Error" do
      expect {
        begin
          raise described_class, "Connection failed"
        rescue Polymux::Api::FlatFiles::Error => e
          expect(e).to be_a(described_class)
          raise "caught correctly"
        end
      }.to raise_error("caught correctly")
    end
  end

  describe "common network error messages" do
    it "handles timeout errors" do
      error = described_class.new("Request Timeout")
      expect(error.message).to eq("Request Timeout")
    end

    it "handles connection errors" do
      error = described_class.new("Connection interrupted")
      expect(error.message).to eq("Connection interrupted")
    end

    it "handles service unavailable errors" do
      error = described_class.new("Service Unavailable")
      expect(error.message).to eq("Service Unavailable")
    end
  end
end

RSpec.describe Polymux::Api::FlatFiles::IntegrityError do
  it "is a subclass of FlatFiles::Error" do
    expect(described_class).to be < Polymux::Api::FlatFiles::Error
  end

  it "can be raised with a message" do
    expect { raise described_class, "Checksum mismatch" }.to raise_error(described_class, "Checksum mismatch")
  end

  it "can be raised without a message" do
    expect { raise described_class }.to raise_error(described_class)
  end

  describe "inheritance behavior" do
    it "can be rescued as FlatFiles::Error" do
      expect {
        begin
          raise described_class, "Data corruption detected"
        rescue Polymux::Api::FlatFiles::Error => e
          expect(e).to be_a(described_class)
          raise "caught correctly"
        end
      }.to raise_error("caught correctly")
    end
  end

  describe "common integrity error scenarios" do
    it "handles checksum validation failures" do
      error = described_class.new("SHA256 checksum validation failed")
      expect(error.message).to eq("SHA256 checksum validation failed")
    end

    it "handles record count mismatches" do
      error = described_class.new("Expected 1000000 records, found 999998")
      expect(error.message).to eq("Expected 1000000 records, found 999998")
    end

    it "handles schema validation failures" do
      error = described_class.new("Missing required field: timestamp")
      expect(error.message).to eq("Missing required field: timestamp")
    end
  end
end