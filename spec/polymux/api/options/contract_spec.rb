# frozen_string_literal: true

require "spec_helper"

RSpec.describe Polymux::Api::Options::Contract do
  let(:contract_data) do
    {
      cfi: "OCASPS",
      contract_type: "call",
      exercise_style: "american",
      expiration_date: "2024-03-15",
      primary_exchange: "CBOE",
      shares_per_contract: 100,
      strike_price: 150.0,
      ticker: "O:AAPL240315C00150000",
      underlying_ticker: "AAPL"
    }
  end

  let(:contract) { described_class.new(contract_data) }

  describe "initialization" do
    it "accepts contract data hash" do
      expect { described_class.new(contract_data) }.not_to raise_error
    end

    it "transforms keys to symbols" do
      expect(contract.cfi).to eq("OCASPS")
      expect(contract.contract_type).to eq("call")
      expect(contract.exercise_style).to eq("american")
      expect(contract.expiration_date).to eq("2024-03-15")
      expect(contract.primary_exchange).to eq("CBOE")
      expect(contract.shares_per_contract).to eq(100)
      expect(contract.strike_price).to eq(150.0)
      expect(contract.ticker).to eq("O:AAPL240315C00150000")
      expect(contract.underlying_ticker).to eq("AAPL")
    end
  end

  describe "required attributes" do
    it "requires all contract attributes to be present" do
      expect(contract.cfi).to be_a(String)
      expect(contract.contract_type).to be_a(String)
      expect(contract.exercise_style).to be_a(String)
      expect(contract.expiration_date).to be_a(String)
      expect(contract.primary_exchange).to be_a(String)
      expect(contract.shares_per_contract).to be_an(Integer)
      expect(contract.strike_price).to be_a(Numeric)
      expect(contract.ticker).to be_a(String)
      expect(contract.underlying_ticker).to be_a(String)
    end
  end

  describe "#call?" do
    context "when contract_type is call" do
      let(:call_contract) { described_class.new(contract_data.merge(contract_type: "call")) }

      it "returns true" do
        expect(call_contract.call?).to be true
      end
    end

    context "when contract_type is put" do
      let(:put_contract) { described_class.new(contract_data.merge(contract_type: "put")) }

      it "returns false" do
        expect(put_contract.call?).to be false
      end
    end
  end

  describe "#put?" do
    context "when contract_type is put" do
      let(:put_contract) { described_class.new(contract_data.merge(contract_type: "put")) }

      it "returns true" do
        expect(put_contract.put?).to be true
      end
    end

    context "when contract_type is call" do
      let(:call_contract) { described_class.new(contract_data.merge(contract_type: "call")) }

      it "returns false" do
        expect(call_contract.put?).to be false
      end
    end
  end

  describe "#american?" do
    context "when exercise_style is american" do
      let(:american_contract) { described_class.new(contract_data.merge(exercise_style: "american")) }

      it "returns true" do
        expect(american_contract.american?).to be true
      end
    end

    context "when exercise_style is european" do
      let(:european_contract) { described_class.new(contract_data.merge(exercise_style: "european")) }

      it "returns false" do
        expect(european_contract.american?).to be false
      end
    end
  end

  describe "#european?" do
    context "when exercise_style is european" do
      let(:european_contract) { described_class.new(contract_data.merge(exercise_style: "european")) }

      it "returns true" do
        expect(european_contract.european?).to be true
      end
    end

    context "when exercise_style is american" do
      let(:american_contract) { described_class.new(contract_data.merge(exercise_style: "american")) }

      it "returns false" do
        expect(american_contract.european?).to be false
      end
    end
  end

  describe "#notional_value" do
    it "calculates strike price multiplied by shares per contract" do
      expect(contract.notional_value).to eq(15000.0) # 150.0 * 100
    end

    context "with different strike price" do
      let(:high_strike_contract) do
        described_class.new(contract_data.merge(strike_price: 200.5, shares_per_contract: 100))
      end

      it "calculates correctly for different values" do
        expect(high_strike_contract.notional_value).to eq(20050.0) # 200.5 * 100
      end
    end

    context "with non-standard multiplier" do
      let(:mini_contract) do
        described_class.new(contract_data.merge(strike_price: 150.0, shares_per_contract: 10))
      end

      it "uses the actual shares_per_contract value" do
        expect(mini_contract.notional_value).to eq(1500.0) # 150.0 * 10
      end
    end

    context "with integer strike price" do
      let(:integer_strike_contract) do
        described_class.new(contract_data.merge(strike_price: 150))
      end

      it "handles integer strike prices correctly" do
        expect(integer_strike_contract.notional_value).to eq(15000) # 150 * 100
      end
    end
  end

  describe ".from_api" do
    let(:raw_api_data) do
      {
        "cfi" => "OCASPS",
        "contract_type" => "call",
        "exercise_style" => "american",
        "expiration_date" => "2024-03-15",
        "primary_exchange" => "CBOE",
        "shares_per_contract" => 100,
        "strike_price" => 150.0,
        "ticker" => "O:AAPL240315C00150000",
        "underlying_ticker" => "AAPL"
      }
    end

    it "creates Contract object from raw API data" do
      contract = described_class.from_api(raw_api_data)

      expect(contract).to be_a(described_class)
      expect(contract.ticker).to eq("O:AAPL240315C00150000")
      expect(contract.underlying_ticker).to eq("AAPL")
      expect(contract.contract_type).to eq("call")
      expect(contract.strike_price).to eq(150.0)
    end

    it "uses the contract transformer" do
      expect(Polymux::Api::Transformers).to receive(:contract).with(raw_api_data).and_call_original

      described_class.from_api(raw_api_data)
    end
  end

  describe "contract type combinations" do
    let(:test_cases) do
      [
        {
          contract_type: "call",
          exercise_style: "american",
          expected: {call?: true, put?: false, american?: true, european?: false}
        },
        {
          contract_type: "call",
          exercise_style: "european",
          expected: {call?: true, put?: false, american?: false, european?: true}
        },
        {
          contract_type: "put",
          exercise_style: "american",
          expected: {call?: false, put?: true, american?: true, european?: false}
        },
        {
          contract_type: "put",
          exercise_style: "european",
          expected: {call?: false, put?: true, american?: false, european?: true}
        }
      ]
    end

    it "correctly identifies all contract type and exercise style combinations" do
      test_cases.each do |test_case|
        contract = described_class.new(
          contract_data.merge(
            contract_type: test_case[:contract_type],
            exercise_style: test_case[:exercise_style]
          )
        )

        test_case[:expected].each do |method, expected_result|
          expect(contract.send(method)).to eq(expected_result),
            "Expected #{method} to return #{expected_result} for #{test_case[:contract_type]} #{test_case[:exercise_style]} contract"
        end
      end
    end
  end

  describe "data structure inheritance" do
    it "inherits from Dry::Struct" do
      expect(described_class.superclass).to eq(Dry::Struct)
    end

    it "is immutable" do
      expect { contract.ticker = "new_ticker" }.to raise_error(NoMethodError)
    end
  end
end
