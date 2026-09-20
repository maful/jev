# frozen_string_literal: true

require "time"

module Jevrb
  class RetryPolicy
    DEFAULT_HTTP_STATUSES = [408, 429, *(500..599)].freeze

    attr_reader :max_retries, :backoff_initial, :backoff_max, :backoff_jitter,
                :http_statuses, :respect_retry_after, :retry_connection_errors,
                :retry_timeout_errors, :timeout

    def initialize(
      max_retries: 2,
      backoff_initial: 0.5,
      backoff_max: 5.0,
      backoff_jitter: 0.25,
      http_statuses: DEFAULT_HTTP_STATUSES,
      respect_retry_after: true,
      retry_connection_errors: true,
      retry_timeout_errors: true,
      timeout: 30.0,
      sleeper: nil,
      random: nil,
      clock: nil
    )
      @max_retries = nonnegative_integer(max_retries, "max_retries")
      @backoff_initial = nonnegative_number(backoff_initial, "backoff_initial")
      @backoff_max = nonnegative_number(backoff_max, "backoff_max")
      @backoff_jitter = fraction(backoff_jitter, "backoff_jitter")
      @http_statuses = http_statuses.to_a.uniq.freeze
      @respect_retry_after = boolean(respect_retry_after, "respect_retry_after")
      @retry_connection_errors = boolean(retry_connection_errors, "retry_connection_errors")
      @retry_timeout_errors = boolean(retry_timeout_errors, "retry_timeout_errors")
      @timeout = timeout.nil? ? nil : nonnegative_number(timeout, "timeout")
      @sleeper = sleeper || ->(seconds) { sleep(seconds) }
      @random = random || Random.new
      @clock = clock || -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }
      freeze
    end

    def execute
      retries = 0
      started_at = @clock.call

      begin
        yield
      rescue Error => e
        raise unless retries < max_retries && retryable?(e)

        delay = retry_delay(e, retries)
        elapsed = @clock.call - started_at
        raise if timeout && elapsed + delay >= timeout

        @sleeper.call(delay)
        retries += 1
        retry
      end
    end

    def retryable?(error)
      return retry_timeout_errors if error.is_a?(TimeoutError)
      return retry_connection_errors if error.is_a?(ConnectionError)
      return http_statuses.include?(error.status) if error.is_a?(APIError)

      false
    end

    def retry_delay(error, retry_number)
      header_delay = retry_after_delay(error)
      return header_delay unless header_delay.nil?

      base = [backoff_initial * (2**retry_number), backoff_max].min
      base * (1.0 - (@random.rand * backoff_jitter))
    end

    private

    def retry_after_delay(error)
      return unless respect_retry_after && error.is_a?(APIError)

      milliseconds = parse_nonnegative_number(error.headers["retry-after-ms"])
      return milliseconds / 1000.0 unless milliseconds.nil?

      value = error.headers["retry-after"]
      return if value.nil?

      seconds = parse_nonnegative_number(value)
      return seconds unless seconds.nil?

      [Time.httpdate(value) - Time.now, 0.0].max
    rescue ArgumentError
      nil
    end

    def parse_nonnegative_number(value)
      return if value.nil?

      number = Float(value)
      number if number.finite? && number >= 0
    rescue ArgumentError, TypeError
      nil
    end

    def nonnegative_integer(value, name)
      return value if value.is_a?(Integer) && value >= 0

      raise ArgumentError, "#{name} must be a nonnegative integer"
    end

    def nonnegative_number(value, name)
      return value.to_f if (value.is_a?(Integer) || value.is_a?(Float)) && value.finite? && value >= 0

      raise ArgumentError, "#{name} must be a nonnegative number"
    end

    def fraction(value, name)
      number = nonnegative_number(value, name)
      return number if number <= 1.0

      raise ArgumentError, "#{name} must be between 0 and 1"
    end

    def boolean(value, name)
      return value if [true, false].include?(value)

      raise ArgumentError, "#{name} must be true or false"
    end
  end
end
