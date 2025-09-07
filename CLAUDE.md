# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Common Development Commands

- **Run tests**: `rake spec` or `bundle exec rspec`
- **Run linting**: `bundle exec standardrb` (automatically fixes issues)
- **Check linting**: `bundle exec standardrb --check`
- **Run both tests and linting**: `rake` (default task)
- **Install dependencies**: `bundle install`
- **Interactive console**: `bin/console`
- **Install gem locally**: `bundle exec rake install`

## Architecture Overview

Polymux is a Ruby client library for the Polygon.io API with the following key architectural components:

### Core Components

- **`Polymux::Client`**: Main entry point that manages HTTP connections via Faraday and provides access to API modules
- **`Polymux::Config`**: Configuration management using `anyway_config` gem, handles API keys and base URLs
- **`Polymux::Api::Options`**: Primary API module for options trading data with methods for contracts, snapshots, chains, trades, quotes, and market data

### Data Layer

- **Types**: Uses `dry-struct` for immutable data structures to represent API responses
- **Transformers**: Located in `lib/polymux/api/transformers.rb` for data transformation between API format and Ruby objects
- **Options Types**: Specialized structs in `lib/polymux/api/options/` for different options data types (contracts, trades, quotes, snapshots, etc.)

### Error Handling

Custom exception hierarchy:
- `Polymux::Error` (base)
- `Polymux::Api::Error` (API errors)
- `Polymux::Api::InvalidCredentials`
- `Polymux::Api::Options::NoPreviousDataFound`

### Configuration

Uses `anyway_config` for flexible configuration management:
- Config file: `config/polymux.local.yml`
- Environment variables with `POLYMUX_` prefix
- Required: `api_key`, `base_url`

### Standards

- Ruby 3.1+ required
- Uses StandardRB for linting and formatting
- RSpec for testing
- Dependencies: Faraday (HTTP), ActiveSupport, dry-struct, dry-transformer