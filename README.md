# Polymux

A comprehensive Ruby client library for the Polygon.io API, providing access to financial market data including options, stocks, exchanges, and real-time streaming.

## Features

- **Production-Ready Options Trading**: Complete options contracts, snapshots, chains, trades, quotes, and market data with comprehensive analysis tools
- **Complete Stock Market Data**: Real-time quotes, historical trades, OHLC aggregates, market snapshots, and ticker discovery with advanced filtering
- **Market Information**: Real-time market status, holidays, and trading schedules  
- **Exchange Data**: Comprehensive exchange listings with asset class filtering
- **WebSocket Streaming**: Real-time and delayed data feeds for options and stocks
- **Type Safety**: Immutable data structures using dry-struct for reliable data handling
- **Flexible Configuration**: Environment variables, YAML files, or direct configuration
- **Comprehensive BDD Testing**: **331 tests** including behavioral specs focused on user investment workflows
- **Complete Documentation**: All classes and methods fully documented with YARD and real-world examples

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

### Stock Market Data

```ruby
stocks = client.stocks

# Stock Discovery & Universe Building
active_tickers = stocks.tickers(active: true, market: "stocks", limit: 1000)
puts "Found #{active_tickers.length} active stocks for screening"

# Screen for large-cap technology stocks
large_cap_tech = active_tickers.select do |ticker|
  details = stocks.ticker_details(ticker.ticker)
  details.market_cap && details.market_cap > 10_000_000_000 &&
  details.sic_description&.include?("Computer")
end
puts "Large-cap tech stocks: #{large_cap_tech.length}"

# Real-time Market Data
snapshot = stocks.snapshot("AAPL")
puts "#{snapshot.ticker}: $#{snapshot.last_trade.price}"
puts "Daily change: #{snapshot.daily_bar.change_percent.round(2)}%"
puts "Volume: #{snapshot.daily_bar.volume.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"

# Portfolio Performance Monitoring  
portfolio = ["AAPL", "MSFT", "GOOGL", "TSLA"]
portfolio_snapshots = portfolio.map { |ticker| stocks.snapshot(ticker) }

puts "\nPortfolio Performance:"
portfolio_snapshots.each do |snap|
  change_pct = snap.daily_bar.change_percent
  indicator = change_pct >= 0 ? "📈" : "📉"
  puts "#{indicator} #{snap.ticker}: $#{snap.last_trade.price} (#{change_pct.round(2)}%)"
end

# Historical Analysis & Backtesting
historical_data = stocks.aggregates("AAPL", 1, "day", "2024-01-01", "2024-12-31")
puts "\nAAPL 2024 Analysis:"
puts "Total trading days: #{historical_data.length}"

# Calculate key metrics
prices = historical_data.map(&:close)
returns = prices.each_cons(2).map { |prev, curr| (curr - prev) / prev }
avg_return = returns.sum / returns.length
volatility = Math.sqrt(returns.map { |r| (r - avg_return) ** 2 }.sum / returns.length)

puts "Average daily return: #{(avg_return * 100).round(4)}%"  
puts "Daily volatility: #{(volatility * 100).round(4)}%"
puts "Annualized volatility: #{(volatility * Math.sqrt(252) * 100).round(2)}%"

# Technical Analysis
recent_bars = historical_data.last(20)
sma_20 = recent_bars.map(&:close).sum / recent_bars.length
current_price = recent_bars.last.close

puts "Current price: $#{current_price}"
puts "20-day SMA: $#{sma_20.round(2)}"
puts "Price vs SMA: #{current_price > sma_20 ? 'Above' : 'Below'} trend"
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

### Testing

The library includes a comprehensive test suite with **331 tests** covering all functionality, including behavioral specs focused on user investment workflows:

```bash
# Run all tests
bundle exec rspec

# Run with coverage
bundle exec rspec --format documentation

# Run specific test files
bundle exec rspec spec/polymux/api/stocks_spec.rb
bundle exec rspec spec/behavior/stocks_behavior_spec.rb
bundle exec rspec spec/polymux/api/options_spec.rb
```

### Documentation

All classes are fully documented with YARD. Generate documentation locally:

```bash
yard doc
```

## Current Status

✅ **Production Ready**: Complete options trading and stock market data functionality with comprehensive error handling  
✅ **Complete Stock Market Data**: Real-time quotes, historical OHLC data, market snapshots, ticker discovery, and portfolio analysis tools  
✅ **Fully Tested**: **331 tests** covering all components, API endpoints, edge cases, and user behavioral workflows  
✅ **BDD Testing Approach**: Behavioral specs focused on real user investment research and analysis scenarios  
✅ **Completely Documented**: All classes and methods documented with practical examples and usage patterns  
✅ **Type Safe**: Immutable data structures prevent runtime errors and ensure data integrity  
✅ **Flexible Configuration**: Multiple configuration options for different environments

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/ljuti/polymux.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
