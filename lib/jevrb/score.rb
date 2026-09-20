# frozen_string_literal: true

module Jevrb
  class Score < Question
    MIN_LEVELS = 2
    MAX_LEVELS = 10

    def self.build(instructions:, criteria:)
      new(instructions: instructions, criteria: criteria)
    end

    private

    def initialize(instructions:, criteria:)
      super(type: "score", instructions: instructions, criteria: normalize_criteria(criteria))
    end

    def normalize_criteria(criteria)
      raise ArgumentError, "criteria must be an array" unless criteria.is_a?(Array)
      unless (MIN_LEVELS..MAX_LEVELS).cover?(criteria.length)
        raise ArgumentError, "criteria must contain #{MIN_LEVELS} through #{MAX_LEVELS} levels"
      end

      criteria.each_with_index.map do |value, index|
        Support.normalize_json_content(value, path: "criteria[#{index}]")
      end.freeze
    end
  end
end
