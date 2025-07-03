require "dry/types"

module Polymux
  module Types
    include Dry.Types()

    PolymuxNumber = Types::Nominal::Integer | Types::Nominal::Float
  end
end