require "anyway_config"

module Polymux
  # Configuration management for Polymux client using anyway_config.
  #
  # This class handles loading configuration from multiple sources in the
  # following priority order:
  # 1. Direct initialization parameters
  # 2. Environment variables with POLYMUX_ prefix
  # 3. Configuration files (polymux.yml, config/polymux.yml, etc.)
  # 4. Default values
  #
  # @example Environment variable configuration
  #   # Set environment variables:
  #   # POLYMUX_API_KEY=your_api_key
  #   # POLYMUX_BASE_URL=https://api.polygon.io
  #
  #   config = Polymux::Config.new
  #   puts config.api_key  # => "your_api_key"
  #
  # @example Direct parameter configuration
  #   config = Polymux::Config.new(
  #     api_key: "your_polygon_api_key",
  #     base_url: "https://api.polygon.io"
  #   )
  #
  # @example YAML file configuration (config/polymux.yml)
  #   # config/polymux.yml
  #   production:
  #     api_key: <%= ENV['POLYGON_API_KEY'] %>
  #     base_url: https://api.polygon.io
  #
  #   development:
  #     api_key: your_dev_api_key
  #     base_url: https://api.polygon.io
  #
  # @see https://github.com/palkan/anyway_config anyway_config documentation
  class Config < Anyway::Config
    # The configuration namespace for anyway_config.
    # This determines environment variable prefix (POLYMUX_) and
    # configuration file names (polymux.yml).
    config_name :polymux

    # Polygon.io API key for authentication.
    #
    # This is required for all API requests. You can obtain an API key
    # by signing up at https://polygon.io
    #
    # @return [String] The API key
    attr_config :api_key

    # Base URL for the Polygon.io API.
    #
    # Defaults to the standard Polygon.io API endpoint. This can be
    # customized for testing or if using a different API endpoint.
    #
    # @return [String] The base URL (default: "https://api.polygon.io")
    attr_config :base_url, default: "https://api.polygon.io"
  end
end
