# frozen_string_literal: true

require "spec_helper"

RSpec.describe Polymux::Api::Markets do
  let(:config) { Polymux::Config.new(api_key: "test_key_123", base_url: "https://api.polygon.io") }
  let(:client) { Polymux::Client.new(config) }
  let(:markets_api) { described_class.new(client) }

  describe "inheritance" do
    it "inherits from PolymuxRestHandler" do
      expect(described_class.superclass).to eq(Polymux::Client::PolymuxRestHandler)
    end

    it "has access to the parent client" do
      expect(markets_api.send(:_client)).to eq(client)
    end
  end

  describe "#status" do
    before do
      stub_request(:get, "https://api.polygon.io/v1/marketstatus/now")
        .with(headers: {"Authorization" => "Bearer test_key_123"})
        .to_return(
          status: 200,
          body: load_fixture("market_status"),
          headers: {"Content-Type" => "application/json"}
        )
    end

    it "makes GET request to market status endpoint" do
      markets_api.status

      expect(a_request(:get, "https://api.polygon.io/v1/marketstatus/now"))
        .to have_been_made.once
    end

    it "returns a Status object" do
      status = markets_api.status

      expect(status).to be_a(described_class::Status)
    end

    it "transforms API data using market_status transformer" do
      status = markets_api.status

      expect(status.status).to eq("open")
      expect(status.after_hours).to eq(false)
      expect(status.pre_market).to eq(false)
      expect(status.exchanges).to eq({"nasdaq" => "open", "nyse" => "open"})
      expect(status.indices).to eq({"s_and_p" => "open", "nasdaq" => "open"})
    end
  end

  describe "#holidays" do
    before do
      stub_request(:get, "https://api.polygon.io/v1/marketstatus/upcoming")
        .with(headers: {"Authorization" => "Bearer test_key_123"})
        .to_return(
          status: 200,
          body: load_fixture("market_holidays"),
          headers: {"Content-Type" => "application/json"}
        )
    end

    it "makes GET request to market holidays endpoint" do
      markets_api.holidays

      expect(a_request(:get, "https://api.polygon.io/v1/marketstatus/upcoming"))
        .to have_been_made.once
    end

    it "returns an array of Holidays objects" do
      holidays = markets_api.holidays

      expect(holidays).to be_an(Array)
      expect(holidays.length).to eq(3)
      expect(holidays).to all(be_a(described_class::Holidays))
    end

    it "transforms API data correctly" do
      holidays = markets_api.holidays
      first_holiday = holidays.first

      expect(first_holiday.name).to eq("Independence Day")
      expect(first_holiday.date).to eq("2024-07-04")
      expect(first_holiday.status).to eq("closed")
      expect(first_holiday.exchange).to eq("XNYS")
    end
  end

  describe "::Status" do
    let(:status_data) do
      {
        status: "open",
        after_hours: false,
        pre_market: true,
        exchanges: {"nasdaq" => "open"},
        currencies: {"fx" => "open"},
        indices: {"s_and_p" => "open"}
      }
    end
    let(:status) { described_class::Status.new(status_data) }

    describe "initialization" do
      it "accepts status data hash" do
        status_instance = described_class::Status.new(status_data)
        expect(status_instance).to be_a(described_class::Status)
        expect(status_instance.status).to eq("open")
      end

      it "transforms keys to symbols" do
        expect(status.status).to eq("open")
        expect(status.after_hours).to eq(false)
        expect(status.pre_market).to eq(true)
      end
    end

    describe "#closed?" do
      it "returns true when status is closed" do
        closed_status = described_class::Status.new(status: "closed")
        expect(closed_status.closed?).to be true
      end

      it "returns false when status is not closed" do
        expect(status.closed?).to be false
      end
    end

    describe "#open?" do
      it "returns true when status is not closed" do
        expect(status.open?).to be true
      end

      it "returns false when status is closed" do
        closed_status = described_class::Status.new(status: "closed")
        expect(closed_status.open?).to be false
      end
    end

    describe "#extended_hours?" do
      it "returns true when status is extended-hours" do
        extended_status = described_class::Status.new(status: "extended-hours")
        expect(extended_status.extended_hours?).to be true
      end

      it "returns false when status is not extended-hours" do
        expect(status.extended_hours?).to be false
      end
    end

    describe ".from_api" do
      let(:raw_api_data) do
        {
          "market" => "open",
          "afterHours" => false,
          "earlyHours" => true,
          "exchanges" => {"nasdaq" => "open"}
        }
      end

      it "creates Status object from raw API data" do
        status = described_class::Status.from_api(raw_api_data)

        expect(status).to be_a(described_class::Status)
        expect(status.status).to eq("open")
        expect(status.after_hours).to eq(false)
        expect(status.pre_market).to eq(true)
        expect(status.exchanges).to eq({"nasdaq" => "open"})
      end
    end

    describe "optional attributes" do
      it "handles missing optional attributes" do
        minimal_status = described_class::Status.new(status: "open")

        expect(minimal_status.status).to eq("open")
        expect(minimal_status.after_hours).to be_nil
        expect(minimal_status.pre_market).to be_nil
        expect(minimal_status.exchanges).to be_nil
      end
    end
  end

  describe "::Holidays" do
    let(:holiday_data) do
      {
        date: "2024-07-04",
        exchange: "XNYS",
        name: "Independence Day",
        status: "closed"
      }
    end
    let(:holiday) { described_class::Holidays.new(holiday_data) }

    describe "initialization" do
      it "accepts holiday data hash" do
        holiday_instance = described_class::Holidays.new(holiday_data)
        expect(holiday_instance).to be_a(described_class::Holidays)
        expect(holiday_instance.name).to eq("Independence Day")
      end

      it "transforms keys to symbols" do
        expect(holiday.date).to eq("2024-07-04")
        expect(holiday.exchange).to eq("XNYS")
        expect(holiday.name).to eq("Independence Day")
        expect(holiday.status).to eq("closed")
      end
    end

    describe "#closed?" do
      it "returns true when status is closed" do
        expect(holiday.closed?).to be true
      end

      it "returns false when status is not closed" do
        early_close = described_class::Holidays.new(status: "early-close")
        expect(early_close.closed?).to be false
      end
    end

    describe "#early_close?" do
      it "returns true when status is early-close" do
        early_close = described_class::Holidays.new(status: "early-close")
        expect(early_close.early_close?).to be true
      end

      it "returns false when status is not early-close" do
        expect(holiday.early_close?).to be false
      end
    end

    describe "optional attributes" do
      it "handles missing optional attributes" do
        minimal_holiday = described_class::Holidays.new({})

        expect(minimal_holiday.date).to be_nil
        expect(minimal_holiday.exchange).to be_nil
        expect(minimal_holiday.name).to be_nil
        expect(minimal_holiday.status).to be_nil
        expect(minimal_holiday.open).to be_nil
        expect(minimal_holiday.close).to be_nil
      end
    end

    context "with early close data" do
      let(:early_close_data) do
        {
          date: "2024-11-29",
          exchange: "XNYS",
          name: "Day after Thanksgiving",
          status: "early-close",
          close: "13:00"
        }
      end
      let(:early_close_holiday) { described_class::Holidays.new(early_close_data) }

      it "includes close time for early close days" do
        expect(early_close_holiday.close).to eq("13:00")
        expect(early_close_holiday.early_close?).to be true
        expect(early_close_holiday.closed?).to be false
      end
    end
  end
end
