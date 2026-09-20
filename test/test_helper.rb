# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "jevrb"

require "minitest/autorun"

class FakeTransport
  Response = Struct.new(:status, :body, :headers, keyword_init: true)

  attr_reader :requests

  def initialize(*responses)
    @responses = responses
    @requests = []
  end

  def endpoint(path)
    "https://example.test#{path}"
  end

  def post(path, body:, headers:, timeout:)
    requests << { path: path, body: body, headers: headers, timeout: timeout }
    response = @responses.shift
    raise response if response.is_a?(Exception)

    response
  end
end

module TestHelpers
  def fake_response(status: 200, body: nil, headers: {})
    FakeTransport::Response.new(status: status, body: body, headers: headers)
  end

  def build_client(transport, **)
    client = Jevrb::Client.new(
      api_key: "test-key",
      retry_policy: Jevrb::RetryPolicy.new(max_retries: 0),
      **
    )
    client.instance_variable_set(:@transport, transport)
    client
  end

  def with_environment(values)
    previous = values.to_h { |name, _value| [name, ENV.fetch(name, nil)] }
    values.each { |name, value| value.nil? ? ENV.delete(name) : ENV[name] = value }
    yield
  ensure
    previous.each { |name, value| value.nil? ? ENV.delete(name) : ENV[name] = value }
  end
end

Minitest::Test.include(TestHelpers)
