# frozen_string_literal: true

require_relative "jevrb/version"
require_relative "jevrb/constants"
require_relative "jevrb/errors"
require_relative "jevrb/support"
require_relative "jevrb/question"
require_relative "jevrb/noul"
require_relative "jevrb/choice"
require_relative "jevrb/score"
require_relative "jevrb/answer"
require_relative "jevrb/usage"
require_relative "jevrb/result"
require_relative "jevrb/retry_policy"
require_relative "jevrb/transport"
require_relative "jevrb/client"

module Jevrb
  private_constant :Support, :Transport
end

Jev = Jevrb
