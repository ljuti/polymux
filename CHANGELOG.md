## [Unreleased]

### Added - Phase 1: Complete Stock Market Data API

#### Core Stock Market Functionality
- **Complete `Polymux::Api::Stocks` class** with 8 comprehensive methods:
  - `tickers` - Stock discovery with advanced filtering (active, market, ticker, limit)
  - `ticker_details` - Individual ticker information with market cap and industry classification
  - `snapshot` - Real-time stock snapshots with last trade/quote data
  - `all_snapshots` - Market-wide snapshot data for portfolio monitoring
  - `trades` - Historical trade data with pagination and filtering
  - `quotes` - Bid/ask quote data with spread analysis
  - `aggregates` - Historical OHLC bars with custom timeframes and date ranges
  - `previous_day` - Previous trading day data for comparison
  - `daily_summary` - Comprehensive daily summary including after-hours data

#### Stock Data Types & Analysis
- **`Polymux::Api::Stocks::Ticker`** - Basic ticker information with market classification
- **`Polymux::Api::Stocks::TickerDetails`** - Comprehensive company information with financial metrics
- **`Polymux::Api::Stocks::Trade`** - Individual trade execution data with analysis methods
- **`Polymux::Api::Stocks::Quote`** - Bid/ask quote data with spread calculations
- **`Polymux::Api::Stocks::Snapshot`** - Real-time market snapshot with current pricing
- **`Polymux::Api::Stocks::Aggregate`** - OHLC bars with technical analysis methods (candlestick patterns, volatility metrics)
- **`Polymux::Api::Stocks::DailySummary`** - Daily trading summary with pre/after-market data

#### Investment Analysis Features
- **Stock Discovery**: Active ticker filtering for investment universe building
- **Portfolio Monitoring**: Real-time price tracking and performance calculation
- **Historical Analysis**: OHLC data with built-in technical analysis methods
- **Market Classification**: Exchange, sector, and market cap classification
- **Risk Assessment**: Volatility calculations and price pattern analysis

#### Comprehensive BDD Testing
- **331 total tests** (increased from 268)
- **5 passing behavioral specs** focused on user investment workflows:
  - Stock discovery for investment opportunities  
  - Portfolio validation and compliance checking
  - Company fundamental analysis for investment decisions
  - Active vs inactive stock filtering for clean universe building
  - Market classification for regulatory compliance
- **10 pending behavioral specs** for future phases (real-time monitoring, historical performance analysis)
- **36 API contract tests** ensuring technical correctness
- **100% passing test suite** with comprehensive error handling coverage

#### Documentation & Examples
- Complete usage examples for all stock functionality
- Real-world investment workflow demonstrations
- Portfolio analysis and backtesting examples
- Technical analysis pattern examples with OHLC data
- Error handling patterns for production use

### Technical Improvements
- Enhanced type safety with comprehensive timestamp handling (String/Integer nanosecond support)
- Improved API parameter validation and error handling
- Complete integration with existing options and market data APIs
- Consistent data transformation patterns across all endpoints

## [0.1.0] - 2025-06-24

- Initial release with complete options trading functionality
