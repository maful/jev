# frozen_string_literal: true

require "json"
require "test_helper"

class ClientTest < Minitest::Test
  def test_uses_environment_defaults_and_explicit_precedence
    with_environment(
      "TYPESAFE_API_KEY" => "env-key",
      "TYPESAFE_BASE_URL" => "https://env.example",
      "TYPESAFE_DEFAULT_MODEL" => "env-model"
    ) do
      client = Jevrb::Client.new(base_url: "https://explicit.example")

      assert_equal "env-key", client.api_key
      assert_equal "https://explicit.example", client.base_url
      assert_equal "env-model", client.model
    end
  end

  def test_rejects_a_missing_api_key
    with_environment("TYPESAFE_API_KEY" => nil) do
      assert_raises(Jevrb::ConfigurationError) { Jevrb::Client.new }
    end
  end

  def test_sends_a_system_one_request_and_returns_a_result
    transport = FakeTransport.new(success_response)
    result = build_client(transport).system_one(
      "Help",
      questions: { urgent: Jevrb::Noul.build(instructions: "Urgent?") },
      model: "jev-test"
    )

    request = transport.requests.fetch(0)
    payload = JSON.parse(request[:body])
    assert_equal "/v1/systemone", request[:path]
    assert_equal "Bearer test-key", request[:headers]["Authorization"]
    assert_equal "application/json", request[:headers]["Content-Type"]
    assert_equal "jev-test", payload["model"]
    assert_equal "noul", payload.dig("questions", "urgent", "type")
    assert_instance_of Jevrb::NoulAnswer, result.answers[:urgent]
    assert_equal "req_test", result.request_id
  end

  def test_raises_status_specific_errors
    cases = {
      400 => Jevrb::BadRequestError,
      401 => Jevrb::AuthenticationError,
      403 => Jevrb::PermissionDeniedError,
      404 => Jevrb::NotFoundError,
      422 => Jevrb::UnprocessableEntityError,
      429 => Jevrb::RateLimitError,
      529 => Jevrb::InternalServerError
    }

    cases.each do |status, error_class|
      transport = FakeTransport.new(fake_response(status: status, body: '{"error":"failed"}'))
      error = assert_raises(error_class) { make_request(build_client(transport)) }

      assert_equal status, error.status
      assert_equal({ "error" => "failed" }, error.body)
    end
  end

  def test_exposes_rate_limit_retry_delay_and_request_id
    response = fake_response(
      status: 429,
      body: "rate limited",
      headers: { "retry-after-ms" => "250", "x-typesafe-request-id" => "req_limit" }
    )

    error = assert_raises(Jevrb::RateLimitError) do
      make_request(build_client(FakeTransport.new(response)))
    end

    assert_equal 250.0, error.retry_after_ms
    assert_equal "req_limit", error.request_id
  end

  def test_wraps_invalid_json_as_a_response_validation_error
    transport = FakeTransport.new(fake_response(body: "not-json"))

    error = assert_raises(Jevrb::ResponseValidationError) do
      make_request(build_client(transport))
    end

    assert_equal "$", error.field_path
    assert_equal 200, error.status
  end

  def test_wraps_a_missing_response_field_with_its_path
    body = JSON.generate("model" => "jev-1", "answers" => {})
    transport = FakeTransport.new(fake_response(body: body))

    error = assert_raises(Jevrb::ResponseValidationError) do
      make_request(build_client(transport))
    end

    assert_equal "response.usage", error.field_path
  end

  private

  def make_request(client)
    client.system_one(
      "Help",
      questions: { urgent: Jevrb::Noul.build(instructions: "Urgent?") }
    )
  end

  def success_response
    fake_response(
      body: JSON.generate(
        model: "jev-1.13.0",
        answers: { urgent: { type: "noul", noul: 0.9 } },
        usage: { input_tokens: 10, output_tokens: 2 }
      ),
      headers: { "x-typesafe-request-id" => "req_test" }
    )
  end
end
