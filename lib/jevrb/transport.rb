# frozen_string_literal: true

require "net/http"
require "openssl"
require "uri"

module Jevrb
  class Transport
    Response = Struct.new(:status, :body, :headers, keyword_init: true)
    private_constant :Response

    def initialize(base_url:, http_factory: Net::HTTP.method(:new))
      @base_url = base_url.chomp("/")
      @http_factory = http_factory
    end

    def endpoint(path)
      "#{@base_url}/#{path.sub(%r{\A/+}, "")}"
    end

    def post(path, body:, headers:, timeout:)
      url = endpoint(path)
      uri = URI.parse(url)
      http = @http_factory.call(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = timeout
      http.read_timeout = timeout
      http.write_timeout = timeout if http.respond_to?(:write_timeout=)

      request = Net::HTTP::Post.new(uri.request_uri, headers)
      request.body = body
      response = http.request(request)

      Response.new(
        status: response.code.to_i,
        body: response.body,
        headers: response.each_header.to_h.freeze
      ).freeze
    rescue Timeout::Error => e
      raise TimeoutError.new(endpoint: "POST #{url}", timeout: timeout, message: e.message)
    rescue IOError, SocketError, SystemCallError, OpenSSL::SSL::SSLError, Net::ProtocolError => e
      raise ConnectionError.new(endpoint: "POST #{url}", message: e.message)
    end
  end
end
