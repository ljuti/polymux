require "anyway_config"

module Polymux
  class Config < Anyway::Config
    config_name :polymux
    attr_config :api_key
    attr_config :base_url
  end
end
