# frozen_string_literal: true

require "test_helper"

class ResultTest < Minitest::Test
  def test_parses_every_answer_type_and_preserves_question_keys
    result = Jevrb::Result.from_hash(
      response_payload,
      key_map: { "urgent" => :urgent, "tone" => :tone, "severity" => :severity },
      request_id: "req_123"
    )

    assert_equal "jev-1.13.0", result.model
    assert_equal "req_123", result.request_id
    assert_instance_of Jevrb::NoulAnswer, result.answers[:urgent]
    assert_instance_of Jevrb::ChoiceAnswer, result.answers[:tone]
    assert_instance_of Jevrb::ScoreAnswer, result.answers[:severity]
    assert_equal({ "angry" => 0.8, "calm" => 0.2 }, result.choices[:tone].probabilities)
    assert_equal({ 0 => "Low", 1 => { "label" => "High" } }, result.scores[:severity].legend)
    assert_equal({ 0 => 0.25, 1 => 0.75 }, result.scores[:severity].probabilities)
    assert_equal({ input_tokens: 300, output_tokens: 20 }, result.usage.to_h)
    assert result.frozen?
  end

  def test_grouped_answer_helpers_contain_only_their_type
    result = Jevrb::Result.from_hash(response_payload)

    assert_equal ["urgent"], result.nouls.keys
    assert_equal ["tone"], result.choices.keys
    assert_equal ["severity"], result.scores.keys
  end

  def test_rejects_an_unknown_answer_type
    payload = response_payload
    payload["answers"]["urgent"] = { "type" => "unknown", "value" => 1 }

    error = assert_raises(StandardError) { Jevrb::Result.from_hash(payload) }

    assert_match(/unknown answer type/, error.message)
  end

  private

  def response_payload
    {
      "model" => "jev-1.13.0",
      "answers" => {
        "urgent" => { "type" => "noul", "noul" => 0.95 },
        "tone" => {
          "type" => "choice",
          "choice" => "angry",
          "probabilities" => { "angry" => 0.8, "calm" => 0.2 },
          "confidence" => 0.7
        },
        "severity" => {
          "type" => "score",
          "score" => 0.75,
          "legend" => { "0" => "Low", "1" => { "label" => "High" } },
          "probabilities" => { "0" => 0.25, "1" => 0.75 },
          "confidence" => 0.6
        }
      },
      "usage" => { "input_tokens" => 300, "output_tokens" => 20 }
    }
  end
end
