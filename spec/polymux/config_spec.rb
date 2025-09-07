# frozen_string_literal: true

require "spec_helper"

RSpec.describe Polymux::Config, :skip_config_setup do
  describe "initialization" do
    context "with default values" do
      it "sets default base_url to Polygon.io API endpoint" do
        config = described_class.new

        expect(config.base_url).to eq("https://api.polygon.io")
      end

      it "leaves api_key as nil when not provided" do
        config = described_class.new

        expect(config.api_key).to be_nil
      end
    end

    context "with direct parameters" do
      it "accepts api_key parameter" do
        config = described_class.new(api_key: "test_key_123")

        expect(config.api_key).to eq("test_key_123")
      end

      it "accepts base_url parameter" do
        config = described_class.new(base_url: "https://custom.api.endpoint")

        expect(config.base_url).to eq("https://custom.api.endpoint")
      end

      it "accepts both api_key and base_url parameters" do
        config = described_class.new(
          api_key: "direct_key_456",
          base_url: "https://test.polygon.io"
        )

        expect(config.api_key).to eq("direct_key_456")
        expect(config.base_url).to eq("https://test.polygon.io")
      end
    end

    context "with environment variables" do
      before do
        ENV["POLYMUX_API_KEY"] = "env_api_key_789"
        ENV["POLYMUX_BASE_URL"] = "https://env.polygon.io"
      end

      after do
        ENV.delete("POLYMUX_API_KEY")
        ENV.delete("POLYMUX_BASE_URL")
      end

      it "loads configuration from environment variables" do
        config = described_class.new

        expect(config.api_key).to eq("env_api_key_789")
        expect(config.base_url).to eq("https://env.polygon.io")
      end

      it "allows direct parameters to override environment variables" do
        config = described_class.new(
          api_key: "override_key",
          base_url: "https://override.api"
        )

        expect(config.api_key).to eq("override_key")
        expect(config.base_url).to eq("https://override.api")
      end
    end
  end

  describe "configuration inheritance" do
    it "inherits from Anyway::Config" do
      expect(described_class.superclass).to eq(Anyway::Config)
    end

    it "has polymux as config namespace" do
      expect(described_class.config_name).to eq("polymux")
    end
  end

  describe "attribute configuration" do
    it "defines api_key as configurable attribute" do
      config = described_class.new(api_key: "test_key")
      expect(config.api_key).to eq("test_key")
    end

    it "defines base_url as configurable attribute with default" do
      config = described_class.new
      expect(config.base_url).to eq("https://api.polygon.io")
    end
  end

  describe "validation behavior" do
    context "when api_key is missing" do
      it "allows initialization without api_key" do
        expect { described_class.new }.not_to raise_error
      end

      it "returns nil for api_key" do
        config = described_class.new
        expect(config.api_key).to be_nil
      end
    end

    context "when base_url is missing" do
      it "uses default base_url" do
        config = described_class.new(api_key: "test_key")
        expect(config.base_url).to eq("https://api.polygon.io")
      end
    end
  end
end
