# frozen_string_literal: true

module Jevrb
  class Question
    attr_reader :type, :instructions, :criteria

    def to_h
      hash = { type: type, instructions: instructions }
      hash[:criteria] = criteria unless criteria.nil?
      hash
    end

    private

    def initialize(type:, instructions:, criteria:)
      @type = type.freeze
      @instructions = Support.normalize_json_content(instructions, path: "instructions")
      @criteria = criteria
      freeze
    end
  end
end
