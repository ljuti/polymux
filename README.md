# Polymux

A comprehensive Ruby client library for the Polygon.io API, providing access to financial market data including options, stocks, exchanges, and real-time streaming.

## Features

- **Options Trading Data**: Complete options contracts, snapshots, chains, trades, quotes, and market data
- **Market Information**: Real-time market status, holidays, and trading schedules  
- **Exchange Data**: Comprehensive exchange listings with asset class filtering
- **WebSocket Streaming**: Real-time and delayed data feeds for options and stocks
- **Type Safety**: Immutable data structures using dry-struct for reliable data handling
- **Flexible Configuration**: Environment variables, YAML files, or direct configuration

## Installation

Install the gem and add to the application's Gemfile by executing:

```bash
bundle add polymux
```

If bundler is not being used to manage dependencies, install the gem by executing:

```bash
gem install polymux
```

## Configuration

### Environment Variables

Set your Polygon.io API key using environment variables:

```bash
export POLYMUX_API_KEY="your_polygon_api_key"
export POLYMUX_BASE_URL="https://api.polygon.io"  # optional, this is the default
```

### Configuration File

Create a `config/polymux.yml` file:

```yaml
development:
  api_key: your_development_api_key
  base_url: https://api.polygon.io

production:
  api_key: <%= ENV['POLYGON_API_KEY'] %>
  base_url: https://api.polygon.io
```

### Direct Configuration

```ruby
config = Polymux::Config.new(
  api_key: "your_polygon_api_key",
  base_url: "https://api.polygon.io"
)
client = Polymux::Client.new(config)
```

## Usage

### Basic Client Setup

```ruby
require 'polymux'

# Use environment variables or config files
client = Polymux::Client.new

# Or configure directly
client = Polymux::Client.new(
  Polymux::Config.new(api_key: "your_api_key")
)
```

### Options Trading Data

```ruby
options = client.options

# Find all AAPL options contracts
contracts = options.contracts("AAPL")
puts "Found #{contracts.length} AAPL contracts"

# Get current market snapshot for a specific contract
contract = contracts.first
snapshot = options.snapshot(contract)

puts "Contract: #{contract.ticker}"
puts "Strike: $#{contract.strike_price} #{contract.call? ? 'Call' : 'Put'}"
puts "Expires: #{contract.expiration_date}"

if snapshot.last_trade
  puts "Last trade: #{snapshot.last_trade.size} @ $#{snapshot.last_trade.price}"
  puts "Total premium: $#{snapshot.last_trade.total_price}"
end

if snapshot.greeks
  puts "Delta: #{snapshot.greeks.delta}"
  puts "Gamma: #{snapshot.greeks.gamma}"  
  puts "Theta: #{snapshot.greeks.theta}"
  puts "Vega: #{snapshot.greeks.vega}"
end

# Get complete options chain for underlying
chain = options.chain("AAPL")
active_options = chain.select { |snap| snap.last_trade }
puts "Active contracts in chain: #{active_options.length}"

# Analyze recent trading activity
trades = options.trades(contract, limit: 100)
total_volume = trades.sum(&:size)
avg_price = trades.map(&:price).sum / trades.length
puts "Recent activity: #{total_volume} contracts at avg $#{avg_price.round(4)}"

# Get bid/ask quotes
quotes = options.quotes(contract, limit: 50)
latest_quote = quotes.last
if latest_quote
  puts "Bid: #{latest_quote.bid_size} @ $#{latest_quote.bid_price}"
  puts "Ask: #{latest_quote.ask_size} @ $#{latest_quote.ask_price}"
  puts "Spread: $#{latest_quote.spread} (#{latest_quote.spread_percentage.round(2)}%)"
end
```

### Market Status and Scheduling

```ruby
markets = client.markets

# Check current market status
status = markets.status
puts "Market is #{status.open? ? 'open' : 'closed'}"
puts "Extended hours: #{status.extended_hours?}" 
puts "Pre-market: #{status.pre_market}"
puts "After-hours: #{status.after_hours}"

# Check upcoming holidays
holidays = markets.holidays
holidays.first(3).each do |holiday|
  puts "#{holiday.date}: #{holiday.name}"
  if holiday.closed?
    puts "  Market closed all day"
  elsif holiday.early_close?
    puts "  Early close at #{holiday.close}"
  end
end
```

### Exchange Information

```ruby
exchanges = client.exchanges.list

puts "Total exchanges: #{exchanges.length}"

# Filter by asset class
options_exchanges = exchanges.select(&:options?)
stocks_exchanges = exchanges.select(&:stocks?)
crypto_exchanges = exchanges.select(&:crypto?)

puts "Options exchanges: #{options_exchanges.length}"
puts "Stock exchanges: #{stocks_exchanges.length}"
puts "Crypto exchanges: #{crypto_exchanges.length}"

# Find specific exchange
nasdaq = exchanges.find { |e| e.name.include?("NASDAQ") }
if nasdaq
  puts "#{nasdaq.name} (#{nasdaq.mic})"
  puts "Asset class: #{nasdaq.asset_class}"
  puts "Website: #{nasdaq.url}"
end
```

### Real-time WebSocket Streaming

```ruby
require 'eventmachine'
require 'faye/websocket'

# Initialize WebSocket client
ws = Polymux::Websocket.new(client.config, mode: :realtime)

# Configure for options data
ws.options.start

# For delayed data (15-minute delay)
ws_delayed = Polymux::Websocket.new(client.config, mode: :delayed)
ws_delayed.stocks.start
```

### Error Handling

```ruby
begin
  contracts = client.options.contracts("INVALID_SYMBOL")
rescue Polymux::Api::Error => e
  puts "API Error: #{e.message}"
rescue Polymux::Api::InvalidCredentials => e
  puts "Invalid API key: #{e.message}"
rescue Polymux::Error => e
  puts "Polymux Error: #{e.message}"
end

# Handle specific options errors
begin
  prev_day = client.options.previous_day("O:INVALID240315C00150000")
rescue Polymux::Api::Options::NoPreviousDataFound => e
  puts "No previous day data available for this contract"
end
```

### Data Analysis Examples

```ruby
# Options chain analysis
chain = client.options.chain("AAPL")

# Find most liquid contracts
by_volume = chain.select { |snap| snap.daily_bar&.volume }
                 .sort_by { |snap| -(snap.daily_bar.volume) }

puts "Most active contracts:"
by_volume.first(5).each do |snap|
  volume = snap.daily_bar.volume
  iv = snap.implied_volatility
  puts "#{snap.underlying_asset.ticker}: #{volume} volume, #{(iv * 100).round(1)}% IV"
end

# Risk analysis using Greeks  
high_gamma_options = chain.select { |snap| snap.greeks&.high_gamma? }
puts "High gamma risk contracts: #{high_gamma_options.length}"

# Break-even analysis
chain.each do |snap|
  underlying_price = snap.underlying_asset.price
  break_even = snap.break_even_price
  
  distance = ((break_even - underlying_price) / underlying_price * 100).abs
  puts "#{snap.underlying_asset.ticker} needs #{distance.round(1)}% move to break even"
end
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/ljuti/polymux.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
