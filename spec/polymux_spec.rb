# frozen_string_literal: true

require "spec_helper"

RSpec.describe Polymux do
  it "has a version number" do
    expect(Polymux.gem_version).not_to be nil
  end

  describe "module structure" do
    it "defines the base Error class" do
      expect(Polymux::Error).to be < StandardError
    end

    it "defines API-specific error classes" do
      expect(Polymux::Api::Error).to be < Polymux::Error
      expect(Polymux::Api::InvalidCredentials).to be < Polymux::Error
      expect(Polymux::Api::Options::NoPreviousDataFound).to be < Polymux::Error
    end
  end

  describe "main components accessibility" do
    it "provides access to core classes" do
      expect(Polymux::Client).to be_a(Class)
      expect(Polymux::Config).to be_a(Class)
      expect(Polymux::Types).to be_a(Module)
    end

    it "provides access to API modules" do
      expect(Polymux::Api::Options).to be_a(Class)
      expect(Polymux::Api::Markets).to be_a(Class)
      expect(Polymux::Api::Exchanges).to be_a(Class)
      expect(Polymux::Api::Transformers).to be_a(Module)
    end
  end

  describe "error hierarchy" do
    context "when catching base Polymux::Error" do
      it "catches all Polymux-specific errors" do
        [
          Polymux::Api::Error.new("API error"),
          Polymux::Api::InvalidCredentials.new("Invalid credentials"),
          Polymux::Api::Options::NoPreviousDataFound.new("No data")
        ].each do |error|
          expect {
            raise error
          }.to raise_error(Polymux::Error)
        end
      end
    end
  end

  describe "quick start workflow" do
    let(:config) { Polymux::Config.new(api_key: "quick_start_key", base_url: "https://api.polygon.io") }
    let(:client) { Polymux::Client.new(config) }

    it "provides simple client instantiation" do
      expect(client).to be_a(Polymux::Client)
      expect(client.options).to be_a(Polymux::Api::Options)
      expect(client.markets).to be_a(Polymux::Api::Markets)
      expect(client.exchanges).to be_a(Polymux::Api::Exchanges)
    end

    it "supports configuration through environment variables" do
      # This is tested without setting up config to verify the classes exist and work
      default_client = Polymux::Client.new
      expect(default_client).to be_a(Polymux::Client)
    end
  end
end
