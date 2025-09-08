#!/usr/bin/env ruby

require_relative "lib/polymux"
require "webmock/rspec"

include WebMock::API
WebMock.enable!

config = Polymux::Config.new(api_key: "test_key_123", base_url: "https://api.polygon.io")
client = Polymux::Client.new(config)
indicators_api = client.technical_indicators

# Stub the same data as in the test
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
          {timestamp: 1704067200000, value: 45.0},
          {timestamp: 1704153600000, value: 68.5},
          {timestamp: 1704240000000, value: 65.0},
          {timestamp: 1704326400000, value: 74.3},
          {timestamp: 1704412800000, value: 67.0},
          {timestamp: 1704499200000, value: 70.0},
          {timestamp: 1704585600000, value: 50.0},
          {timestamp: 1704672000000, value: 18.4},
          {timestamp: 1704758400000, value: 31.2},
          {timestamp: 1704844800000, value: 28.6}
        ]
      },
      status: "OK"
    }.to_json,
    headers: {"Content-Type" => "application/json"}
  )

# Act: User analyzes momentum for divergence signals
rsi_data = indicators_api.rsi("AAPL",
  window: 14,
  timespan: "day",
  timestamp_gte: "2024-01-01",
  timestamp_lte: "2024-03-31")

puts "RSI data values length: #{rsi_data.values.length}"
rsi_data.values.each_with_index do |val, i|
  puts "Index #{i}: #{val.inspect}"
end
