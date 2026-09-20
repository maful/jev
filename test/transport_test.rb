# frozen_string_literal: true

require "test_helper"

class TransportTest < Minitest::Test
  FakeHTTP = Struct.new(
    :response,
    :error,
    :use_ssl,
    :open_timeout,
    :read_timeout,
    :write_timeout,
    :request_value,
    keyword_init: true
  ) do
    def request(request)
      self.request_value = request
      raise error if error

      response
    end
  end

  FakeResponse = Struct.new(:code, :body, :headers, keyword_init: true) do
    def each_header(&)
      return enum_for(__method__) unless block_given?

      headers.each(&)
    end
  end

  def test_sets_http_options_and_returns_the_response
    response = FakeResponse.new(code: "200", body: "{}", headers: { "x-id" => "1" })
    http = FakeHTTP.new(response: response)
    transport = build_transport(http)

    result = transport.post("/v1/systemone", body: "{}", headers: {}, timeout: 7.5)

    assert_equal 200, result.status
    assert_equal({ "x-id" => "1" }, result.headers)
    assert_equal [7.5, 7.5, 7.5], [http.open_timeout, http.read_timeout, http.write_timeout]
    assert_equal "{}", http.request_value.body
  end

  def test_converts_net_timeouts_to_typed_timeout_errors
    transport = build_transport(FakeHTTP.new(error: Net::ReadTimeout.new("slow response")))

    error = assert_raises(Jevrb::TimeoutError) do
      transport.post("/v1/systemone", body: "{}", headers: {}, timeout: 3.0)
    end

    assert_equal 3.0, error.timeout
    assert_equal "POST https://example.test/v1/systemone", error.endpoint
  end

  private

  def build_transport(http)
    transport_class = Jevrb.const_get(:Transport, false)
    transport_class.new(base_url: "https://example.test", http_factory: ->(*) { http })
  end
end
