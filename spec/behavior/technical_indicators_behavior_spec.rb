# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Technical Analysis for Trading Strategies", type: :behavior do
  describe "Quantitative Analysis for Trading Strategies" do
    context "when generating systematic trading signals" do
      it "identifies trend direction using moving averages for position sizing" do
        # Expected Outcome: User receives trend signals to determine position direction and size
        # Success Criteria:
        #   - SMA and EMA calculations provide clear trend identification
        #   - Multiple timeframes (20, 50, 200 periods) enable multi-dimensional analysis
        #   - Crossover signals indicate trend changes with precise timing
        #   - Values are mathematically accurate for algorithmic decision-making
        # User Value: User can systematically determine when to enter long/short positions
        #             and size them appropriately based on trend strength and direction

        # Setup: Create API client for quantitative trading workflow
        config = Polymux::Config.new(api_key: "test_key_123", base_url: "https://api.polygon.io")
        client = Polymux::Client.new(config)
        indicators_api = client.technical_indicators

        # Mock comprehensive moving average data for systematic trading
        stub_request(:get, "https://api.polygon.io/v1/indicators/sma/AAPL")
          .with(
            query: hash_including({
              "timestamp.gte" => "2024-01-01",
              "timestamp.lte" => "2024-03-31",
              "timespan" => "day",
              "window" => "20",
              "series_type" => "close",
              "adjusted" => "true",
              "limit" => "5000"
            }),
            headers: {"Authorization" => "Bearer test_key_123"}
          )
          .to_return(
            status: 200,
            body: {
              results: {
                underlying: {ticker: "AAPL"},
                values: [
                  {timestamp: 1704067200000, value: 180.50}, # 2024-01-01
                  {timestamp: 1704153600000, value: 181.75}, # 2024-01-02
                  {timestamp: 1704240000000, value: 183.20}, # 2024-01-03
                  {timestamp: 1704326400000, value: 184.15}, # 2024-01-04
                  {timestamp: 1704412800000, value: 185.30}  # 2024-01-05
                ]
              },
              status: "OK"
            }.to_json,
            headers: {"Content-Type" => "application/json"}
          )

        stub_request(:get, "https://api.polygon.io/v1/indicators/ema/AAPL")
          .with(
            query: hash_including({
              "timestamp.gte" => "2024-01-01",
              "timestamp.lte" => "2024-03-31",
              "timespan" => "day",
              "window" => "20",
              "series_type" => "close",
              "adjusted" => "true",
              "limit" => "5000"
            }),
            headers: {"Authorization" => "Bearer test_key_123"}
          )
          .to_return(
            status: 200,
            body: {
              results: {
                underlying: {ticker: "AAPL"},
                values: [
                  {timestamp: 1704067200000, value: 179.85}, # More responsive to recent price changes
                  {timestamp: 1704153600000, value: 181.20},
                  {timestamp: 1704240000000, value: 183.45},
                  {timestamp: 1704326400000, value: 184.55},
                  {timestamp: 1704412800000, value: 185.75}
                ]
              },
              status: "OK"
            }.to_json,
            headers: {"Content-Type" => "application/json"}
          )

        # Act: User calculates moving averages for trend identification
        sma_data = indicators_api.sma("AAPL",
          window: 20,
          timespan: "day",
          timestamp_gte: "2024-01-01",
          timestamp_lte: "2024-03-31")

        ema_data = indicators_api.ema("AAPL",
          window: 20,
          timespan: "day",
          timestamp_gte: "2024-01-01",
          timestamp_lte: "2024-03-31")

        # Assert: User obtains precise trend analysis capabilities

        # Verify data structure and accuracy for algorithmic use
        expect(sma_data).to be_a(Polymux::Api::TechnicalIndicators::SMA)
        expect(sma_data.ticker).to eq("AAPL")
        expect(sma_data.values.length).to eq(5)

        expect(ema_data).to be_a(Polymux::Api::TechnicalIndicators::EMA)
        expect(ema_data.ticker).to eq("AAPL")
        expect(ema_data.values.length).to eq(5)

        # Verify mathematical precision for quantitative analysis
        sma_values = sma_data.values.map(&:value)
        ema_values = ema_data.values.map(&:value)

        expect(sma_values.first).to eq(180.50)
        expect(ema_values.first).to eq(179.85)

        # Verify EMA responsiveness (should be more reactive to price changes)
        latest_sma = sma_values.last
        latest_ema = ema_values.last
        expect(latest_ema).to be > latest_sma # EMA typically more responsive

        # Verify timestamps for precise signal timing
        first_timestamp = sma_data.values.first.timestamp
        expect(first_timestamp).to be_a(Time)
        expect(first_timestamp.year).to eq(2024)
        expect(first_timestamp.month).to eq(1)

        # Business Value Verification: User can generate systematic trading signals

        # Simulate trend identification workflow
        trend_signals = []
        sma_data.values.each_with_index do |sma_point, index|
          ema_point = ema_data.values[index]

          signal = if ema_point.value > sma_point.value
            {
              timestamp: sma_point.timestamp,
              signal: "bullish",
              ema: ema_point.value,
              sma: sma_point.value,
              strength: ((ema_point.value - sma_point.value) / sma_point.value * 100).round(2)
            }
          else
            {
              timestamp: sma_point.timestamp,
              signal: "bearish",
              ema: ema_point.value,
              sma: sma_point.value,
              strength: ((sma_point.value - ema_point.value) / sma_point.value * 100).round(2)
            }
          end
          trend_signals << signal
        end

        # Verify user can systematically identify trend direction
        expect(trend_signals.length).to eq(5)
        expect(trend_signals.all? { |s| %w[bullish bearish].include?(s[:signal]) }).to be true
        expect(trend_signals.all? { |s| s[:strength].is_a?(Float) && s[:strength] >= 0 }).to be true

        # Verify signal consistency for automated trading
        bullish_signals = trend_signals.select { |s| s[:signal] == "bullish" }
        expect(bullish_signals).to_not be_empty
        expect(bullish_signals.all? { |s| s[:ema] > s[:sma] }).to be true
      end

      it "detects momentum shifts with RSI for entry/exit timing" do
        # Expected Outcome: User identifies overbought/oversold conditions for precise trade timing
        # Success Criteria:
        #   - RSI values range from 0-100 with standard interpretation levels
        #   - Overbought (>70) and oversold (<30) levels clearly identified
        #   - Momentum divergences detected for advanced signal generation
        #   - Calculations follow standard RSI methodology for industry compatibility
        # User Value: User can time market entries and exits with quantified momentum analysis,
        #             reducing emotional decision-making and improving trade timing precision

        # Setup: Prepare for momentum analysis workflow
        config = Polymux::Config.new(api_key: "test_key_123", base_url: "https://api.polygon.io")
        client = Polymux::Client.new(config)
        indicators_api = client.technical_indicators

        # Mock RSI data showing momentum cycle for trading decisions
        stub_request(:get, "https://api.polygon.io/v1/indicators/rsi/AAPL")
          .with(
            query: hash_including({
              "timestamp.gte" => "2024-01-01",
              "timestamp.lte" => "2024-03-31",
              "timespan" => "day",
              "window" => "14",
              "series_type" => "close",
              "adjusted" => "true",
              "limit" => "5000"
            }),
            headers: {"Authorization" => "Bearer test_key_123"}
          )
          .to_return(
            status: 200,
            body: {
              results: {
                underlying: {ticker: "AAPL"},
                values: [
                  {timestamp: 1704067200000, value: 45.0}, # Weak
                  {timestamp: 1704153600000, value: 52.8}, # Building momentum
                  {timestamp: 1704240000000, value: 68.5}, # Approaching overbought
                  {timestamp: 1704326400000, value: 74.3}, # Overbought
                  {timestamp: 1704412800000, value: 71.9}, # Starting to cool
                  {timestamp: 1704499200000, value: 65.1}, # Returning to neutral
                  {timestamp: 1704585600000, value: 33.7}, # Approaching oversold
                  {timestamp: 1704672000000, value: 18.4}, # Extremely oversold
                  {timestamp: 1704758400000, value: 31.2}, # Recovery from oversold
                  {timestamp: 1704844800000, value: 48.6}  # Back to neutral
                ]
              },
              status: "OK"
            }.to_json,
            headers: {"Content-Type" => "application/json"}
          )

        # Act: User calculates RSI for momentum-based trading signals
        rsi_data = indicators_api.rsi("AAPL",
          window: 14,
          timespan: "day",
          timestamp_gte: "2024-01-01",
          timestamp_lte: "2024-03-31")

        # Assert: User receives precise momentum analysis for trading decisions

        # Verify RSI data structure and mathematical bounds
        expect(rsi_data).to be_a(Polymux::Api::TechnicalIndicators::RSI)
        expect(rsi_data.ticker).to eq("AAPL")
        expect(rsi_data.values.length).to eq(10)

        # Verify RSI values are within valid range (0-100)
        rsi_values = rsi_data.values.map(&:value)
        expect(rsi_values.all? { |v| v.between?(0, 100) }).to be true

        # Verify overbought/oversold level identification
        overbought_threshold = 70
        oversold_threshold = 30

        overbought_readings = rsi_values.select { |v| v > overbought_threshold }
        oversold_readings = rsi_values.select { |v| v < oversold_threshold }

        expect(overbought_readings).to include(74.3, 71.9)
        expect(oversold_readings).to include(18.4)

        # Verify timestamp accuracy for precise signal timing
        first_point = rsi_data.values.first
        expect(first_point.timestamp).to be_a(Time)
        expect(first_point.value).to eq(45.0)

        # Business Value Verification: User can systematically time market entries/exits

        # Simulate momentum-based trading signal generation
        momentum_signals = []
        rsi_data.values.each_with_index do |point, index|
          signal_type = if point.value > overbought_threshold
            "sell_signal" # Overbought - consider selling
          elsif point.value < oversold_threshold
            "buy_signal"  # Oversold - consider buying
          else
            "neutral"     # Hold position
          end

          # Detect momentum shifts (turning points)
          momentum_shift = if index > 0
            previous_value = rsi_data.values[index - 1].value
            if point.value > overbought_threshold && previous_value <= overbought_threshold
              "entering_overbought"
            elsif point.value < oversold_threshold && previous_value >= oversold_threshold
              "entering_oversold"
            elsif point.value <= overbought_threshold && previous_value > overbought_threshold
              "exiting_overbought"
            elsif point.value >= oversold_threshold && previous_value < oversold_threshold
              "exiting_oversold"
            end
          end

          momentum_signals << {
            timestamp: point.timestamp,
            rsi_value: point.value,
            signal: signal_type,
            momentum_shift: momentum_shift,
            strength: case point.value
                      when 0..20 then "extremely_oversold"
                      when 21..30 then "oversold"
                      when 31..45 then "weak"
                      when 46..55 then "neutral"
                      when 56..70 then "strong"
                      when 71..80 then "overbought"
                      when 81..100 then "extremely_overbought"
                      end
          }
        end

        # Verify systematic signal generation works for automated trading
        expect(momentum_signals.length).to eq(10)

        # Verify buy signals occur during oversold conditions
        buy_signals = momentum_signals.select { |s| s[:signal] == "buy_signal" }
        expect(buy_signals).to_not be_empty
        expect(buy_signals.all? { |s| s[:rsi_value] < oversold_threshold }).to be true

        # Verify sell signals occur during overbought conditions
        sell_signals = momentum_signals.select { |s| s[:signal] == "sell_signal" }
        expect(sell_signals).to_not be_empty
        expect(sell_signals.all? { |s| s[:rsi_value] > overbought_threshold }).to be true

        # Verify momentum shift detection for advanced timing
        shifts = momentum_signals.select { |s| s[:momentum_shift] }
        expect(shifts.length).to be >= 2 # Should detect multiple shifts

        # Verify user gets clear strength categorization
        expect(momentum_signals.all? { |s| s[:strength].is_a?(String) }).to be true
        extremely_oversold = momentum_signals.select { |s| s[:strength] == "extremely_oversold" }
        expect(extremely_oversold).to_not be_empty
      end

      it "generates MACD crossover signals for trend confirmation" do
        # Expected Outcome: User receives sophisticated trend-following signals with precise timing
        # Success Criteria:
        #   - MACD line, signal line, and histogram provide comprehensive trend analysis
        #   - Bullish/bearish crossovers indicate trend changes with exact timing
        #   - Histogram divergence shows momentum strength and weakness
        #   - Multiple timeframe analysis enables strategy confirmation
        # User Value: User can confirm trend changes with industry-standard momentum oscillator,
        #             reducing false signals and improving entry/exit timing precision

        # Setup: Create client for advanced momentum analysis
        config = Polymux::Config.new(api_key: "test_key_123", base_url: "https://api.polygon.io")
        client = Polymux::Client.new(config)
        indicators_api = client.technical_indicators

        # Mock MACD data showing complete trend cycle for strategy development
        stub_request(:get, "https://api.polygon.io/v1/indicators/macd/AAPL")
          .with(
            query: hash_including({
              "timestamp.gte" => "2024-01-01",
              "timestamp.lte" => "2024-03-31",
              "timespan" => "day",
              "short_window" => "12",
              "long_window" => "26",
              "signal_window" => "9",
              "series_type" => "close",
              "adjusted" => "true",
              "limit" => "5000"
            }),
            headers: {"Authorization" => "Bearer test_key_123"}
          )
          .to_return(
            status: 200,
            body: {
              results: {
                underlying: {ticker: "AAPL"},
                values: [
                  {timestamp: 1704067200000, value: -1.25, signal: -0.85, histogram: -0.40}, # Bearish
                  {timestamp: 1704153600000, value: -0.75, signal: -0.95, histogram: 0.20},  # Bullish cross
                  {timestamp: 1704240000000, value: 0.45, signal: -0.35, histogram: 0.80},   # Strong bullish
                  {timestamp: 1704326400000, value: 1.15, signal: 0.25, histogram: 0.90},    # Momentum peak
                  {timestamp: 1704412800000, value: 1.35, signal: 0.65, histogram: 0.70},    # Momentum declining
                  {timestamp: 1704499200000, value: 1.25, signal: 0.95, histogram: 0.30},    # Weakening
                  {timestamp: 1704585600000, value: 0.85, signal: 1.15, histogram: -0.30},   # Bearish cross
                  {timestamp: 1704672000000, value: 0.25, signal: 1.05, histogram: -0.80},   # Strong bearish
                  {timestamp: 1704758400000, value: -0.35, signal: 0.65, histogram: -1.00},  # Deep bearish
                  {timestamp: 1704844800000, value: -0.15, signal: 0.25, histogram: -0.40}   # Recovering
                ]
              },
              status: "OK"
            }.to_json,
            headers: {"Content-Type" => "application/json"}
          )

        # Act: User calculates MACD for trend confirmation and signal generation
        macd_data = indicators_api.macd("AAPL",
          short_window: 12,
          long_window: 26,
          signal_window: 9,
          timespan: "day",
          timestamp_gte: "2024-01-01",
          timestamp_lte: "2024-03-31")

        # Assert: User receives comprehensive trend analysis with precise signals

        # Verify MACD data structure contains all components
        expect(macd_data).to be_a(Polymux::Api::TechnicalIndicators::MACD)
        expect(macd_data.ticker).to eq("AAPL")
        expect(macd_data.values.length).to eq(10)

        # Verify each MACD point has all three components
        first_point = macd_data.values.first
        expect(first_point).to respond_to(:value) # MACD line
        expect(first_point).to respond_to(:signal) # Signal line
        expect(first_point).to respond_to(:histogram) # Histogram
        expect(first_point).to respond_to(:timestamp)

        # Verify mathematical relationships hold
        macd_data.values.each do |point|
          calculated_histogram = point.value - point.signal
          expect((calculated_histogram - point.histogram).abs).to be < 0.01 # Allow for rounding
        end

        # Business Value Verification: User can generate sophisticated trend signals

        # Simulate comprehensive MACD signal analysis
        trend_analysis = []
        macd_data.values.each_with_index do |point, index|
          analysis = {
            timestamp: point.timestamp,
            macd_line: point.value,
            signal_line: point.signal,
            histogram: point.histogram
          }

          # Detect crossover signals
          if index > 0
            prev_point = macd_data.values[index - 1]

            # Bullish crossover: MACD line crosses above signal line
            if point.value > point.signal && prev_point.value <= prev_point.signal
              analysis[:crossover_signal] = "bullish_crossover"
              analysis[:signal_strength] = "buy"
            # Bearish crossover: MACD line crosses below signal line
            elsif point.value < point.signal && prev_point.value >= prev_point.signal
              analysis[:crossover_signal] = "bearish_crossover"
              analysis[:signal_strength] = "sell"
            else
              analysis[:crossover_signal] = "none"
              analysis[:signal_strength] = (point.value > point.signal) ? "bullish" : "bearish"
            end

            # Histogram momentum analysis
            histogram_change = point.histogram - prev_point.histogram
            analysis[:momentum_direction] = (histogram_change > 0) ? "increasing" : "decreasing"
            analysis[:momentum_strength] = case point.histogram.abs
            when 0..0.3 then "weak"
            when 0.3..0.7 then "moderate"
            else "strong"
            end
          else
            analysis[:crossover_signal] = "none"
            # First point has no comparison, so no signal strength
            analysis[:momentum_direction] = "neutral"
            analysis[:momentum_strength] = "weak"
          end

          trend_analysis << analysis
        end

        # Verify crossover signal detection works precisely
        crossover_signals = trend_analysis.select { |a| a[:crossover_signal] != "none" }
        expect(crossover_signals.length).to be >= 2 # Should detect multiple crossovers

        bullish_crossovers = trend_analysis.select { |a| a[:crossover_signal] == "bullish_crossover" }
        bearish_crossovers = trend_analysis.select { |a| a[:crossover_signal] == "bearish_crossover" }

        expect(bullish_crossovers).to_not be_empty
        expect(bearish_crossovers).to_not be_empty

        # Verify momentum analysis provides actionable insights
        strong_momentum = trend_analysis.select { |a| a[:momentum_strength] == "strong" }
        expect(strong_momentum).to_not be_empty

        # Verify user can track momentum direction changes
        increasing_momentum = trend_analysis.select { |a| a[:momentum_direction] == "increasing" }
        decreasing_momentum = trend_analysis.select { |a| a[:momentum_direction] == "decreasing" }

        expect(increasing_momentum).to_not be_empty
        expect(decreasing_momentum).to_not be_empty

        # Verify signal strength categorization for systematic trading
        buy_signals = trend_analysis.select { |a| a[:signal_strength] == "buy" }
        sell_signals = trend_analysis.select { |a| a[:signal_strength] == "sell" }
        bullish_signals = trend_analysis.select { |a| a[:signal_strength] == "bullish" }
        bearish_signals = trend_analysis.select { |a| a[:signal_strength] == "bearish" }

        total_signals = buy_signals.length + sell_signals.length + bullish_signals.length + bearish_signals.length
        expect(total_signals).to eq(trend_analysis.length - 1) # First point has no comparison
      end
    end

    context "when backtesting trading strategies" do
      it "validates strategy performance across multiple indicators" do
        # Expected Outcome: User confirms strategy effectiveness using multiple technical indicators
        # Success Criteria:
        #   - Multiple indicators provide convergent signals for higher probability trades
        #   - Strategy performance metrics quantify effectiveness objectively
        #   - Risk-adjusted returns demonstrate strategy viability
        #   - Transaction costs and slippage are factored into realistic performance
        # User Value: User can validate trading strategies before risking capital,
        #             ensuring systematic approach has positive expected value

        skip "Integration test requiring multiple indicator APIs - implementation needed for technical indicators module"
      end

      it "optimizes indicator parameters for maximum strategy performance" do
        # Expected Outcome: User discovers optimal parameter settings for their trading timeframe
        # Success Criteria:
        #   - Parameter optimization across multiple timeframes and settings
        #   - Performance metrics highlight best-performing combinations
        #   - Overfitting protection through walk-forward analysis
        #   - Statistical significance testing validates optimization results
        # User Value: User can systematically optimize strategy parameters instead of guessing,
        #             maximizing returns while maintaining statistical validity

        skip "Parameter optimization requires extensive historical data - implementation needed for technical indicators module"
      end

      it "measures strategy drawdowns and risk metrics" do
        # Expected Outcome: User understands complete risk profile of their trading strategy
        # Success Criteria:
        #   - Maximum drawdown, win rate, and risk-adjusted metrics calculated
        #   - Sharpe ratio and other statistical measures provide objective comparison
        #   - Worst-case scenarios identified through stress testing
        #   - Risk per trade optimized based on historical performance
        # User Value: User can size positions appropriately and understand worst-case scenarios,
        #             preventing catastrophic losses and ensuring long-term viability

        skip "Risk measurement requires extensive historical testing - implementation needed for technical indicators module"
      end
    end
  end

  describe "Market Timing for Investment Strategies" do
    context "when timing portfolio allocation decisions" do
      it "identifies market regime changes using multiple timeframe analysis" do
        # Expected Outcome: User recognizes major market shifts to adjust portfolio allocation
        # Success Criteria:
        #   - Multiple timeframe indicators confirm regime changes (daily, weekly, monthly)
        #   - Bull/bear market transitions identified with statistical confidence
        #   - Sector rotation opportunities highlighted through comparative analysis
        #   - Economic cycle positioning based on technical momentum
        # User Value: User can adjust portfolio allocation proactively based on technical evidence,
        #             improving returns and reducing drawdowns during market transitions

        # Setup: Create client for multi-timeframe regime analysis
        config = Polymux::Config.new(api_key: "test_key_123", base_url: "https://api.polygon.io")
        client = Polymux::Client.new(config)
        indicators_api = client.technical_indicators

        # Mock daily SMA data showing trend
        stub_request(:get, "https://api.polygon.io/v1/indicators/sma/SPY")
          .with(
            query: hash_including({
              "timestamp.gte" => "2024-01-01",
              "timestamp.lte" => "2024-03-31",
              "timespan" => "day",
              "window" => "200",
              "series_type" => "close",
              "adjusted" => "true",
              "limit" => "5000"
            }),
            headers: {"Authorization" => "Bearer test_key_123"}
          )
          .to_return(
            status: 200,
            body: {
              results: {
                underlying: {ticker: "SPY"},
                values: [
                  {timestamp: 1704067200000, value: 445.20}, # Below current price - bullish
                  {timestamp: 1704153600000, value: 446.15},
                  {timestamp: 1704240000000, value: 447.30},
                  {timestamp: 1704326400000, value: 448.75},
                  {timestamp: 1704412800000, value: 450.10}
                ]
              },
              status: "OK"
            }.to_json,
            headers: {"Content-Type" => "application/json"}
          )

        # Mock weekly SMA data for higher timeframe confirmation
        stub_request(:get, "https://api.polygon.io/v1/indicators/sma/SPY")
          .with(
            query: hash_including({
              "timestamp.gte" => "2024-01-01",
              "timestamp.lte" => "2024-03-31",
              "timespan" => "week",
              "window" => "50",
              "series_type" => "close",
              "adjusted" => "true",
              "limit" => "5000"
            }),
            headers: {"Authorization" => "Bearer test_key_123"}
          )
          .to_return(
            status: 200,
            body: {
              results: {
                underlying: {ticker: "SPY"},
                values: [
                  {timestamp: 1704067200000, value: 442.50}, # Lower than daily - confirming uptrend
                  {timestamp: 1704672000000, value: 444.25},
                  {timestamp: 1705276800000, value: 446.75},
                  {timestamp: 1705881600000, value: 449.20}
                ]
              },
              status: "OK"
            }.to_json,
            headers: {"Content-Type" => "application/json"}
          )

        # Act: User analyzes multiple timeframes for regime identification
        daily_trend = indicators_api.sma("SPY",
          window: 200,
          timespan: "day",
          timestamp_gte: "2024-01-01",
          timestamp_lte: "2024-03-31")

        weekly_trend = indicators_api.sma("SPY",
          window: 50,
          timespan: "week",
          timestamp_gte: "2024-01-01",
          timestamp_lte: "2024-03-31")

        # Assert: User can identify market regime with multi-timeframe confirmation

        expect(daily_trend.ticker).to eq("SPY")
        expect(weekly_trend.ticker).to eq("SPY")

        # Verify trend direction consistency across timeframes
        daily_values = daily_trend.values.map(&:value)
        weekly_values = weekly_trend.values.map(&:value)

        # Daily trend should be rising (bull market regime)
        daily_trend_slope = daily_values.last - daily_values.first
        weekly_trend_slope = weekly_values.last - weekly_values.first

        expect(daily_trend_slope).to be > 0 # Rising trend
        expect(weekly_trend_slope).to be > 0 # Confirmed by weekly

        # Business Value Verification: User can make allocation decisions

        # Simulate regime analysis workflow
        regime_analysis = {
          daily_trend: (daily_trend_slope > 0) ? "bullish" : "bearish",
          weekly_trend: (weekly_trend_slope > 0) ? "bullish" : "bearish",
          regime_confidence: nil,
          allocation_recommendation: nil
        }

        # Multi-timeframe confirmation increases confidence
        if regime_analysis[:daily_trend] == regime_analysis[:weekly_trend]
          regime_analysis[:regime_confidence] = "high"
          regime_analysis[:allocation_recommendation] = (regime_analysis[:daily_trend] == "bullish") ? "increase_equity_allocation" : "reduce_equity_allocation"
        else
          regime_analysis[:regime_confidence] = "mixed"
          regime_analysis[:allocation_recommendation] = "maintain_current_allocation"
        end

        # Verify user gets clear allocation guidance
        expect(regime_analysis[:regime_confidence]).to eq("high")
        expect(regime_analysis[:allocation_recommendation]).to eq("increase_equity_allocation")
      end

      it "detects sector rotation opportunities through relative strength" do
        # Expected Outcome: User identifies sectors showing relative outperformance for rotation
        # Success Criteria:
        #   - Relative strength analysis across major sectors (Tech, Healthcare, Finance, etc.)
        #   - Momentum indicators highlight sectors gaining/losing leadership
        #   - Rotation timing based on technical breakouts and breakdowns
        #   - Risk management through diversified sector exposure
        # User Value: User can rotate portfolio into outperforming sectors ahead of the crowd,
        #             capturing alpha through systematic sector selection

        skip "Sector rotation analysis requires multiple sector ETF data - implementation needed"
      end

      it "times defensive positioning during market stress periods" do
        # Expected Outcome: User reduces risk exposure before significant market declines
        # Success Criteria:
        #   - Volatility indicators signal rising market stress in advance
        #   - Multiple indicators confirm defensive positioning requirements
        #   - Safe haven assets show relative strength during stress periods
        #   - Risk parity approaches optimize defensive allocation
        # User Value: User can protect capital during market stress while maintaining upside exposure,
        #             reducing portfolio volatility and preserving long-term wealth

        skip "Defensive positioning requires volatility and safe haven analysis - implementation needed"
      end
    end

    context "when optimizing entry and exit timing" do
      it "coordinates multiple indicator signals for high-probability entries" do
        # Expected Outcome: User enters positions when multiple indicators align for higher success rates
        # Success Criteria:
        #   - RSI oversold, MACD bullish crossover, and price above moving average alignment
        #   - Confirmation across multiple timeframes reduces false signals
        #   - Volume analysis confirms price movement validity
        #   - Risk/reward ratios optimized based on technical levels
        # User Value: User dramatically improves entry timing by waiting for convergent signals,
        #             increasing win rates and reducing average losses per trade

        skip "Multi-indicator coordination requires complete indicator suite - implementation needed"
      end

      it "manages position sizing based on technical signal strength" do
        # Expected Outcome: User adjusts position sizes based on signal quality and market conditions
        # Success Criteria:
        #   - Strong signals warrant larger positions, weak signals smaller positions
        #   - Volatility adjustment prevents oversizing in unstable markets
        #   - Portfolio correlation limits prevent over-concentration in similar trades
        #   - Kelly criterion optimization maximizes long-term growth
        # User Value: User optimizes capital allocation per trade based on systematic signal analysis,
        #             maximizing returns while controlling risk per individual position

        skip "Position sizing optimization requires portfolio-level analysis - implementation needed"
      end

      it "implements systematic profit-taking and loss-cutting rules" do
        # Expected Outcome: User removes emotions from exit decisions through systematic rules
        # Success Criteria:
        #   - Technical levels (support/resistance) define exit points objectively
        #   - Trailing stops based on volatility preserve profits while allowing upside
        #   - Time-based exits prevent stagnant positions from tying up capital
        #   - Risk/reward analysis ensures positive expected value over time
        # User Value: User eliminates emotional exit decisions and locks in systematic profits,
        #             improving overall strategy performance through disciplined execution

        skip "Exit rule implementation requires real-time monitoring capabilities - implementation needed"
      end
    end
  end

  describe "Risk Management Through Technical Analysis" do
    context "when assessing portfolio risk exposure" do
      it "measures correlation risk across portfolio holdings" do
        # Expected Outcome: User understands how portfolio holdings move together during market stress
        # Success Criteria:
        #   - Correlation matrices show relationship strength between holdings
        #   - Rolling correlations identify periods of increased systematic risk
        #   - Diversification effectiveness measured through correlation analysis
        #   - Stress testing shows portfolio behavior during extreme market events
        # User Value: User can identify hidden concentration risks and improve diversification,
        #             reducing portfolio volatility and drawdowns during market stress

        skip "Correlation analysis requires multiple security data - implementation needed"
      end

      it "calculates position-level volatility for appropriate sizing" do
        # Expected Outcome: User sizes positions based on individual security volatility characteristics
        # Success Criteria:
        #   - Historical volatility calculation using standard methodologies
        #   - Implied volatility comparison for options-eligible securities
        #   - Volatility-adjusted position sizing prevents oversizing risky positions
        #   - Portfolio-level volatility targeting maintains consistent risk exposure
        # User Value: User can maintain consistent risk per position regardless of individual security volatility,
        #             creating more stable portfolio returns and predictable risk exposure

        skip "Volatility calculation requires historical price data integration - implementation needed"
      end

      it "monitors momentum divergences as early warning indicators" do
        # Expected Outcome: User identifies potential trend reversals before they fully materialize
        # Success Criteria:
        #   - Price/momentum divergences signal weakening trends in advance
        #   - Multiple timeframe divergence analysis improves signal reliability
        #   - Volume divergences confirm or refute price movement sustainability
        #   - Early warning system prevents riding trends too long into reversals
        # User Value: User can exit deteriorating positions before major losses occur,
        #             preserving capital and improving overall portfolio performance

        # Setup: Create client for divergence analysis
        config = Polymux::Config.new(api_key: "test_key_123", base_url: "https://api.polygon.io")
        client = Polymux::Client.new(config)
        indicators_api = client.technical_indicators

        # Mock price data creating bearish divergence (higher highs)
        stock_prices = [
          {timestamp: 1704067200000, price: 150.00},
          {timestamp: 1704153600000, price: 158.00}, # 1st price peak
          {timestamp: 1704240000000, price: 155.00},
          {timestamp: 1704326400000, price: 162.00}, # 2nd price peak (higher)
          {timestamp: 1704412800000, price: 160.00},
          {timestamp: 1704499200000, price: 168.00}, # 3rd price peak (highest - divergence!)
          {timestamp: 1704585600000, price: 165.00},
          {timestamp: 1704672000000, price: 150.00}, # Drop
          {timestamp: 1704758400000, price: 145.00}, # Lower
          {timestamp: 1704844800000, price: 148.00}  # No peak
        ]

        # Mock RSI data showing lower highs (bearish divergence)
        stub_request(:get, "https://api.polygon.io/v1/indicators/rsi/AAPL")
          .with(
            query: hash_including({
              "window" => "14",
              "timespan" => "day"
            }),
            headers: {"Authorization" => "Bearer test_key_123"}
          )
          .to_return(
            status: 200,
            body: {
              results: {
                underlying: {ticker: "AAPL"},
                values: [
                  {timestamp: 1704067200000, value: 45.0}, # Weak
                  {timestamp: 1704153600000, value: 68.5}, # First high
                  {timestamp: 1704240000000, value: 65.0}, # Cooling
                  {timestamp: 1704326400000, value: 74.3}, # Second high (higher)
                  {timestamp: 1704412800000, value: 67.0}, # Cooling
                  {timestamp: 1704499200000, value: 69.0}, # 3rd RSI peak (lower than 74.3 - DIVERGENCE!)
                  {timestamp: 1704585600000, value: 50.0}, # Dropping
                  {timestamp: 1704672000000, value: 18.4}, # Extremely oversold
                  {timestamp: 1704758400000, value: 31.2}, # Recovery
                  {timestamp: 1704844800000, value: 28.6}  # Weak recovery
                ]
              },
              status: "OK"
            }.to_json,
            headers: {"Content-Type" => "application/json"}
          )

        # Act: User analyzes momentum for divergence signals
        rsi_data = indicators_api.rsi("AAPL",
          window: 14,
          timespan: "day")

        # Assert: User can detect dangerous momentum divergences

        expect(rsi_data.values.length).to eq(10)

        # Business Value Verification: User identifies early warning signals

        # Simulate divergence analysis
        divergence_analysis = []

        # Compare price highs with momentum highs
        price_highs = []
        rsi_highs = []

        stock_prices.each_with_index do |price_point, index|
          rsi_point = rsi_data.values[index]

          # Find local highs (simplified - peak identification)
          if index > 0 && index < stock_prices.length - 1 &&
              index < rsi_data.values.length - 1 # Ensure RSI bounds too
            prev_price = stock_prices[index - 1][:price]
            next_price = stock_prices[index + 1][:price]
            prev_rsi = rsi_data.values[index - 1].value
            next_rsi = rsi_data.values[index + 1].value

            if price_point[:price] > prev_price && price_point[:price] > next_price
              price_highs << {index: index, price: price_point[:price], timestamp: price_point[:timestamp]}
            end

            if rsi_point.value > prev_rsi && rsi_point.value > next_rsi
              rsi_highs << {index: index, rsi: rsi_point.value, timestamp: rsi_point.timestamp}
            end
          end
        end

        # Check for bearish divergence: price making higher highs while RSI makes lower highs
        if price_highs.length >= 2 && rsi_highs.length >= 2
          latest_price_high = price_highs.last
          previous_price_high = price_highs[-2]
          latest_rsi_high = rsi_highs.last
          previous_rsi_high = rsi_highs[-2]

          price_direction = (latest_price_high[:price] > previous_price_high[:price]) ? "higher" : "lower"
          rsi_direction = (latest_rsi_high[:rsi] > previous_rsi_high[:rsi]) ? "higher" : "lower"

          if price_direction == "higher" && rsi_direction == "lower"
            divergence_analysis << {
              type: "bearish_divergence",
              signal: "early_warning_sell",
              confidence: "high",
              price_trend: "rising",
              momentum_trend: "falling",
              risk_level: "elevated"
            }
          end
        end

        # Verify divergence detection provides actionable early warning
        expect(divergence_analysis).to_not be_empty
        warning_signal = divergence_analysis.first
        expect(warning_signal[:type]).to eq("bearish_divergence")
        expect(warning_signal[:signal]).to eq("early_warning_sell")
        expect(warning_signal[:risk_level]).to eq("elevated")

        # Verify user gets clear risk assessment
        expect(warning_signal[:confidence]).to eq("high")
        expect(warning_signal[:price_trend]).to eq("rising")
        expect(warning_signal[:momentum_trend]).to eq("falling")
      end
    end

    context "when managing downside protection" do
      it "implements volatility-based stop losses for consistent risk" do
        # Expected Outcome: User maintains consistent risk per trade regardless of market conditions
        # Success Criteria:
        #   - Stop loss levels adjust automatically based on recent volatility
        #   - Position sizes account for stop distance to maintain consistent dollar risk
        #   - Trailing stops preserve profits while allowing for normal market fluctuation
        #   - Risk per trade never exceeds predetermined portfolio percentage
        # User Value: User can maintain disciplined risk management without manual calculation,
        #             preventing large losses while accommodating different volatility regimes

        skip "Stop loss implementation requires real-time price monitoring - implementation needed"
      end

      it "diversifies across uncorrelated technical signals" do
        # Expected Outcome: User reduces strategy risk through signal diversification
        # Success Criteria:
        #   - Multiple uncorrelated indicators prevent single-point-of-failure risks
        #   - Signal combination techniques improve overall strategy reliability
        #   - Correlation analysis identifies independent vs. redundant signals
        #   - Portfolio performs well even when individual indicators fail
        # User Value: User creates more robust trading strategies that withstand changing market conditions,
        #             reducing strategy-specific risks and improving long-term consistency

        skip "Signal diversification requires multiple indicator correlation analysis - implementation needed"
      end

      it "stress tests strategies against historical extreme events" do
        # Expected Outcome: User understands how strategies perform during market crises
        # Success Criteria:
        #   - Strategy performance during major market crashes and volatility spikes
        #   - Maximum drawdown analysis under extreme stress conditions
        #   - Recovery time analysis shows strategy resilience characteristics
        #   - Tail risk analysis quantifies worst-case scenario impacts
        # User Value: User can prepare for extreme market conditions and size strategies appropriately,
        #             ensuring survival through major market disruptions while maintaining long-term viability

        skip "Stress testing requires extensive historical crisis data - implementation needed"
      end
    end
  end
end
