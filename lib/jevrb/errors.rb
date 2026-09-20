# frozen_string_literal: true

module Jevrb
  class Error < StandardError; end

  class ConfigurationError < Error; end

  class APIError < Error
    attr_reader :status, :body, :headers, :endpoint

    def initialize(status:, body:, headers:, endpoint:, message: nil)
      @status = status
      @body = body
      @headers = headers.freeze
      @endpoint = endpoint

      super(message || "TypeSafe API request failed with status #{status}")
    end

    def request_id
      headers["x-typesafe-request-id"]
    end
  end

  class BadRequestError < APIError; end
  class AuthenticationError < APIError; end
  class PermissionDeniedError < APIError; end
  class NotFoundError < APIError; end
  class UnprocessableEntityError < APIError; end

  class RateLimitError < APIError
    def retry_after_ms
      value = headers["retry-after-ms"]
      return if value.nil?

      Float(value)
    rescue ArgumentError, TypeError
      nil
    end
  end

  class InternalServerError < APIError; end

  class ConnectionError < Error
    attr_reader :endpoint

    def initialize(endpoint:, message: nil)
      @endpoint = endpoint
      super(message || "TypeSafe API connection failed")
    end
  end

  class TimeoutError < ConnectionError
    attr_reader :timeout

    def initialize(endpoint:, timeout:, message: nil)
      @timeout = timeout
      super(endpoint: endpoint, message: message || "TypeSafe API request exceeded #{timeout} seconds")
    end
  end

  class ResponseValidationError < APIError
    attr_reader :field_path

    def initialize(status:, body:, headers:, field_path:, endpoint:, message: nil)
      @field_path = field_path
      super(
        status: status,
        body: body,
        headers: headers,
        endpoint: endpoint,
        message: message || "TypeSafe API response is invalid at #{field_path}"
      )
    end
  end
end
