# frozen_string_literal: true

module Jevrb
  class Noul < Question
    CRITERIA_KEYS = %w[true false].freeze

    def self.build(instructions:, criteria: nil)
      new(instructions: instructions, criteria: criteria)
    end

    private

    def initialize(instructions:, criteria:)
      super(type: "noul", instructions: instructions, criteria: normalize_criteria(criteria))
    end

    def normalize_criteria(criteria)
      return if criteria.nil?
      raise ArgumentError, "criteria must be a hash" unless criteria.is_a?(Hash)

      normalized = criteria.each_with_object({}) do |(key, value), result|
        normalized_key = key.to_s
        raise ArgumentError, "criteria accepts only true and false keys" unless CRITERIA_KEYS.include?(normalized_key)
        raise ArgumentError, "criteria contains duplicate key #{normalized_key.inspect}" if result.key?(normalized_key)

        result[normalized_key.freeze] = Support.normalize_json_content(
          value,
          path: "criteria.#{normalized_key}",
          allow_nil: true
        )
      end

      normalized.freeze
    end
  end
end
