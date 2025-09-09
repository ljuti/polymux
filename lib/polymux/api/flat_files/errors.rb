# frozen_string_literal: true

module Polymux
  module Api
    module FlatFiles
      # Base error class for FlatFiles operations
      class Error < StandardError; end

      # Authentication-related errors
      class AuthenticationError < Error
        attr_reader :error_code, :resolution_steps

        def initialize(message, error_code: nil, resolution_steps: [])
          super(message)
          @error_code = error_code
          @resolution_steps = resolution_steps
        end
      end

      # File not found errors with helpful context
      class FileNotFoundError < Error
        attr_reader :requested_date, :reason, :alternative_dates, :data_availability_through

        def initialize(message, requested_date: nil, reason: nil, alternative_dates: [], data_availability_through: nil)
          super(message)
          @requested_date = requested_date
          @reason = reason
          @alternative_dates = alternative_dates
          @data_availability_through = data_availability_through
        end
      end

      # Network-related errors
      class NetworkError < Error; end

      # Data integrity errors
      class IntegrityError < Error; end
    end
  end
end