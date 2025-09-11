# frozen_string_literal: true

require "spec_helper"

RSpec.describe Polymux::Api::Options::Greeks do
  let(:valid_greeks_data) do
    {
      delta: 0.75,
      gamma: 0.02,
      theta: -0.08,
      vega: 0.15
    }
  end

  let(:greeks) { described_class.new(valid_greeks_data) }

  describe "initialization" do
    it "creates Greeks with valid attributes" do
      expect(greeks.delta).to eq(0.75)
      expect(greeks.gamma).to eq(0.02)
      expect(greeks.theta).to eq(-0.08)
      expect(greeks.vega).to eq(0.15)
    end

    it "allows all attributes to be nil" do
      nil_greeks = described_class.new({})

      expect(nil_greeks.delta).to be_nil
      expect(nil_greeks.gamma).to be_nil
      expect(nil_greeks.theta).to be_nil
      expect(nil_greeks.vega).to be_nil
    end

    it "allows partial data" do
      partial_greeks = described_class.new(delta: 0.5, theta: -0.05)

      expect(partial_greeks.delta).to eq(0.5)
      expect(partial_greeks.gamma).to be_nil
      expect(partial_greeks.theta).to eq(-0.05)
      expect(partial_greeks.vega).to be_nil
    end
  end

  describe "#high_gamma?" do
    context "when gamma is greater than 0.05" do
      let(:high_gamma_greeks) do
        described_class.new(valid_greeks_data.merge(gamma: 0.06))
      end

      it "returns true" do
        expect(high_gamma_greeks.high_gamma?).to be true
      end
    end

    context "when gamma is equal to 0.05" do
      let(:boundary_gamma_greeks) do
        described_class.new(valid_greeks_data.merge(gamma: 0.05))
      end

      it "returns false" do
        expect(boundary_gamma_greeks.high_gamma?).to be false
      end
    end

    context "when gamma is less than 0.05" do
      it "returns false" do
        expect(greeks.high_gamma?).to be false # gamma is 0.02
      end
    end

    context "when gamma is negative but absolute value is greater than 0.05" do
      let(:negative_high_gamma_greeks) do
        described_class.new(valid_greeks_data.merge(gamma: -0.06))
      end

      it "returns true (uses absolute value)" do
        expect(negative_high_gamma_greeks.high_gamma?).to be true
      end
    end

    context "when gamma is nil" do
      let(:nil_gamma_greeks) do
        described_class.new(valid_greeks_data.merge(gamma: nil))
      end

      it "returns false" do
        expect(nil_gamma_greeks.high_gamma?).to be false
      end
    end

    context "boundary value testing" do
      it "returns false for gamma exactly at negative boundary" do
        boundary_negative = described_class.new(valid_greeks_data.merge(gamma: -0.05))
        expect(boundary_negative.high_gamma?).to be false
      end

      it "returns true for gamma just above positive boundary" do
        just_above = described_class.new(valid_greeks_data.merge(gamma: 0.050001))
        expect(just_above.high_gamma?).to be true
      end

      it "returns true for gamma just above negative boundary" do
        just_below = described_class.new(valid_greeks_data.merge(gamma: -0.050001))
        expect(just_below.high_gamma?).to be true
      end
    end
  end

  describe "#high_theta_decay?" do
    context "when theta is less than -0.05" do
      let(:high_decay_greeks) do
        described_class.new(valid_greeks_data.merge(theta: -0.10))
      end

      it "returns true" do
        expect(high_decay_greeks.high_theta_decay?).to be true
      end
    end

    context "when theta is equal to -0.05" do
      let(:boundary_theta_greeks) do
        described_class.new(valid_greeks_data.merge(theta: -0.05))
      end

      it "returns false" do
        expect(boundary_theta_greeks.high_theta_decay?).to be false
      end
    end

    context "when theta is greater than -0.05" do
      let(:low_decay_greeks) do
        described_class.new(valid_greeks_data.merge(theta: -0.02))
      end

      it "returns false" do
        expect(low_decay_greeks.high_theta_decay?).to be false
      end
    end

    context "when theta is positive" do
      let(:positive_theta_greeks) do
        described_class.new(valid_greeks_data.merge(theta: 0.10))
      end

      it "returns false" do
        expect(positive_theta_greeks.high_theta_decay?).to be false
      end
    end

    context "when theta is nil" do
      let(:nil_theta_greeks) do
        described_class.new(valid_greeks_data.merge(theta: nil))
      end

      it "returns false" do
        expect(nil_theta_greeks.high_theta_decay?).to be false
      end
    end

    context "boundary value testing" do
      it "returns true for theta just below boundary" do
        just_below = described_class.new(valid_greeks_data.merge(theta: -0.050001))
        expect(just_below.high_theta_decay?).to be true
      end

      it "returns false for theta just above boundary" do
        just_above = described_class.new(valid_greeks_data.merge(theta: -0.049999))
        expect(just_above.high_theta_decay?).to be false
      end
    end
  end

  describe "#high_vega?" do
    context "when vega absolute value is greater than 0.10" do
      let(:high_vega_greeks) do
        described_class.new(valid_greeks_data.merge(vega: 0.12))
      end

      it "returns true" do
        expect(high_vega_greeks.high_vega?).to be true
      end
    end

    context "when vega absolute value is equal to 0.10" do
      let(:boundary_vega_greeks) do
        described_class.new(valid_greeks_data.merge(vega: 0.10))
      end

      it "returns false" do
        expect(boundary_vega_greeks.high_vega?).to be false
      end
    end

    context "when vega absolute value is greater than 0.10" do
      it "returns true" do
        expect(greeks.high_vega?).to be true # vega is 0.15, which should actually be true
      end
    end

    context "when vega is negative but absolute value is greater than 0.10" do
      let(:negative_high_vega_greeks) do
        described_class.new(valid_greeks_data.merge(vega: -0.12))
      end

      it "returns true (uses absolute value)" do
        expect(negative_high_vega_greeks.high_vega?).to be true
      end
    end

    context "when vega is nil" do
      let(:nil_vega_greeks) do
        described_class.new(valid_greeks_data.merge(vega: nil))
      end

      it "returns false" do
        expect(nil_vega_greeks.high_vega?).to be false
      end
    end

    context "correcting the test expectation" do
      it "returns true for default vega of 0.15" do
        expect(greeks.high_vega?).to be true # 0.15 > 0.10
      end
    end
  end

  describe "#call_like_delta?" do
    context "when delta is positive" do
      it "returns true" do
        expect(greeks.call_like_delta?).to be true # delta is 0.75
      end
    end

    context "when delta is zero" do
      let(:zero_delta_greeks) do
        described_class.new(valid_greeks_data.merge(delta: 0.0))
      end

      it "returns false" do
        expect(zero_delta_greeks.call_like_delta?).to be false
      end
    end

    context "when delta is negative" do
      let(:negative_delta_greeks) do
        described_class.new(valid_greeks_data.merge(delta: -0.30))
      end

      it "returns false" do
        expect(negative_delta_greeks.call_like_delta?).to be false
      end
    end

    context "when delta is nil" do
      let(:nil_delta_greeks) do
        described_class.new(valid_greeks_data.merge(delta: nil))
      end

      it "returns false" do
        expect(nil_delta_greeks.call_like_delta?).to be false
      end
    end

    context "boundary testing" do
      it "returns true for very small positive delta" do
        tiny_positive = described_class.new(valid_greeks_data.merge(delta: 0.001))
        expect(tiny_positive.call_like_delta?).to be true
      end

      it "returns false for very small negative delta" do
        tiny_negative = described_class.new(valid_greeks_data.merge(delta: -0.001))
        expect(tiny_negative.call_like_delta?).to be false
      end
    end
  end

  describe "#put_like_delta?" do
    context "when delta is negative" do
      let(:negative_delta_greeks) do
        described_class.new(valid_greeks_data.merge(delta: -0.30))
      end

      it "returns true" do
        expect(negative_delta_greeks.put_like_delta?).to be true
      end
    end

    context "when delta is zero" do
      let(:zero_delta_greeks) do
        described_class.new(valid_greeks_data.merge(delta: 0.0))
      end

      it "returns false" do
        expect(zero_delta_greeks.put_like_delta?).to be false
      end
    end

    context "when delta is positive" do
      it "returns false" do
        expect(greeks.put_like_delta?).to be false # delta is 0.75
      end
    end

    context "when delta is nil" do
      let(:nil_delta_greeks) do
        described_class.new(valid_greeks_data.merge(delta: nil))
      end

      it "returns false" do
        expect(nil_delta_greeks.put_like_delta?).to be false
      end
    end

    context "boundary testing" do
      it "returns true for very small negative delta" do
        tiny_negative = described_class.new(valid_greeks_data.merge(delta: -0.001))
        expect(tiny_negative.put_like_delta?).to be true
      end

      it "returns false for very small positive delta" do
        tiny_positive = described_class.new(valid_greeks_data.merge(delta: 0.001))
        expect(tiny_positive.put_like_delta?).to be false
      end
    end
  end

  describe "#abs_delta" do
    context "when delta is positive" do
      it "returns the same value" do
        expect(greeks.abs_delta).to eq(0.75)
      end
    end

    context "when delta is negative" do
      let(:negative_delta_greeks) do
        described_class.new(valid_greeks_data.merge(delta: -0.30))
      end

      it "returns the absolute value" do
        expect(negative_delta_greeks.abs_delta).to eq(0.30)
      end
    end

    context "when delta is zero" do
      let(:zero_delta_greeks) do
        described_class.new(valid_greeks_data.merge(delta: 0.0))
      end

      it "returns zero" do
        expect(zero_delta_greeks.abs_delta).to eq(0.0)
      end
    end

    context "when delta is nil" do
      let(:nil_delta_greeks) do
        described_class.new(valid_greeks_data.merge(delta: nil))
      end

      it "returns nil" do
        expect(nil_delta_greeks.abs_delta).to be_nil
      end
    end

    context "edge cases" do
      it "handles very small negative delta" do
        tiny_negative = described_class.new(valid_greeks_data.merge(delta: -0.001))
        expect(tiny_negative.abs_delta).to eq(0.001)
      end

      it "handles large negative delta" do
        large_negative = described_class.new(valid_greeks_data.merge(delta: -0.999))
        expect(large_negative.abs_delta).to eq(0.999)
      end
    end
  end

  describe "type handling" do
    context "with integer values" do
      let(:integer_greeks) do
        described_class.new(
          delta: 1,
          gamma: 0,
          theta: -1,
          vega: 2
        )
      end

      it "handles integer Greek values" do
        expect(integer_greeks.delta).to eq(1)
        expect(integer_greeks.gamma).to eq(0)
        expect(integer_greeks.theta).to eq(-1)
        expect(integer_greeks.vega).to eq(2)
      end

      it "calculates methods correctly with integer values" do
        expect(integer_greeks.call_like_delta?).to be true
        expect(integer_greeks.high_gamma?).to be false # 0 is not > 0.05
        expect(integer_greeks.high_theta_decay?).to be true # -1 < -0.05
        expect(integer_greeks.high_vega?).to be true # |2| > 0.10
        expect(integer_greeks.abs_delta).to eq(1)
      end
    end
  end

  describe "immutability and inheritance" do
    it "inherits from Dry::Struct" do
      expect(described_class.superclass).to eq(Dry::Struct)
    end

    it "is immutable after creation" do
      expect { greeks.delta = 0.5 }.to raise_error(NoMethodError)
    end
  end

  describe "comprehensive boundary testing" do
    let(:boundary_test_cases) do
      [
        # gamma boundary tests
        {gamma: 0.05, expected_high_gamma: false},
        {gamma: 0.050001, expected_high_gamma: true},
        {gamma: -0.05, expected_high_gamma: false},
        {gamma: -0.050001, expected_high_gamma: true},
        # theta boundary tests
        {theta: -0.05, expected_high_theta_decay: false},
        {theta: -0.050001, expected_high_theta_decay: true},
        {theta: -0.049999, expected_high_theta_decay: false},
        # vega boundary tests
        {vega: 0.10, expected_high_vega: false},
        {vega: 0.100001, expected_high_vega: true},
        {vega: -0.10, expected_high_vega: false},
        {vega: -0.100001, expected_high_vega: true}
      ]
    end

    it "handles all boundary conditions correctly" do
      boundary_test_cases.each do |test_case|
        greeks_instance = described_class.new(test_case.except(:expected_high_gamma, :expected_high_theta_decay, :expected_high_vega))

        if test_case.key?(:expected_high_gamma)
          expect(greeks_instance.high_gamma?).to eq(test_case[:expected_high_gamma]),
            "Expected high_gamma? to be #{test_case[:expected_high_gamma]} for gamma #{test_case[:gamma]}"
        end

        if test_case.key?(:expected_high_theta_decay)
          expect(greeks_instance.high_theta_decay?).to eq(test_case[:expected_high_theta_decay]),
            "Expected high_theta_decay? to be #{test_case[:expected_high_theta_decay]} for theta #{test_case[:theta]}"
        end

        if test_case.key?(:expected_high_vega)
          expect(greeks_instance.high_vega?).to eq(test_case[:expected_high_vega]),
            "Expected high_vega? to be #{test_case[:expected_high_vega]} for vega #{test_case[:vega]}"
        end
      end
    end
  end
end
