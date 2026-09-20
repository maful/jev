# frozen_string_literal: true

require "test_helper"

class TestJevrb < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::Jevrb::VERSION
  end

  def test_public_constants_match_the_documented_defaults
    assert_equal "https://api.typesafe.ai", Jevrb::DEFAULT_BASE_URL
    assert_equal "jev-latest", Jevrb::DEFAULT_MODEL
    assert_equal 10.0, Jevrb::DEFAULT_TIMEOUT
  end

  def test_jev_is_an_alias_for_the_full_namespace
    assert_same Jevrb, Jev
    assert_same Jevrb::Client, Jev::Client
    assert_instance_of Jevrb::Client, Jev::Client.new(api_key: "test-key")
  end
end
