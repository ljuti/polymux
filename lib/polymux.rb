# frozen_string_literal: true

require "polymux/config"
require "polymux/client"
require "polymux/types"
require "polymux/version"
require "polymux/api"
require "polymux/websocket"

# Polymux is a Ruby client library for the Polygon.io API, providing access to
# financial market data including stocks, options, forex, and cryptocurrencies.
#
# The library is built around a modular architecture with separate API modules
# for different asset classes and data types. It uses Faraday for HTTP requests,
# dry-struct for immutable data structures, and anyway_config for flexible
# configuration management.
#
# @example Basic usage
#   # Configure with API key
#   client = Polymux::Client.new
#
#   # Access options data
#   contracts = client.options.contracts("AAPL")
#
#   # Get market status
#   status = client.markets.status
#
# @example Custom configuration
#   config = Polymux::Config.new(
#     api_key: "your_api_key",
#     base_url: "https://api.polygon.io"
#   )
#   client = Polymux::Client.new(config)
#
# @see Polymux::Client The main client interface
# @see Polymux::Config Configuration management
# @see Polymux::Api::Options Options trading data API
module Polymux
  # Base exception class for all Polymux-related errors.
  #
  # All custom exceptions in the Polymux library inherit from this class,
  # providing a common ancestor for error handling.
  class Error < StandardError; end

  # Base exception class for API-related errors.
  #
  # Raised when API requests fail due to network issues, invalid responses,
  # or server errors from the Polygon.io API.
  class Api::Error < Error; end

  # Exception raised when API credentials are invalid or missing.
  #
  # This typically occurs when the API key is incorrect, expired, or missing
  # from the configuration.
  class Api::InvalidCredentials < Error; end

  # Exception raised when no previous trading day data is available.
  #
  # This specific error occurs in options API calls when requesting previous
  # day data for contracts that don't have historical data available.
  class Api::Options::NoPreviousDataFound < Error; end
end
