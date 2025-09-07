require "dry/types"

module Polymux
  # Type definitions using dry-types for data validation and coercion.
  #
  # This module provides custom type definitions used throughout the Polymux
  # library for ensuring data integrity and providing clear type contracts.
  # All types are built on top of the dry-types gem which provides runtime
  # type checking and coercion capabilities.
  #
  # These types are primarily used in dry-struct definitions for API response
  # data structures, ensuring that data from the Polygon.io API is properly
  # validated and coerced to the expected Ruby types.
  #
  # @example Using types in structs
  #   class MyStruct < Dry::Struct
  #     attribute :price, Types::PolymuxNumber
  #     attribute :volume, Types::Integer
  #   end
  #
  # @see https://dry-rb.org/gems/dry-types/ dry-types documentation
  module Types
    include Dry.Types()

    # Union type that accepts either Integer or Float values.
    #
    # This type is commonly used for financial data that can be represented
    # as either integers or floating-point numbers, such as prices, volumes,
    # or other numerical market data from the Polygon.io API.
    #
    # @example
    #   Types::PolymuxNumber[100]     # => 100 (Integer)
    #   Types::PolymuxNumber[99.95]   # => 99.95 (Float)
    #   Types::PolymuxNumber["99.95"] # => Raises coercion error
    PolymuxNumber = Types::Nominal::Integer | Types::Nominal::Float
  end
end
