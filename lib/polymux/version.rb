# frozen_string_literal: true

module Polymux
  def self.gem_version
    Gem::Version.new(VERSION::STRING)
  end

  module VERSION
    MAJOR = 0
    MINOR = 1
    PATCH = 0
    STRING = [MAJOR, MINOR, PATCH].join('.')
  end
end
