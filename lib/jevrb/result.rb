# frozen_string_literal: true

module Jevrb
  class Result
    ANSWER_CLASSES = {
      "noul" => NoulAnswer,
      "choice" => ChoiceAnswer,
      "score" => ScoreAnswer
    }.freeze

    attr_reader :model, :answers, :usage, :request_id, :nouls, :choices, :scores

    def self.from_hash(value, key_map: {}, request_id: nil)
      value = ResponseSupport.hash(value, "response")
      model = ResponseSupport.string(ResponseSupport.required(value, "model", "response"), "model")
      usage = Usage.from_hash(ResponseSupport.required(value, "usage", "response"))
      answers = parse_answers(ResponseSupport.required(value, "answers", "response"), key_map)

      new(model: model, answers: answers, usage: usage, request_id: request_id)
    end

    def self.parse_answers(value, key_map)
      ResponseSupport.hash(value, "answers").each_with_object({}) do |(key, answer), result|
        key = ResponseSupport.string(key, "answers key")
        answer = ResponseSupport.hash(answer, "answers.#{key}")
        type = ResponseSupport.string(
          ResponseSupport.required(answer, "type", "answers.#{key}"),
          "answers.#{key}.type"
        )
        answer_class = ANSWER_CLASSES[type]
        raise ResponseDataError.new("answers.#{key}.type", "unknown answer type #{type.inspect}") unless answer_class

        result[key_map.fetch(key, key)] = answer_class.from_hash(answer, path: "answers.#{key}")
      end.freeze
    end
    private_class_method :parse_answers

    def to_h
      {
        model: model,
        answers: answers.transform_values(&:to_h),
        usage: usage.to_h
      }
    end

    private

    def initialize(model:, answers:, usage:, request_id:)
      @model = model
      @answers = answers
      @usage = usage
      @request_id = request_id&.dup&.freeze
      @nouls = answers.select { |_key, answer| answer.is_a?(NoulAnswer) }.freeze
      @choices = answers.select { |_key, answer| answer.is_a?(ChoiceAnswer) }.freeze
      @scores = answers.select { |_key, answer| answer.is_a?(ScoreAnswer) }.freeze
      freeze
    end
  end
end
