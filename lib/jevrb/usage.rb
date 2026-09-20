# frozen_string_literal: true

module Jevrb
  class Usage
    attr_reader :input_tokens, :output_tokens

    def self.from_hash(value, path: "usage")
      value = ResponseSupport.hash(value, path)
      new(
        input_tokens: ResponseSupport.integer_or_nil(value["input_tokens"], "#{path}.input_tokens"),
        output_tokens: ResponseSupport.integer_or_nil(value["output_tokens"], "#{path}.output_tokens")
      )
    end

    def to_h
      { input_tokens: input_tokens, output_tokens: output_tokens }
    end

    private

    def initialize(input_tokens:, output_tokens:)
      @input_tokens = input_tokens
      @output_tokens = output_tokens
      freeze
    end
  end
end
