# frozen_string_literal: true

require "polymux/config"
require "polymux/client"
require "polymux/types"
require "polymux/version"
require "polymux/api"

module Polymux
  class Error < StandardError; end

  class Api::Error < Error; end
  class Api::InvalidCredentials < Error; end
  class Api::Options::NoPreviousDataFound < Error; end
  # Your code goes here...
end
