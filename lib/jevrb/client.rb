# frozen_string_literal: true

require "json"
require "uri"

module Jevrb
  class Client
    NOT_GIVEN = Object.new.freeze
    SYSTEM_ONE_PATH = "/v1/systemone"

    attr_reader :api_key, :base_url, :model, :timeout, :retry_policy

    def initialize(
      api_key: NOT_GIVEN,
      base_url: NOT_GIVEN,
      model: NOT_GIVEN,
      timeout: DEFAULT_TIMEOUT,
      retry_policy: nil
    )
      @api_key = client_value(api_key, API_KEY_ENV)
      @base_url = client_value(base_url, BASE_URL_ENV, DEFAULT_BASE_URL)
      @model = client_value(model, DEFAULT_MODEL_ENV, DEFAULT_MODEL)
      @timeout = positive_number(timeout, "timeout")
      @retry_policy = retry_policy || RetryPolicy.new

      validate_configuration
      @transport = Transport.new(base_url: @base_url)
    end

    def system_one(state, questions:, model: nil)
      state = Support.normalize_json_content(state, path: "state")
      questions, key_map = serialize_questions(questions)
      request_model = model.nil? ? @model : nonempty_string(model, "model")
      body = JSON.generate(state: state, model: request_model, questions: questions)
      endpoint = @transport.endpoint(SYSTEM_ONE_PATH)

      retry_policy.execute do
        response = @transport.post(
          SYSTEM_ONE_PATH,
          body: body,
          headers: request_headers,
          timeout: timeout
        )
        handle_response(response, endpoint: endpoint, key_map: key_map)
      end
    end

    private

    def client_value(explicit, environment_name, default = nil)
      return normalize_client_value(explicit) unless explicit.equal?(NOT_GIVEN)

      environment_value = ENV.fetch(environment_name, nil)
      normalized = normalize_client_value(environment_value)
      normalized.nil? ? default : normalized
    end

    def normalize_client_value(value)
      return if value.nil?
      return value.strip if value.is_a?(String)

      value
    end

    def validate_configuration
      raise ConfigurationError, "api_key is required" unless api_key.is_a?(String) && !api_key.empty?

      raise ConfigurationError, "model must be a nonempty string" unless model.is_a?(String) && !model.empty?

      validate_base_url
      return if retry_policy.is_a?(RetryPolicy)

      raise ConfigurationError, "retry_policy must be a Jevrb::RetryPolicy"
    end

    def validate_base_url
      unless base_url.is_a?(String) && !base_url.empty?
        raise ConfigurationError, "base_url must be an HTTP or HTTPS URL"
      end

      uri = URI.parse(base_url)
      valid = %w[http https].include?(uri.scheme) && uri.host && !uri.userinfo && !uri.query && !uri.fragment
      raise ConfigurationError, "base_url must be an HTTP or HTTPS URL" unless valid
    rescue URI::InvalidURIError
      raise ConfigurationError, "base_url must be an HTTP or HTTPS URL"
    end

    def nonempty_string(value, name)
      return value if value.is_a?(String) && !value.empty?

      raise ArgumentError, "#{name} must be a nonempty string"
    end

    def positive_number(value, name)
      return value.to_f if (value.is_a?(Integer) || value.is_a?(Float)) && value.finite? && value.positive?

      raise ConfigurationError, "#{name} must be a positive number"
    end

    def serialize_questions(questions)
      raise ArgumentError, "questions must be a hash" unless questions.is_a?(Hash)
      raise ArgumentError, "questions must not be empty" if questions.empty?

      key_map = {}
      serialized = questions.each_with_object({}) do |(key, question), result|
        raise ArgumentError, "question names must be strings or symbols" unless key.is_a?(String) || key.is_a?(Symbol)
        raise ArgumentError, "questions must contain Jevrb question objects" unless question.is_a?(Question)

        normalized_key = key.to_s
        if result.key?(normalized_key)
          raise ArgumentError,
                "questions contains duplicate name #{normalized_key.inspect}"
        end

        result[normalized_key] = question.to_h
        key_map[normalized_key] = key
      end

      [serialized, key_map.freeze]
    end

    def request_headers
      {
        "Authorization" => "Bearer #{api_key}",
        "Content-Type" => "application/json",
        "Accept" => "application/json",
        "User-Agent" => "jevrb/#{VERSION}"
      }
    end

    def handle_response(response, endpoint:, key_map:)
      raise api_error(response, endpoint: endpoint) unless (200..299).cover?(response.status)

      parsed = JSON.parse(response.body.to_s)
      Result.from_hash(
        parsed,
        key_map: key_map,
        request_id: response.headers["x-typesafe-request-id"]
      )
    rescue JSON::ParserError => e
      raise response_validation_error(response, endpoint, "$", e.message)
    rescue ResponseDataError => e
      raise response_validation_error(response, endpoint, e.field_path, e.message)
    end

    def response_validation_error(response, endpoint, field_path, message)
      ResponseValidationError.new(
        status: response.status,
        body: response.body,
        headers: response.headers,
        field_path: field_path,
        endpoint: "POST #{endpoint}",
        message: message
      )
    end

    def api_error(response, endpoint:)
      error_class = case response.status
                    when 400 then BadRequestError
                    when 401 then AuthenticationError
                    when 403 then PermissionDeniedError
                    when 404 then NotFoundError
                    when 422 then UnprocessableEntityError
                    when 429 then RateLimitError
                    when 500..599 then InternalServerError
                    else APIError
                    end

      error_class.new(
        status: response.status,
        body: parse_error_body(response.body),
        headers: response.headers,
        endpoint: "POST #{endpoint}"
      )
    end

    def parse_error_body(body)
      return if body.nil? || body.empty?

      JSON.parse(body)
    rescue JSON::ParserError
      body
    end
  end
end
