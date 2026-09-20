# frozen_string_literal: true

require "test_helper"

class QuestionTest < Minitest::Test
  def test_noul_serializes_optional_criteria
    question = Jevrb::Noul.build(
      instructions: { question: "Is it urgent?", context: ["billing", nil] },
      criteria: { "true" => "Urgent", "false" => nil }
    )

    assert_equal(
      {
        type: "noul",
        instructions: { "question" => "Is it urgent?", "context" => ["billing", nil] },
        criteria: { "true" => "Urgent", "false" => nil }
      },
      question.to_h
    )
  end

  def test_choice_normalizes_option_names_without_mutating_the_input
    instructions = { prompt: "Pick a team" }
    criteria = { billing: nil, "technical" => ["bugs"] }
    question = Jevrb::Choice.build(instructions: instructions, criteria: criteria)

    instructions[:prompt] = "changed"
    criteria[:billing] = "changed"

    assert_equal({ "prompt" => "Pick a team" }, question.instructions)
    assert_equal({ "billing" => nil, "technical" => ["bugs"] }, question.criteria)
    assert question.frozen?
    assert question.criteria.frozen?
  end

  def test_score_requires_between_two_and_ten_levels
    error = assert_raises(ArgumentError) do
      Jevrb::Score.build(instructions: "Rate it", criteria: ["one"])
    end

    assert_match(/2 through 10/, error.message)
  end

  def test_choice_rejects_more_than_255_options
    criteria = 256.times.to_h { |index| ["option-#{index}", nil] }

    assert_raises(ArgumentError) do
      Jevrb::Choice.build(instructions: "Pick", criteria: criteria)
    end
  end

  def test_questions_reject_non_json_content
    assert_raises(ArgumentError) do
      Jevrb::Noul.build(instructions: Object.new)
    end
  end
end
