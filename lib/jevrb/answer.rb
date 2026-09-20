# frozen_string_literal: true

module Jevrb
  class ResponseDataError < StandardError
    attr_reader :field_path

    def initialize(field_path, message)
      @field_path = field_path
      super(message)
    end
  end
  private_constant :ResponseDataError

  module ResponseSupport
    module_function

    def hash(value, path)
      return value if value.is_a?(Hash)

      raise ResponseDataError.new(path, "#{path} must be an object")
    end

    def required(value, key, path)
      return value[key] if value.key?(key)

      raise ResponseDataError.new("#{path}.#{key}", "#{path}.#{key} is required")
    end

    def string(value, path)
      return value.dup.freeze if value.is_a?(String)

      raise ResponseDataError.new(path, "#{path} must be a string")
    end

    def number(value, path, range: nil)
      unless (value.is_a?(Integer) || value.is_a?(Float)) && (!value.is_a?(Float) || value.finite?)
        raise ResponseDataError.new(path, "#{path} must be a finite number")
      end
      if range && !range.cover?(value)
        raise ResponseDataError.new(path, "#{path} must be between #{range.begin} and #{range.end}")
      end

      value.to_f
    end

    def integer_or_nil(value, path)
      return if value.nil?
      return value if value.is_a?(Integer) && value >= 0

      raise ResponseDataError.new(path, "#{path} must be a nonnegative integer or null")
    end

    def probability_hash(value, path, integer_keys: false)
      hash(value, path).each_with_object({}) do |(key, probability), result|
        normalized_key = integer_keys ? integer_key(key, path) : string(key, "#{path} key")
        result[normalized_key] = number(probability, "#{path}.#{key}", range: 0.0..1.0)
      end.freeze
    end

    def integer_key(value, path)
      integer = Integer(value, 10)
      return integer if integer.to_s == value.to_s

      raise ArgumentError
    rescue ArgumentError, TypeError
      raise ResponseDataError.new(path, "#{path} keys must be integer strings")
    end

    def json_content(value, path)
      Support.normalize_json_content(value, path: path)
    rescue ArgumentError => e
      raise ResponseDataError.new(path, e.message)
    end
  end
  private_constant :ResponseSupport

  class Answer
    attr_reader :type

    private

    def initialize(type)
      @type = type.freeze
    end

    def finish_initialization
      freeze
    end
  end

  class NoulAnswer < Answer
    attr_reader :noul

    def self.from_hash(value, path:)
      value = ResponseSupport.hash(value, path)
      type = ResponseSupport.string(ResponseSupport.required(value, "type", path), "#{path}.type")
      raise ResponseDataError.new("#{path}.type", "#{path}.type must be noul") unless type == "noul"

      new(noul: ResponseSupport.number(
        ResponseSupport.required(value, "noul", path),
        "#{path}.noul",
        range: 0.0..1.0
      ))
    end

    def to_h
      { type: type, noul: noul }
    end

    private

    def initialize(noul:)
      super("noul")
      @noul = noul
      finish_initialization
    end
  end

  class ChoiceAnswer < Answer
    attr_reader :choice, :probabilities, :confidence

    def self.from_hash(value, path:)
      value = ResponseSupport.hash(value, path)
      type = ResponseSupport.string(ResponseSupport.required(value, "type", path), "#{path}.type")
      raise ResponseDataError.new("#{path}.type", "#{path}.type must be choice") unless type == "choice"

      new(
        choice: ResponseSupport.string(ResponseSupport.required(value, "choice", path), "#{path}.choice"),
        probabilities: ResponseSupport.probability_hash(
          ResponseSupport.required(value, "probabilities", path),
          "#{path}.probabilities"
        ),
        confidence: ResponseSupport.number(
          ResponseSupport.required(value, "confidence", path),
          "#{path}.confidence",
          range: 0.0..1.0
        )
      )
    end

    def to_h
      {
        type: type,
        choice: choice,
        probabilities: probabilities,
        confidence: confidence
      }
    end

    private

    def initialize(choice:, probabilities:, confidence:)
      super("choice")
      @choice = choice
      @probabilities = probabilities
      @confidence = confidence
      finish_initialization
    end
  end

  class ScoreAnswer < Answer
    attr_reader :score, :legend, :probabilities, :confidence

    def self.from_hash(value, path:)
      value = ResponseSupport.hash(value, path)
      type = ResponseSupport.string(ResponseSupport.required(value, "type", path), "#{path}.type")
      raise ResponseDataError.new("#{path}.type", "#{path}.type must be score") unless type == "score"

      new(
        score: ResponseSupport.number(ResponseSupport.required(value, "score", path), "#{path}.score"),
        legend: parse_legend(ResponseSupport.required(value, "legend", path), "#{path}.legend"),
        probabilities: ResponseSupport.probability_hash(
          ResponseSupport.required(value, "probabilities", path),
          "#{path}.probabilities",
          integer_keys: true
        ),
        confidence: ResponseSupport.number(
          ResponseSupport.required(value, "confidence", path),
          "#{path}.confidence",
          range: 0.0..1.0
        )
      )
    end

    def self.parse_legend(value, path)
      ResponseSupport.hash(value, path).each_with_object({}) do |(key, description), result|
        integer_key = ResponseSupport.integer_key(key, path)
        result[integer_key] = ResponseSupport.json_content(description, "#{path}.#{key}")
      end.freeze
    end
    private_class_method :parse_legend

    def to_h
      {
        type: type,
        score: score,
        legend: legend,
        probabilities: probabilities,
        confidence: confidence
      }
    end

    private

    def initialize(score:, legend:, probabilities:, confidence:)
      super("score")
      @score = score
      @legend = legend
      @probabilities = probabilities
      @confidence = confidence
      finish_initialization
    end
  end
end
