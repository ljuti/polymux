require "dry/struct"

module Polymux
  module Api
    class Options
      class Greeks < Dry::Struct
        transform_keys(&:to_sym)

        attribute? :delta, Types::Float | Types::Nil
        attribute? :gamma, Types::Float | Types::Nil
        attribute? :theta, Types::Float | Types::Nil
        attribute? :vega, Types::Float | Types::Nil
      end
    end
  end
end
