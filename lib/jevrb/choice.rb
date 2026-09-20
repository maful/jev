# frozen_string_literal: true

module Jevrb
  class Choice < Question
    MAX_OPTIONS = 255

    def self.build(instructions:, criteria:)
      new(instructions: instructions, criteria: criteria)
    end

    private

    def initialize(instructions:, criteria:)
      super(type: "choice", instructions: instructions, criteria: normalize_criteria(criteria))
    end

    def normalize_criteria(criteria)
      raise ArgumentError, "criteria must be a hash" unless criteria.is_a?(Hash)
      raise ArgumentError, "criteria must not be empty" if criteria.empty?
      raise ArgumentError, "criteria cannot contain more than #{MAX_OPTIONS} options" if criteria.size > MAX_OPTIONS

      criteria.each_with_object({}) do |(key, value), result|
        unless key.is_a?(String) || key.is_a?(Symbol)
          raise ArgumentError, "criteria option names must be strings or symbols"
        end

        normalized_key = key.to_s
        if result.key?(normalized_key)
          raise ArgumentError,
                "criteria contains duplicate option #{normalized_key.inspect}"
        end

        result[normalized_key.freeze] = Support.normalize_json_content(
          value,
          path: "criteria.#{normalized_key}",
          allow_nil: true
        )
      end.freeze
    end
  end
end
