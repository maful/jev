# frozen_string_literal: true

require "test_helper"

class RetryPolicyTest < Minitest::Test
  ZeroRandom = Class.new do
    def rand
      0.0
    end
  end

  def test_retries_rate_limits_and_obeys_retry_after_ms
    sleeps = []
    attempts = 0
    policy = retry_policy(sleeps: sleeps)

    result = policy.execute do
      attempts += 1
      if attempts == 1
        raise Jevrb::RateLimitError.new(
          status: 429,
          body: nil,
          headers: { "retry-after-ms" => "125" },
          endpoint: "POST https://example.test/v1/systemone"
        )
      end

      :ok
    end

    assert_equal :ok, result
    assert_equal 2, attempts
    assert_equal [0.125], sleeps
  end

  def test_uses_exponential_backoff_and_stops_after_max_retries
    sleeps = []
    attempts = 0
    policy = retry_policy(sleeps: sleeps)

    assert_raises(Jevrb::InternalServerError) do
      policy.execute do
        attempts += 1
        raise api_error(529)
      end
    end

    assert_equal 3, attempts
    assert_equal [0.5, 1.0], sleeps
  end

  def test_retries_connection_and_timeout_errors
    [
      Jevrb::ConnectionError.new(endpoint: "POST https://example.test"),
      Jevrb::TimeoutError.new(endpoint: "POST https://example.test", timeout: 10.0)
    ].each do |error|
      attempts = 0
      result = retry_policy(sleeps: []).execute do
        attempts += 1
        raise error if attempts == 1

        :ok
      end

      assert_equal :ok, result
      assert_equal 2, attempts
    end
  end

  def test_does_not_retry_client_errors
    attempts = 0

    assert_raises(Jevrb::AuthenticationError) do
      retry_policy(sleeps: []).execute do
        attempts += 1
        raise Jevrb::AuthenticationError.new(
          status: 401,
          body: nil,
          headers: {},
          endpoint: "POST https://example.test"
        )
      end
    end

    assert_equal 1, attempts
  end

  private

  def retry_policy(sleeps:)
    Jevrb::RetryPolicy.new(
      sleeper: ->(seconds) { sleeps << seconds },
      random: ZeroRandom.new
    )
  end

  def api_error(status)
    Jevrb::InternalServerError.new(
      status: status,
      body: nil,
      headers: {},
      endpoint: "POST https://example.test"
    )
  end
end
